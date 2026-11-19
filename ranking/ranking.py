#!/usr/bin/env python3
"""Ranking de Anime Server by 4RMAss.

Lee las repeticiones (.yrpX) que guarda Multirole al terminar cada duelo, apunta quién
ganó y lo muestra en una página web. Desde /admin, 4RMAss puede anular un resultado o
cambiar el ganador.

Solo usa la biblioteca estándar de Python 3.
"""
import base64
import hmac
import html
import json
import lzma
import os
import sqlite3
import struct
import threading
import time
import urllib.parse
from datetime import datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

REPLAYS = os.environ.get("RANKING_REPLAYS", "/opt/multirole/replays")
DB = os.environ.get("RANKING_DB", "/opt/ranking/ranking.db")
PORT = int(os.environ.get("RANKING_PORT", "7920"))
PASSFILE = os.environ.get("RANKING_PASSFILE", "/opt/ranking/admin_password.txt")
TZ = timezone(timedelta(hours=int(os.environ.get("RANKING_TZ_HOURS", "-5"))))  # Lima
KEEP_DAYS = int(os.environ.get("RANKING_KEEP_DAYS", "90"))
TITLE = "Anime Server by 4RMAss"

MSG_WIN = 5
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
def parse_replay(path):
    """Devuelve (timestamp, [nombres equipo 0], [nombres equipo 1], ganador, razón)."""
    data = open(path, "rb").read()
    if len(data) < HEADER.size:
        raise ValueError("archivo demasiado corto")
    rtype, _ver, flags, ts, size, _hash, props, _xver, *_seed = HEADER.unpack_from(data)
    if rtype != REPLAY_YRPX:
        raise ValueError("no es una repetición YRPX")
    body = data[HEADER.size:]
    if flags & REPLAY_COMPRESSED:
        body = lzma.decompress(props[:5] + struct.pack("<Q", size) + body, format=lzma.FORMAT_ALONE)
    pos = 0
    teams = []
    for _ in range(2):
        (count,) = struct.unpack_from("<I", body, pos)
        pos += 4
        names = []
        for _ in range(count):
            raw = body[pos:pos + 40]
            pos += 40
            names.append(raw.decode("utf-16-le", "replace").split("\x00", 1)[0].strip())
        teams.append(names)
    pos += 8  # duelFlags
    winner, reason = None, None
    while pos + 5 <= len(body):
        mtype = body[pos]
        (length,) = struct.unpack_from("<I", body, pos + 1)
        pos += 5
        if mtype == MSG_WIN and length >= 2:
            winner, reason = body[pos], body[pos + 1]
        pos += length
    return ts, teams[0], teams[1], winner, reason


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
                    ts, t0, t1, w, r = parse_replay(path)
                    con.execute("insert into duels(file,ts,team0,team1,winner,reason) values (?,?,?,?,?,?)",
                                (fn, ts or int(mtime), json.dumps(t0, ensure_ascii=False),
                                 json.dumps(t1, ensure_ascii=False), w, r))
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
        d["final"] = d["corrected"] if d["corrected"] is not None else d["winner"]
        d["self"] = bool({n.lower() for n in d["team0"]} & {n.lower() for n in d["team1"]})
        out.append(d)
    return out


def standings():
    stats = {}
    for d in load_duels():
        if d["annulled"] or d["self"] or d["final"] not in (0, 1, 2) or not d["team0"] or not d["team1"]:
            continue
        for side, names in ((0, d["team0"]), (1, d["team1"])):
            for n in names:
                if not n:
                    continue
                s = stats.setdefault(n.lower(), {"name": n, "w": 0, "l": 0, "d": 0, "spell": {}})
                s["spell"][n] = s["spell"].get(n, 0) + 1  # se muestra la forma de escribirlo más usada
                if d["final"] == 2:
                    s["d"] += 1
                elif d["final"] == side:
                    s["w"] += 1
                else:
                    s["l"] += 1
    rows = list(stats.values())
    for s in rows:
        s["name"] = max(s["spell"].items(), key=lambda kv: kv[1])[0]
        total = s["w"] + s["l"] + s["d"]
        s["total"] = total
        s["pct"] = round(100 * s["w"] / total) if total else 0
    rows.sort(key=lambda s: (-s["w"], -s["pct"], s["l"], s["name"].lower()))
    return rows


# ---------------------------------------------------------------- páginas
CSS = """
body{font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif;margin:0;background:#0f1320;color:#e8ecf5}
main{max-width:760px;margin:0 auto;padding:16px}
h1{font-size:1.35rem;margin:.2em 0}h2{font-size:1.05rem;margin:1.4em 0 .5em;color:#9fb3ff}
p.sub{color:#9aa3b8;margin:.2em 0 1em}
table{width:100%;border-collapse:collapse;background:#171c2e;border-radius:10px;overflow:hidden}
th,td{padding:8px 6px;text-align:center;border-bottom:1px solid #232a42;font-size:.95rem}
th{background:#1e2540;color:#b9c4e6;font-weight:600}td.n{text-align:left;font-weight:600}
tr:last-child td{border-bottom:none}.top1 td.n{color:#ffd56b}.top2 td.n{color:#d9dde8}.top3 td.n{color:#e0a46a}
.duel{background:#171c2e;border-radius:10px;padding:8px 10px;margin:6px 0;font-size:.92rem}
.win{color:#7ee2a1;font-weight:700}.muted{color:#8d96ad;font-size:.82rem}.off{opacity:.45;text-decoration:line-through}
button{background:#2b355c;color:#e8ecf5;border:1px solid #3c4878;border-radius:7px;padding:5px 8px;margin:3px 2px;font-size:.85rem}
button.r{background:#5a2733;border-color:#7a3443}footer{color:#7f88a0;font-size:.8rem;margin:24px 0 8px}
"""


def page(body, title=TITLE):
    return f"""<!DOCTYPE html><html lang="es"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>{html.escape(title)}</title>
<style>{CSS}</style></head><body><main>{body}</main></body></html>"""


def fmt_ts(ts):
    return datetime.fromtimestamp(ts, TZ).strftime("%d/%m/%Y %H:%M")


def names_html(names, won):
    txt = " y ".join(html.escape(n) for n in names) or "?"
    return f'<span class="win">{txt}</span>' if won else txt


def duel_line(d):
    f = d["final"]
    a = names_html(d["team0"], f == 0)
    b = names_html(d["team1"], f == 1)
    res = "Empate" if f == 2 else ("Sin resultado" if f not in (0, 1) else "")
    why = REASONS.get(d["reason"], "Efecto de carta" if (d["reason"] or 0) >= 0x10 else "")
    extra = []
    if d["corrected"] is not None:
        extra.append("corregido por 4RMAss")
    if why:
        extra.append(why)
    meta = " · ".join([fmt_ts(d["ts"])] + extra)
    return f'{a} <b>vs</b> {b} {res}<div class="muted">{html.escape(meta)}</div>'


def render_public():
    rows = standings()
    if rows:
        trs = "".join(
            f'<tr class="top{i}"><td>{i}</td><td class="n">{html.escape(s["name"])}</td><td>{s["w"]}</td>'
            f'<td>{s["l"]}</td><td>{s["d"]}</td><td>{s["pct"]}%</td></tr>'
            for i, s in enumerate(rows, 1))
        table = f"""<table><tr><th>#</th><th>Jugador</th><th>V</th><th>D</th><th>E</th><th>%</th></tr>{trs}</table>"""
    else:
        table = '<p class="sub">Todavía no hay duelos registrados.</p>'
    last = [d for d in load_duels(40) if not d["annulled"] and not d["self"]][:20]
    duels = "".join(f'<div class="duel">{duel_line(d)}</div>' for d in last) or '<p class="sub">—</p>'
    body = f"""<h1>🏆 Ranking · {TITLE}</h1>
<p class="sub">V = victorias · D = derrotas · E = empates. Cuenta cada duelo jugado en el servidor.</p>
{table}<h2>Últimos duelos</h2>{duels}
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
    server_version = "Ranking4RMAss/1.0"

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
    threading.Thread(target=scanner, daemon=True).start()
    print(f"Ranking de {TITLE} escuchando en el puerto {PORT}", flush=True)
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()


if __name__ == "__main__":
    main()
