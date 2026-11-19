#!/usr/bin/env python3
"""Ranking de Anime Server by 4RMAss.

Lee las repeticiones (.yrpX) que guarda Multirole al terminar cada duelo, apunta quién
ganó y con qué deck, reconoce a qué personaje se parece cada deck y lo muestra en una
página web: ranking de jugadores, de personajes y de torneos. Los puntos funcionan como un
ranking tipo FIFA/Elo: cada personaje empieza con los puntos de su tier (tiers.json) y ganar
con un personaje débil contra uno fuerte vale más. Los torneos se definen en torneos.json.
Desde /admin, 4RMAss puede anular un resultado o cambiar el ganador.

tiers.json, torneos.json, personajes.json y este mismo programa se actualizan solos desde el
repositorio de GitHub cada 30 minutos.

Solo usa la biblioteca estándar de Python 3.
"""
import base64
import hashlib
import hmac
import html
import json
import lzma
import math
import os
import sqlite3
import struct
import sys
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
DATA_DIR = os.path.dirname(CHARS) or "."
TIERS = os.path.join(DATA_DIR, "tiers.json")
TOURN = os.path.join(DATA_DIR, "torneos.json")
# las demás direcciones salen de la de personajes.json (misma carpeta "ranking" del repositorio)
URL_BASE = CHARS_URL[:-len("personajes.json")] if CHARS_URL.endswith("personajes.json") else ""
SELF_PATH = os.path.abspath(__file__)
UPDATE_MARK = SELF_PATH + ".actualizado"
REJECTED = SELF_PATH + ".rechazada"  # huella de una versión que falló al arrancar (no se reinstala)
VERSION = "2.0"
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


def fetch(url):
    with urllib.request.urlopen(url, timeout=30) as r:
        return r.read()


def save_if_changed(path, data):
    old = open(path, "rb").read() if os.path.exists(path) else b""
    if data == old:
        return False
    tmp = path + ".nuevo"
    open(tmp, "wb").write(data)
    os.replace(tmp, path)
    return True


def update_self():
    """Descarga ranking.py del repositorio; si cambió y es válido, lo instala y se reinicia
    (systemd lo vuelve a arrancar). Se guarda una copia de la versión anterior."""
    data = fetch(URL_BASE + "ranking.py")
    current = open(SELF_PATH, "rb").read()
    digest = hashlib.sha256(data).hexdigest()
    if digest == hashlib.sha256(current).hexdigest():
        return
    if os.path.exists(REJECTED) and open(REJECTED).read().strip() == digest:
        return  # esa versión ya falló una vez; se espera a que la arreglen en GitHub
    compile(data, "ranking.py", "exec")  # si tiene errores de sintaxis, no se instala
    open(SELF_PATH + ".anterior", "wb").write(current)
    save_if_changed(SELF_PATH, data)
    open(UPDATE_MARK, "w").write(str(int(time.time())))
    print("ranking.py actualizado desde GitHub; reiniciando", flush=True)
    os._exit(0)


def updater():
    while True:
        files = [(CHARS_URL, CHARS)]
        if URL_BASE:
            files += [(URL_BASE + "tiers.json", TIERS), (URL_BASE + "torneos.json", TOURN)]
        for url, path in files:
            if not url:
                continue
            try:
                data = fetch(url)
                json.loads(data)  # solo se guarda si es válido
                save_if_changed(path, data)
            except Exception as exc:
                print(f"No se pudo actualizar {os.path.basename(path)}:", exc, flush=True)
        CHAR.load()
        if URL_BASE:
            try:
                update_self()
            except Exception as exc:
                print("No se pudo actualizar ranking.py:", exc, flush=True)
        time.sleep(1800)


def load_json(path, default):
    try:
        return json.load(open(path, encoding="utf-8"))
    except Exception:
        return default


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


DEFAULT_POINTS = {"SSS": 1800, "SS": 1700, "S": 1600, "A+": 1550, "A": 1500, "B": 1450, "C": 1400, "D": 1300}
K_BASE = 32          # cuánto se mueven los puntos en cada duelo
K_TOURNAMENT = 2     # los duelos de torneo valen el doble
START_PLAYER = 1500  # puntos iniciales de cada jugador


def tiers_info():
    data = load_json(TIERS, {})
    points = dict(DEFAULT_POINTS)
    points.update({k: v for k, v in (data.get("puntos") or {}).items() if isinstance(v, (int, float))})
    default = data.get("por_defecto", "B")
    chars = data.get("personajes") or {}

    def tier(char):
        t = chars.get(char, default)
        return t if t in points else default

    return tier, points, default


def parse_day(s, end=False):
    d = datetime.strptime(s, "%Y-%m-%d").replace(tzinfo=TZ)
    if end:
        d += timedelta(days=1)
    return d.timestamp()


def tournaments_info():
    out = []
    for t in (load_json(TOURN, {}).get("torneos") or []):
        try:
            out.append({
                "name": str(t.get("nombre") or "Torneo"),
                "start": parse_day(t["inicio"]),
                "end": parse_day(t.get("fin") or t["inicio"], end=True),
                "start_txt": t["inicio"], "end_txt": t.get("fin") or t["inicio"],
                "players": {str(p).strip().lower() for p in t.get("participantes") or [] if str(p).strip()},
                "champion": str(t.get("campeon") or "").strip(),
                "bonus": float(t.get("bono_campeon") or 0),
            })
        except Exception as exc:
            print("Torneo mal escrito en torneos.json:", exc, flush=True)
    return out


def valid_duel(d):
    return not (d["annulled"] or d["self"] or d["final"] not in (0, 1, 2) or not d["team0"] or not d["team1"])


def expected(a, b):
    return 1 / (1 + 10 ** ((b - a) / 400))


def stats(duels):
    """Puntos, victorias/derrotas/empates por jugador y por personaje, y tablas de torneos.
    Añade a cada duelo: 'tour' (torneo o None) y 'delta' (puntos ganados/perdidos por lado)."""
    tier, points, default = tiers_info()
    tours = tournaments_info()
    players, chars = {}, {}

    def row(table, key, display):
        return table.setdefault(key, {"name": display, "w": 0, "l": 0, "d": 0, "spell": Counter(),
                                      "fav": Counter(), "pts": None})

    def char_pts(c):
        s = chars.get(c)
        if s is not None and s["pts"] is not None:
            return s["pts"]
        return points[tier(c)] if c else points[default]

    def player_pts(k):
        s = players.get(k)
        return s["pts"] if s is not None and s["pts"] is not None else START_PLAYER

    events = [(d["ts"], 0, d) for d in duels if valid_duel(d)]
    for t in tours:
        if t["champion"] and t["bonus"]:
            events.append((t["end"], 1, t))
    events.sort(key=lambda e: (e[0], e[1], e[2]["file"] if e[1] == 0 else ""))

    for t in tours:
        t["table"] = {}
    for ts, kind, d in events:
        if kind == 1:  # bono al campeón al terminar el torneo
            if ts <= time.time():
                k = d["champion"].lower()
                s = row(players, k, d["champion"])
                s["pts"] = player_pts(k) + d["bonus"]
            continue
        keys = [[n.lower() for n in d["team" + str(s)]] for s in (0, 1)]
        everyone = set(keys[0]) | set(keys[1])
        d["tour"] = next((t for t in tours if t["start"] <= d["ts"] < t["end"] and t["players"]
                          and everyone <= t["players"]), None)
        k_factor = K_BASE * (K_TOURNAMENT if d["tour"] else 1)
        r0 = 0.5 if d["final"] == 2 else (1.0 if d["final"] == 0 else 0.0)
        side_chars = [[c for c, _p in d["chars"][s]] for s in (0, 1)]
        # fuerza de cada lado = puntos de sus jugadores + ventaja/desventaja de su personaje
        strength = []
        cstr = []
        for s in (0, 1):
            cp = sum(char_pts(c) for c in side_chars[s]) / len(side_chars[s])
            pp = sum(player_pts(k) for k in keys[s]) / len(keys[s])
            cstr.append(cp)
            strength.append(pp + (cp - START_PLAYER))
        delta = k_factor * (r0 - expected(strength[0], strength[1]))
        d["delta"] = [round(delta), -round(delta)]
        cdelta = k_factor * (r0 - expected(cstr[0], cstr[1]))
        same = set(c for c in side_chars[0] if c) == set(c for c in side_chars[1] if c)
        for s in (0, 1):
            sign = 1 if s == 0 else -1
            result = "d" if d["final"] == 2 else ("w" if d["final"] == s else "l")
            for name, k, c in zip(d["team" + str(s)], keys[s], side_chars[s]):
                p = row(players, k, name)
                p["spell"][name] += 1
                p[result] += 1
                p["pts"] = player_pts(k) + sign * delta
                if c:
                    p["fav"][c] += 1
                    cr = row(chars, c, c)
                    cr["spell"][c] += 1
                    cr[result] += 1
                    cr["pts"] = char_pts(c) + (0 if same else sign * cdelta)
                if d["tour"]:
                    tr = row(d["tour"]["table"], k, name)
                    tr["spell"][name] += 1
                    tr[result] += 1

    def finish(table, by_points=True):
        rows = list(table.values())
        for s in rows:
            s["name"] = s["spell"].most_common(1)[0][0] if s["spell"] else s["name"]
            s["total"] = s["w"] + s["l"] + s["d"]
            s["pct"] = round(100 * s["w"] / s["total"]) if s["total"] else 0
            s["favorite"] = s["fav"].most_common(1)[0][0] if s["fav"] else ""
            s["points"] = round(s["pts"]) if s["pts"] is not None else START_PLAYER
            s["tpts"] = 3 * s["w"] + s["d"]
        if by_points:
            rows.sort(key=lambda s: (-s["points"], -s["w"], s["l"], s["name"].lower()))
        else:
            rows.sort(key=lambda s: (-s["tpts"], -s["w"], s["l"], s["name"].lower()))
        return rows

    prow = [s for s in finish(players) if s["total"]]
    crow = finish(chars)
    for c in crow:
        c["tier"] = tier(c["name"])
    for t in tours:
        t["rows"] = finish(t["table"], by_points=False)
        now = time.time()
        t["state"] = "Próximo" if now < t["start"] else ("En curso" if now < t["end"] else "Terminado")
    return prow, crow, tours


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
.up{color:#7ee2a1;font-size:.8rem}.down{color:#ff8a8a;font-size:.8rem}
.tour{color:#ffd56b;background:#3a3216;border-radius:9px;padding:1px 7px;font-size:.78rem;white-space:nowrap}
.tier{display:inline-block;min-width:2.2em;border-radius:6px;padding:1px 4px;font-weight:700;font-size:.8rem;background:#2a3150}
.tSSS{background:#7a2030}.tSS{background:#7a4a20}.tS{background:#6a6020}.tAp{background:#2f6a30}.tA{background:#215a5a}
.tB{background:#26407a}.tC{background:#4a2f7a}.tD{background:#444a58}
td.p{font-weight:700;color:#ffe9a8}
"""


def page(body, title=TITLE):
    return f"""<!DOCTYPE html><html lang="es"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>{html.escape(title)}</title>
<style>{CSS}</style></head><body><main>{body}</main></body></html>"""


def fmt_ts(ts):
    return datetime.fromtimestamp(ts, TZ).strftime("%d/%m/%Y %H:%M")


def side_html(names, chars, won, delta=None):
    parts = []
    for name, (char, pct) in zip(names, chars):
        txt = html.escape(name or "?")
        if won:
            txt = f'<span class="win">{txt}</span>'
        if delta is not None:
            txt += (f' <span class="up">+{delta}</span>' if delta >= 0 else
                    f' <span class="down">−{-delta}</span>')
        if char:
            txt += f' <span class="ch">{html.escape(char)} · {pct}%</span>'
        parts.append(txt)
    return " y ".join(parts) or "?"


def duel_line(d):
    f = d["final"]
    delta = d.get("delta") or [None, None]
    a = side_html(d["team0"], d["chars"][0], f == 0, delta[0])
    b = side_html(d["team1"], d["chars"][1], f == 1, delta[1])
    res = "· Empate" if f == 2 else ("· Sin resultado" if f not in (0, 1) else "")
    why = REASONS.get(d["reason"], "Efecto de carta" if (d["reason"] or 0) >= 0x10 else "")
    extra = []
    if d["corrected"] is not None:
        extra.append("corregido por 4RMAss")
    if why:
        extra.append(why)
    meta = " · ".join([fmt_ts(d["ts"])] + extra)
    tour = f' <span class="tour">🏆 {html.escape(d["tour"]["name"])}</span>' if d.get("tour") else ""
    return f'{a} <b>vs</b> {b} {res}{tour}<div class="muted">{html.escape(meta)}</div>'


def tier_badge(t):
    cls = "t" + t.replace("+", "p")
    return f'<span class="tier {cls}">{html.escape(t)}</span>'


def players_table(rows):
    if not rows:
        return '<p class="sub">Todavía no hay duelos registrados.</p>'
    head = ('<tr><th>#</th><th>Jugador</th><th>Puntos</th><th>V</th><th>D</th><th>E</th><th>%</th>'
            '<th>Personaje favorito</th></tr>')
    trs = []
    for i, s in enumerate(rows, 1):
        trs.append(f'<tr class="top{i}"><td>{i}</td><td class="n">{html.escape(s["name"])}</td>'
                   f'<td class="p">{s["points"]}</td><td>{s["w"]}</td><td>{s["l"]}</td><td>{s["d"]}</td>'
                   f'<td>{s["pct"]}%</td><td class="c">{html.escape(s["favorite"]) or "—"}</td></tr>')
    return f"<table>{head}{''.join(trs)}</table>"


def chars_table(rows):
    if not rows:
        return '<p class="sub">Todavía no hay duelos registrados.</p>'
    head = ('<tr><th>#</th><th>Personaje</th><th>Tier</th><th>Puntos</th><th>V</th><th>D</th><th>E</th>'
            '<th>%</th></tr>')
    trs = []
    for i, s in enumerate(rows, 1):
        trs.append(f'<tr class="top{i}"><td>{i}</td><td class="n">{html.escape(s["name"])}</td>'
                   f'<td>{tier_badge(s["tier"])}</td><td class="p">{s["points"]}</td><td>{s["w"]}</td>'
                   f'<td>{s["l"]}</td><td>{s["d"]}</td><td>{s["pct"]}%</td></tr>')
    return f"<table>{head}{''.join(trs)}</table>"


def tournament_html(t):
    champ = t["champion"] or (t["rows"][0]["name"] if t["state"] == "Terminado" and t["rows"] else "")
    info = f'{t["start_txt"]} al {t["end_txt"]} · {t["state"]}'
    if champ:
        info += f" · Campeón: {champ}"
        if t["champion"] and t["bonus"]:
            info += f" (+{round(t['bonus'])} puntos)"
    if t["rows"]:
        head = '<tr><th>#</th><th>Jugador</th><th>Pts</th><th>V</th><th>D</th><th>E</th><th>Duelos</th></tr>'
        trs = "".join(f'<tr class="top{i}"><td>{i}</td><td class="n">{html.escape(s["name"])}</td>'
                      f'<td class="p">{s["tpts"]}</td><td>{s["w"]}</td><td>{s["l"]}</td><td>{s["d"]}</td>'
                      f'<td>{s["total"]}</td></tr>' for i, s in enumerate(t["rows"], 1))
        table = f"<table>{head}{trs}</table>"
    else:
        table = '<p class="sub">Todavía no hay duelos de este torneo.</p>'
    return f'<h3 style="margin:1em 0 .2em">🏆 {html.escape(t["name"])}</h3><p class="sub">{html.escape(info)}</p>{table}'


def render_public():
    duels = load_duels()
    players, chars, tours = stats(duels)
    last = [d for d in duels if not d["annulled"] and not d["self"]][:20]
    duel_html = "".join(f'<div class="duel">{duel_line(d)}</div>' for d in last) or '<p class="sub">—</p>'
    tours_html = ""
    if tours:
        order = {"En curso": 0, "Próximo": 1, "Terminado": 2}
        tours_sorted = sorted(tours, key=lambda t: (order[t["state"]], -t["start"]))
        tours_html = ('<h2>Torneos</h2><p class="sub">Pts = 3 por victoria y 1 por empate. '
                      'Los duelos de torneo también suman (el doble) a la tabla general.</p>'
                      + "".join(tournament_html(t) for t in tours_sorted))
    body = f"""<h1>🏆 Ranking · {TITLE}</h1>
<p class="sub">Puntos tipo ranking FIFA: cada jugador empieza con {START_PLAYER}. Ganar da más puntos si el
rival es más fuerte o si tu personaje es más débil (según su tier), y perder contra alguien más débil quita
más. Los duelos de torneo valen el doble. V = victorias · D = derrotas · E = empates.</p>
<h2>Jugadores</h2>{players_table(players)}
<h2>Personajes</h2>
<p class="sub">Cada personaje empieza con los puntos de su tier (SSS {DEFAULT_POINTS["SSS"]} … D {DEFAULT_POINTS["D"]})
y sube o baja con sus duelos. Cada deck se compara con los decks de los personajes y cuenta para el más
parecido (desde un {MIN_PCT}% de parecido).</p>{chars_table(chars)}
{tours_html}
<h2>Últimos duelos</h2>{duel_html}
<footer>Se cuenta por el nombre que usas en EDOPro. 4RMAss revisa y corrige los resultados. · v{VERSION}</footer>"""
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
    server_version = "Ranking4RMAss/" + VERSION

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


def restore_previous(exc):
    """Si la versión recién descargada falla al arrancar, se vuelve a la anterior."""
    prev = SELF_PATH + ".anterior"
    if os.path.exists(UPDATE_MARK) and os.path.exists(prev):
        print("La versión nueva falló al arrancar; se vuelve a la anterior:", exc, flush=True)
        open(REJECTED, "w").write(hashlib.sha256(open(SELF_PATH, "rb").read()).hexdigest())
        os.replace(prev, SELF_PATH)
        os.remove(UPDATE_MARK)
        sys.exit(1)  # systemd lo vuelve a arrancar con la versión anterior
    raise exc


def main():
    try:
        init_db()
        CHAR.load()
        stats(load_duels())  # comprueba que todo funciona antes de abrir la página
        server = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    except Exception as exc:
        restore_previous(exc)
    if os.path.exists(UPDATE_MARK):
        os.remove(UPDATE_MARK)
    threading.Thread(target=scanner, daemon=True).start()
    threading.Thread(target=updater, daemon=True).start()
    print(f"Ranking de {TITLE} v{VERSION} escuchando en el puerto {PORT}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
