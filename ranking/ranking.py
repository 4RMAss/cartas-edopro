#!/usr/bin/env python3
"""Ranking de Anime Server by 4RMAss.

Lee las repeticiones (.yrpX) que guarda Multirole al terminar cada duelo, apunta quién
ganó y con qué deck, reconoce a qué personaje se parece cada deck y lo muestra en una
página web: ranking de jugadores y ranking de personajes. Desde /admin, 4RMAss puede
anular un resultado o cambiar el ganador.

Solo usa la biblioteca estándar de Python 3.
"""
import base64
import hmac
import html
import json
import lzma
import math
import os
import sqlite3
import struct
import threading
import time
import urllib.parse
import urllib.request
from collections import Counter
from datetime import datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

REPLAYS = os.environ.get("RANKING_REPLAYS", "/opt/multirole/replays")
DB = os.environ.get("RANKING_DB", "/opt/ranking/ranking.db")
PORT = int(os.environ.get("RANKING_PORT", "7920"))
PASSFILE = os.environ.get("RANKING_PASSFILE", "/opt/ranking/admin_password.txt")
CHARS = os.environ.get("RANKING_CHARS", "/opt/ranking/personajes.json")
CHARS_URL = os.environ.get("RANKING_CHARS_URL", "")  # si se indica, se actualiza solo desde GitHub
TZ = timezone(timedelta(hours=int(os.environ.get("RANKING_TZ_HOURS", "-5"))))  # Lima
KEEP_DAYS = int(os.environ.get("RANKING_KEEP_DAYS", "90"))
MIN_PCT = int(os.environ.get("RANKING_MIN_PCT", "40"))  # parecido mínimo para asignar personaje
TITLE = "Anime Server by 4RMAss"

MSG_WIN = 5
MSG_OLD_REPLAY = 231  # dentro va la repetición antigua (YRP), con los decks
REASONS = {
    0x00: "Rendición",
    0x01: "LP a 0",
    0x02: "Sin cartas para robar",
    0x03: "Tiempo agotado",
    0x04: "Desconexión",
    0x05: "Respuesta inválida",
    0x06: "Error del servidor",
}
HEADER = struct.Struct("<IIIIII8sQ4Q")  # ExtendedReplayHeader de Multirole (72 bytes)
REPLAY_YRPX = 0x58707279
REPLAY_COMPRESSED = 0x1

db_lock = threading.Lock()


# ---------------------------------------------------------------- lectura de repeticiones
def read_names(buf, pos):
    teams = []
    for _ in range(2):
        (count,) = struct.unpack_from("<I", buf, pos)
        pos += 4
        names = []
        for _ in range(count):
            raw = buf[pos:pos + 40]
            pos += 40
            names.append(raw.decode("utf-16-le", "replace").split("\x00", 1)[0].strip())
        teams.append(names)
    return teams, pos


def read_decks(yrp, counts):
    """Decks de cada duelista dentro de la repetición antigua (YRP)."""
    pos = HEADER.size
    _teams, pos = read_names(yrp, pos)
    pos += 12 + 8  # LP inicial, robos iniciales, robos por turno, duelFlags
    decks = []
    for _ in range(counts[0] + counts[1]):
        cards = []
        for _part in range(2):  # Deck y Deck Extra
            (n,) = struct.unpack_from("<I", yrp, pos)
            pos += 4
            cards += list(struct.unpack_from(f"<{n}I", yrp, pos))
            pos += 4 * n
        decks.append(cards)
    return [decks[:counts[0]], decks[counts[0]:]]


def parse_replay(path):
    """Devuelve (timestamp, nombres0, nombres1, ganador, razón, decks0, decks1)."""
    data = open(path, "rb").read()
    if len(data) < HEADER.size:
        raise ValueError("archivo demasiado corto")
    rtype, _ver, flags, ts, size, _hash, props, _xver, *_seed = HEADER.unpack_from(data)
    if rtype != REPLAY_YRPX:
        raise ValueError("no es una repetición YRPX")
    body = data[HEADER.size:]
    if flags & REPLAY_COMPRESSED:
        body = lzma.decompress(props[:5] + struct.pack("<Q", size) + body, format=lzma.FORMAT_ALONE)
    teams, pos = read_names(body, 0)
    pos += 8  # duelFlags
    winner, reason = None, None
    decks = [[], []]
    while pos + 5 <= len(body):
        mtype = body[pos]
        (length,) = struct.unpack_from("<I", body, pos + 1)
        pos += 5
        if mtype == MSG_WIN and length >= 2:
            winner, reason = body[pos], body[pos + 1]
        elif mtype == MSG_OLD_REPLAY:
            try:
                decks = read_decks(body[pos:pos + length], (len(teams[0]), len(teams[1])))
            except Exception:
                decks = [[], []]
        pos += length
    return ts, teams[0], teams[1], winner, reason, decks[0], decks[1]


# ---------------------------------------------------------------- personajes
class Characters:
    def __init__(self):
        self.mtime = None
        self.decks = []   # [(personaje, set de claves)]
        self.map = {}
        self.weight = {}
        self.unseen = 1.0
        self.lock = threading.Lock()

    def load(self):
        try:
            mtime = os.path.getmtime(CHARS)
        except OSError:
            return
        if mtime == self.mtime:
            return
        try:
            data = json.load(open(CHARS, encoding="utf-8"))
        except Exception as exc:
            print("personajes.json no válido:", exc, flush=True)
            return
        decks, df = [], Counter()
        for char, lists in data["characters"].items():
            union = set()
            for keys in lists:
                decks.append((char, set(keys)))
                union |= set(keys)
            df.update(union)
        n = max(1, len(data["characters"]))
        with self.lock:
            self.decks = decks
            self.map = {int(k): v for k, v in data["map"].items()}
            # las cartas que usan muchos personajes (Pot of Greed...) pesan poco
            self.weight = {k: math.log(1 + n / c) for k, c in df.items()}
            self.unseen = math.log(1 + n)
            self.mtime = mtime

    def detect(self, cards):
        """(personaje, porcentaje) del deck de referencia más parecido."""
        if not cards:
            return None, 0
        with self.lock:
            if not self.decks:
                return None, 0
            keys = {self.map.get(c, ("id", c)) for c in cards}
            w = {k: self.weight.get(k, self.unseen) for k in keys}
            total = sum(w.values()) or 1
            best, best_score, best_tie = None, 0.0, 0.0
            for char, ref in self.decks:
                common = keys & ref
                score = sum(w[k] for k in common) / total
                tie = len(common) / (len(ref) or 1)
                if score > best_score or (score == best_score and tie > best_tie):
                    best, best_score, best_tie = char, score, tie
        pct = round(100 * best_score)
        return (best if pct >= MIN_PCT else None), pct


CHAR = Characters()


def chars_updater():
    while True:
        if CHARS_URL:
            try:
                with urllib.request.urlopen(CHARS_URL, timeout=30) as r:
                    data = r.read()
                json.loads(data)  # solo se guarda si es válido
                old = open(CHARS, "rb").read() if os.path.exists(CHARS) else b""
                if data != old:
                    tmp = CHARS + ".nuevo"
                    open(tmp, "wb").write(data)
                    os.replace(tmp, CHARS)
            except Exception as exc:
                print("No se pudo actualizar personajes.json:", exc, flush=True)
        CHAR.load()
        time.sleep(1800)


# ---------------------------------------------------------------- base de datos
def db():
    con = sqlite3.connect(DB, timeout=30)
    con.row_factory = sqlite3.Row
    return con


def init_db():
    os.makedirs(os.path.dirname(DB), exist_ok=True)
    with db_lock, db() as con:
        con.execute("""create table if not exists duels(
            file text primary key, ts integer, team0 text, team1 text,
            winner integer, reason integer, corrected integer, annulled integer default 0)""")
        cols = {r[1] for r in con.execute("pragma table_info(duels)")}
        for col in ("decks0", "decks1"):
            if col not in cols:
                con.execute(f"alter table duels add column {col} text default '[]'")
        con.execute("create table if not exists bad(file text primary key, error text)")


def scan_once():
    if not os.path.isdir(REPLAYS):
        return
    with db_lock, db() as con:
        known = {r[0] for r in con.execute("select file from duels union select file from bad")}
        now = time.time()
        for fn in sorted(os.listdir(REPLAYS)):
            if not fn.endswith(".yrpX"):
                continue
            path = os.path.join(REPLAYS, fn)
            try:
                mtime = os.path.getmtime(path)
            except OSError:
                continue
            if fn not in known and now - mtime > 5:
                try:
                    ts, t0, t1, w, r, d0, d1 = parse_replay(path)
                    con.execute("insert into duels(file,ts,team0,team1,winner,reason,decks0,decks1) "
                                "values (?,?,?,?,?,?,?,?)",
                                (fn, ts or int(mtime), json.dumps(t0, ensure_ascii=False),
                                 json.dumps(t1, ensure_ascii=False), w, r, json.dumps(d0), json.dumps(d1)))
                except Exception as exc:  # repetición rota: se apunta y no se vuelve a intentar
                    con.execute("insert or ignore into bad values (?,?)", (fn, str(exc)[:200]))
            # limpieza de repeticiones viejas (los resultados se quedan en la base de datos)
            if KEEP_DAYS > 0 and now - mtime > KEEP_DAYS * 86400 and fn in known:
                try:
                    os.remove(path)
                except OSError:
                    pass


def scanner():
    while True:
        try:
            scan_once()
        except Exception as exc:
            print("Error al leer repeticiones:", exc, flush=True)
        time.sleep(20)


def load_duels(limit=None):
    with db_lock, db() as con:
        q = "select * from duels order by ts desc"
        if limit:
            q += f" limit {int(limit)}"
        rows = con.execute(q).fetchall()
    out = []
    for r in rows:
        d = dict(r)
        d["team0"] = json.loads(d["team0"])
        d["team1"] = json.loads(d["team1"])
        decks = [json.loads(d.get("decks0") or "[]"), json.loads(d.get("decks1") or "[]")]
        d["chars"] = [[CHAR.detect(decks[t][i]) if i < len(decks[t]) else (None, 0)
                       for i in range(len(d["team" + str(t)]))] for t in (0, 1)]
        d["final"] = d["corrected"] if d["corrected"] is not None else d["winner"]
        d["self"] = bool({n.lower() for n in d["team0"]} & {n.lower() for n in d["team1"]})
        out.append(d)
    return out


def counts(duels):
    """Victorias/derrotas/empates por jugador y por personaje."""
    players, chars = {}, {}

    def add(table, key, display, result):
        s = table.setdefault(key, {"name": display, "w": 0, "l": 0, "d": 0, "spell": Counter(), "fav": Counter()})
        s["spell"][display] += 1
        s[result] += 1
        return s

    for d in duels:
        if d["annulled"] or d["self"] or d["final"] not in (0, 1, 2) or not d["team0"] or not d["team1"]:
            continue
        for side in (0, 1):
            result = "d" if d["final"] == 2 else ("w" if d["final"] == side else "l")
            for name, (char, _pct) in zip(d["team" + str(side)], d["chars"][side]):
                if not name:
                    continue
                s = add(players, name.lower(), name, result)
                if char:
                    s["fav"][char] += 1
                    add(chars, char, char, result)

    def finish(table):
        rows = list(table.values())
        for s in rows:
            s["name"] = s["spell"].most_common(1)[0][0]  # la forma de escribirlo más usada
            s["total"] = s["w"] + s["l"] + s["d"]
            s["pct"] = round(100 * s["w"] / s["total"]) if s["total"] else 0
            s["favorite"] = s["fav"].most_common(1)[0][0] if s["fav"] else ""
        rows.sort(key=lambda s: (-s["w"], -s["pct"], s["l"], s["name"].lower()))
        return rows

    return finish(players), finish(chars)


# ---------------------------------------------------------------- páginas
CSS = """
body{font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif;margin:0;background:#0f1320;color:#e8ecf5}
main{max-width:780px;margin:0 auto;padding:16px}
h1{font-size:1.35rem;margin:.2em 0}h2{font-size:1.05rem;margin:1.5em 0 .5em;color:#9fb3ff}
p.sub{color:#9aa3b8;margin:.2em 0 1em}
table{width:100%;border-collapse:collapse;background:#171c2e;border-radius:10px;overflow:hidden}
th,td{padding:8px 6px;text-align:center;border-bottom:1px solid #232a42;font-size:.93rem}
th{background:#1e2540;color:#b9c4e6;font-weight:600}td.n{text-align:left;font-weight:600}
td.c{text-align:left;color:#c9b6ff;font-size:.85rem}
tr:last-child td{border-bottom:none}.top1 td.n{color:#ffd56b}.top2 td.n{color:#d9dde8}.top3 td.n{color:#e0a46a}
.duel{background:#171c2e;border-radius:10px;padding:8px 10px;margin:6px 0;font-size:.92rem}
.win{color:#7ee2a1;font-weight:700}
.ch{color:#d9ccff;background:#2a2550;border-radius:9px;padding:1px 7px;font-size:.78rem;white-space:nowrap}
.muted{color:#8d96ad;font-size:.82rem}.off{opacity:.45;text-decoration:line-through}
button{background:#2b355c;color:#e8ecf5;border:1px solid #3c4878;border-radius:7px;padding:5px 8px;margin:3px 2px;font-size:.85rem}
button.r{background:#5a2733;border-color:#7a3443}footer{color:#7f88a0;font-size:.8rem;margin:24px 0 8px}
"""


def page(body, title=TITLE):
    return f"""<!DOCTYPE html><html lang="es"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>{html.escape(title)}</title>
<style>{CSS}</style></head><body><main>{body}</main></body></html>"""


def fmt_ts(ts):
    return datetime.fromtimestamp(ts, TZ).strftime("%d/%m/%Y %H:%M")


def side_html(names, chars, won):
    parts = []
    for name, (char, pct) in zip(names, chars):
        txt = html.escape(name or "?")
        if won:
            txt = f'<span class="win">{txt}</span>'
        if char:
            txt += f' <span class="ch">{html.escape(char)} · {pct}%</span>'
        parts.append(txt)
    return " y ".join(parts) or "?"


def duel_line(d):
    f = d["final"]
    a = side_html(d["team0"], d["chars"][0], f == 0)
    b = side_html(d["team1"], d["chars"][1], f == 1)
    res = "· Empate" if f == 2 else ("· Sin resultado" if f not in (0, 1) else "")
    why = REASONS.get(d["reason"], "Efecto de carta" if (d["reason"] or 0) >= 0x10 else "")
    extra = []
    if d["corrected"] is not None:
        extra.append("corregido por 4RMAss")
    if why:
        extra.append(why)
    meta = " · ".join([fmt_ts(d["ts"])] + extra)
    return f'{a} <b>vs</b> {b} {res}<div class="muted">{html.escape(meta)}</div>'


def table_html(rows, first_col, show_fav):
    if not rows:
        return '<p class="sub">Todavía no hay duelos registrados.</p>'
    head = f'<tr><th>#</th><th>{first_col}</th><th>V</th><th>D</th><th>E</th><th>%</th>'
    head += '<th>Personaje favorito</th></tr>' if show_fav else '<th>Duelos</th></tr>'
    trs = []
    for i, s in enumerate(rows, 1):
        last = (f'<td class="c">{html.escape(s["favorite"]) or "—"}</td>' if show_fav
                else f'<td>{s["total"]}</td>')
        trs.append(f'<tr class="top{i}"><td>{i}</td><td class="n">{html.escape(s["name"])}</td>'
                   f'<td>{s["w"]}</td><td>{s["l"]}</td><td>{s["d"]}</td><td>{s["pct"]}%</td>{last}</tr>')
    return f"<table>{head}{''.join(trs)}</table>"


def render_public():
    duels = load_duels()
    players, chars = counts(duels)
    last = [d for d in duels if not d["annulled"] and not d["self"]][:20]
    duel_html = "".join(f'<div class="duel">{duel_line(d)}</div>' for d in last) or '<p class="sub">—</p>'
    body = f"""<h1>🏆 Ranking · {TITLE}</h1>
<p class="sub">V = victorias · D = derrotas · E = empates. Cuenta cada duelo jugado en el servidor.</p>
<h2>Jugadores</h2>{table_html(players, "Jugador", True)}
<h2>Personajes</h2>
<p class="sub">Cada deck se compara con los decks de los personajes y cuenta para el más parecido
(desde un {MIN_PCT}% de parecido).</p>{table_html(chars, "Personaje", False)}
<h2>Últimos duelos</h2>{duel_html}
<footer>Se cuenta por el nombre que usas en EDOPro. 4RMAss revisa y corrige los resultados.</footer>"""
    return page(body)


def render_admin():
    items = []
    for d in load_duels(150):
        cls = "duel off" if d["annulled"] else "duel"
        fid = html.escape(d["file"])
        n0 = html.escape(" y ".join(d["team0"]) or "?")
        n1 = html.escape(" y ".join(d["team1"]) or "?")
        state = "ANULADO · " if d["annulled"] else ("Mismo jugador en ambos lados (no cuenta) · " if d["self"] else "")
        buttons = (
            f'<button name="a" value="g0">Ganó {n0}</button><button name="a" value="g1">Ganó {n1}</button>'
            f'<button name="a" value="emp">Empate</button>'
            + ('<button name="a" value="res">Restaurar</button>' if d["annulled"] else
               '<button class="r" name="a" value="anu">Anular</button>')
            + ('<button name="a" value="orig">Quitar corrección</button>' if d["corrected"] is not None else "")
        )
        items.append(f'<div class="{cls}"><div class="muted">{state}</div>{duel_line(d)}'
                     f'<form method="post" action="/admin"><input type="hidden" name="f" value="{fid}">{buttons}</form></div>')
    body = f"""<h1>Administrar resultados</h1>
<p class="sub">Los cambios se aplican al momento en el <a href="/" style="color:#9fb3ff">ranking</a>.</p>
{''.join(items) or '<p class="sub">Todavía no hay duelos registrados.</p>'}"""
    return page(body, "Administrar · " + TITLE)


def admin_password():
    try:
        return open(PASSFILE, encoding="utf-8").read().strip()
    except OSError:
        return None


class Handler(BaseHTTPRequestHandler):
    server_version = "Ranking4RMAss/1.1"

    def log_message(self, fmt, *args):
        pass

    def send_html(self, text, code=200):
        data = text.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def authorized(self):
        pw = admin_password()
        auth = self.headers.get("Authorization", "")
        if pw and auth.startswith("Basic "):
            try:
                _user, _, given = base64.b64decode(auth[6:]).decode("utf-8").partition(":")
            except Exception:
                return False
            return hmac.compare_digest(given, pw)
        return False

    def ask_auth(self):
        self.send_response(401)
        self.send_header("WWW-Authenticate", 'Basic realm="Ranking 4RMAss", charset="UTF-8"')
        self.send_header("Content-Length", "0")
        self.end_headers()

    def do_GET(self):
        CHAR.load()
        path = urllib.parse.urlparse(self.path).path
        if path == "/":
            self.send_html(render_public())
        elif path == "/admin":
            if not self.authorized():
                return self.ask_auth()
            self.send_html(render_admin())
        else:
            self.send_html(page("<p>No existe esta página.</p>"), 404)

    def do_POST(self):
        if urllib.parse.urlparse(self.path).path != "/admin":
            return self.send_html(page("<p>No existe esta página.</p>"), 404)
        if not self.authorized():
            return self.ask_auth()
        length = int(self.headers.get("Content-Length", "0") or 0)
        form = urllib.parse.parse_qs(self.rfile.read(min(length, 10000)).decode("utf-8"))
        f = (form.get("f") or [""])[0]
        a = (form.get("a") or [""])[0]
        sql = {
            "g0": "update duels set corrected=0 where file=?",
            "g1": "update duels set corrected=1 where file=?",
            "emp": "update duels set corrected=2 where file=?",
            "orig": "update duels set corrected=null where file=?",
            "anu": "update duels set annulled=1 where file=?",
            "res": "update duels set annulled=0 where file=?",
        }.get(a)
        if sql and f:
            with db_lock, db() as con:
                con.execute(sql, (f,))
        self.send_response(303)
        self.send_header("Location", "/admin")
        self.send_header("Content-Length", "0")
        self.end_headers()


def main():
    init_db()
    CHAR.load()
    threading.Thread(target=scanner, daemon=True).start()
    threading.Thread(target=chars_updater, daemon=True).start()
    print(f"Ranking de {TITLE} escuchando en el puerto {PORT}", flush=True)
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()


if __name__ == "__main__":
    main()
