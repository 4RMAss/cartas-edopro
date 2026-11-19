#!/usr/bin/env python3
"""Ranking de Anime Server by 4RMAss.

Lee las repeticiones (.yrpX) que guarda Multirole al terminar cada duelo, apunta quién
ganó y con qué deck, reconoce a qué personaje se parece cada deck y lo muestra en una
página web: ranking de jugadores, de personajes y de torneos. Los puntos funcionan como un
sistema Elo: cada personaje empieza con los puntos de su tier (tiers.json) y ganar
con un personaje débil contra uno fuerte vale más. Los torneos se definen en torneos.json.
Desde /admin, 4RMAss puede anular un resultado o cambiar el ganador.

tiers.json, torneos.json, personajes.json y este mismo programa se actualizan solos desde el
repositorio de GitHub cada 10 minutos. nerfeos.json (sacado de las banlists por personaje) sirve
para avisar de los duelos en que alguien usó cartas nerfeadas para su personaje.
personajes_img.json trae la imagen de cada personaje (se muestra al lado de los ganadores).

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
import re
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
NERFS = os.path.join(DATA_DIR, "nerfeos.json")
SALON = os.path.join(DATA_DIR, "salon_fama.json")
ALIASES = os.path.join(DATA_DIR, "jugadores.json")
CARDS = os.path.join(DATA_DIR, "cartas.json")
IMGS = os.path.join(DATA_DIR, "personajes_img.json")
# las demás direcciones salen de la de personajes.json (misma carpeta "ranking" del repositorio)
URL_BASE = CHARS_URL[:-len("personajes.json")] if CHARS_URL.endswith("personajes.json") else ""
SELF_PATH = os.path.abspath(__file__)
UPDATE_MARK = SELF_PATH + ".actualizado"
REJECTED = SELF_PATH + ".rechazada"  # huella de una versión que falló al arrancar (no se reinstala)
VERSION = "3.5"
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


class Portraits:
    """Imágenes de los personajes (personajes_img.json: nombre -> JPEG en base64)."""
    def __init__(self):
        self.mtime = None
        self.data = {}

    def load(self):
        try:
            mtime = os.path.getmtime(IMGS)
        except OSError:
            self.data, self.mtime = {}, None
            return
        if mtime == self.mtime:
            return
        try:
            raw = json.load(open(IMGS, encoding="utf-8"))
            self.data = {k: base64.b64decode(v) for k, v in raw.items() if not k.startswith("_")}
        except Exception as exc:
            print("personajes_img.json no válido:", exc, flush=True)
            return
        self.mtime = mtime


PORTRAITS = Portraits()


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
            files += [(URL_BASE + "tiers.json", TIERS), (URL_BASE + "torneos.json", TOURN),
                      (URL_BASE + "nerfeos.json", NERFS), (URL_BASE + "salon_fama.json", SALON),
                      (URL_BASE + "jugadores.json", ALIASES)]
        if URL_BASE:
            try:  # la lista de nombres de cartas es grande: se baja como mucho una vez al día
                if not os.path.exists(CARDS) or time.time() - os.path.getmtime(CARDS) > 86400:
                    data = fetch(URL_BASE + "cartas.json")
                    json.loads(data)
                    if not save_if_changed(CARDS, data):
                        os.utime(CARDS)
            except Exception as exc:
                print("No se pudo actualizar cartas.json:", exc, flush=True)
            try:  # las imágenes de los personajes: como mucho una vez por hora
                if not os.path.exists(IMGS) or time.time() - os.path.getmtime(IMGS) > 3600:
                    data = fetch(URL_BASE + "personajes_img.json")
                    json.loads(data)
                    if not save_if_changed(IMGS, data):
                        os.utime(IMGS)
            except Exception as exc:
                print("No se pudo actualizar personajes_img.json:", exc, flush=True)
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
        time.sleep(600)


def load_json(path, default):
    try:
        return json.load(open(path, encoding="utf-8"))
    except Exception:
        return default


# ---------------------------------------------------------------- nerfeos por personaje
class Nerfs:
    def __init__(self):
        self.mtime = None
        self.map = {}
        self.lists = {}

    def load(self):
        try:
            mtime = os.path.getmtime(NERFS)
        except OSError:
            return
        if mtime == self.mtime:
            return
        data = load_json(NERFS, None)
        if not data:
            return
        self.map = data.get("mapa") or {}
        self.lists = {n: [(set(g["ids"]), int(g["max"]), g.get("nombre", "?")) for g in groups]
                      for n, groups in (data.get("listas") or {}).items()}
        self.mtime = mtime

    def check(self, char, cards):
        """Cartas que el deck usa de más según los nerfeos de su personaje ([] si cumple)."""
        names = self.map.get(char) if char else None
        if not names or not cards:
            return []
        cnt = Counter(cards)
        best = None
        for name in names:
            bad = []
            for ids, mx, label in self.lists.get(name, []):
                n = sum(cnt[i] for i in ids)
                if n > mx:
                    bad.append(label if mx == 0 else f"{label} (máx. {mx})")
            if not bad:
                return []  # cumple al menos una de sus listas
            if best is None or len(bad) < len(best):
                best = bad
        return best or []


NERF = Nerfs()


# ---------------------------------------------------------------- nicknames de un mismo jugador
def alias_map():
    """{nick en minúsculas: nombre principal} según jugadores.json."""
    out = {}
    for main, nicks in (load_json(ALIASES, {}).get("alias") or {}).items():
        main = str(main).strip()
        if not main:
            continue
        out[main.lower()] = main
        for n in nicks or []:
            if str(n).strip():
                out[str(n).strip().lower()] = main
    return out


def canon(name, amap):
    return amap.get((name or "").strip().lower(), name)


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
        con.execute("create table if not exists signups(tid text, key text, name text, ts integer, "
                    "primary key(tid, key))")


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
    amap = alias_map()
    for r in rows:
        d = dict(r)
        d["team0"] = [canon(n, amap) for n in json.loads(d["team0"])]
        d["team1"] = [canon(n, amap) for n in json.loads(d["team1"])]
        decks = [json.loads(d.get("decks0") or "[]"), json.loads(d.get("decks1") or "[]")]
        d["chars"] = [[CHAR.detect(decks[t][i]) if i < len(decks[t]) else (None, 0)
                       for i in range(len(d["team" + str(t)]))] for t in (0, 1)]
        d["decks"] = decks
        d["nerf"] = [[NERF.check(d["chars"][t][i][0], decks[t][i] if i < len(decks[t]) else [])
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


FORMAT_LABELS = {"liga": "Liga", "eliminacion": "Eliminación directa", "grupos": "Fase de grupos",
                 "grupos+eliminacion": "Fase de grupos y eliminatoria"}


def norm_format(f):
    f = str(f or "").lower()
    if "grup" in f and "elim" in f:
        return "grupos+eliminacion"
    if "grup" in f:
        return "grupos"
    if "elim" in f:
        return "eliminacion"
    return "liga"


def slug(text):
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-") or "torneo"


def load_signups(tid):
    try:
        with db_lock, db() as con:
            return [r[0] for r in con.execute("select name from signups where tid=? order by ts", (tid,))]
    except Exception:
        return []


def split_team(entry):
    """«Sky&Syrus» o «Kaiser & Coco» -> ['Sky', 'Syrus']."""
    return [p.strip() for p in re.split(r"\s*&\s*", str(entry)) if p.strip()]


def tournaments_info():
    out = []
    amap = alias_map()
    for t in (load_json(TOURN, {}).get("torneos") or []):
        try:
            unit_of = {}   # frozenset(miembros en minúsculas) -> nombre del jugador o del equipo
            members_of = {}

            def unit(entry):
                members = [canon(m, amap) for m in split_team(entry)]
                if not members:
                    return None
                disp = "&".join(members)
                unit_of[frozenset(m.lower() for m in members)] = disp
                members_of[disp] = members
                return disp

            open_ = bool(t.get("inscripcion"))
            tid = slug(str(t.get("nombre") or "Torneo")) + "-" + str(t["inicio"])
            signups = load_signups(tid) if open_ else []
            seeds = [u for u in (unit(p) for p in t.get("participantes") or []) if u]
            groups = {str(g): [u for u in (unit(p) for p in members) if u]
                      for g, members in (t.get("grupos") or {}).items()}
            if open_ and not seeds and not groups:  # sin lista fija: juegan los inscritos
                seeds = [u for u in (unit(p) for p in signups) if u]
            units = seeds + [u for members in groups.values() for u in members if u not in seeds]
            fmt = norm_format(t.get("formato"))
            ko = t.get("inicio_eliminacion")
            name = str(t.get("nombre") or "Torneo")
            label = str(t.get("tipo") or FORMAT_LABELS[fmt])
            out.append({
                "name": name,
                "id": tid,
                "start": parse_day(t["inicio"]),
                "end": parse_day(t.get("fin") or t["inicio"], end=True),
                "start_txt": t["inicio"], "end_txt": t.get("fin") or t["inicio"],
                "seeds": seeds,
                "everyone": units,
                "unit_of": unit_of,
                "teams": any(len(m) > 1 for m in members_of.values()),
                "players": {m.lower() for ms in members_of.values() for m in ms},
                "groups": groups,
                "qualify": max(1, int(t.get("clasifican") or 2)),
                "ko_start": parse_day(ko) if ko else None,
                "ko_txt": ko or "",
                "champion": canon(str(t.get("campeon") or "").strip(), amap),
                "bonus": float(t.get("bono_campeon") or 0),
                "format": fmt,
                "label": label,
                "category": str(t.get("categoria") or "").strip() or label,
                "open": open_,
                "signups": signups,
                "bo": max(1, int(t.get("al_mejor_de") or 1)),
            })
        except Exception as exc:
            print("Torneo mal escrito en torneos.json:", exc, flush=True)
    return out


def valid_duel(d):
    return not (d["annulled"] or d["self"] or d["final"] not in (0, 1, 2) or not d["team0"] or not d["team1"])


def expected(a, b):
    return 1 / (1 + 10 ** ((b - a) / 400))


# ---------------------------------------------------------------- temporadas (año con 2 semestres)
def period_bounds(key):
    if key == "todo":
        return None, None
    m = re.fullmatch(r"(\d{4})(?:-([12]))?", key or "")
    if not m:
        return None
    y = int(m.group(1))
    if m.group(2) is None:
        a, b = datetime(y, 1, 1, tzinfo=TZ), datetime(y + 1, 1, 1, tzinfo=TZ)
    elif m.group(2) == "1":
        a, b = datetime(y, 1, 1, tzinfo=TZ), datetime(y, 7, 1, tzinfo=TZ)
    else:
        a, b = datetime(y, 7, 1, tzinfo=TZ), datetime(y + 1, 1, 1, tzinfo=TZ)
    return a.timestamp(), b.timestamp()


def current_period():
    now = datetime.now(TZ)
    return f"{now.year}-{1 if now.month <= 6 else 2}"


def period_label(key):
    if key == "todo":
        return "Histórico"
    if "-" in key:
        y, s = key.split("-")
        return f"{'I' if s == '1' else 'II'} semestre {y}"
    return f"Temporada {key}"


def period_key(param):
    return param if param and period_bounds(param) is not None else current_period()


def seasons(duels):
    """Temporadas con duelos (o la actual): [(año, [semestres...])], de la más nueva a la más vieja."""
    now = datetime.now(TZ)
    years = {now.year} | {datetime.fromtimestamp(d["ts"], TZ).year for d in duels}
    out = []
    for y in sorted(years, reverse=True):
        sems = [f"{y}-{s}" for s in (2, 1) if period_bounds(f"{y}-{s}")[0] <= time.time()]
        out.append((str(y), sems))
    return out


# ---------------------------------------------------------------- cálculo de puntos y tablas
def stats(duels, start=None, end=None):
    """Puntos, V/D/E, racha y forma por jugador; puntos por personaje; torneos; en el periodo dado.
    Añade a cada duelo: 'tour' (torneo o None) y 'delta' (puntos ganados/perdidos por lado)."""
    tier, points, default = tiers_info()
    tours = tournaments_info()
    players, chars = {}, {}
    history = {}

    def inside(ts):
        return (start is None or ts >= start) and (end is None or ts < end)

    def row(table, key, display):
        return table.setdefault(key, {"name": display, "w": 0, "l": 0, "d": 0, "spell": Counter(),
                                      "fav": Counter(), "pts": None, "res": []})

    def char_pts(c):
        s = chars.get(c)
        if s is not None and s["pts"] is not None:
            return s["pts"]
        return points[tier(c)] if c else points[default]

    def player_pts(k):
        s = players.get(k)
        return s["pts"] if s is not None and s["pts"] is not None else START_PLAYER

    events = [(d["ts"], 0, d) for d in duels if valid_duel(d) and inside(d["ts"])]
    for t in tours:
        if t["champion"] and t["bonus"] and inside(t["end"]):
            events.append((t["end"], 1, t))
    events.sort(key=lambda e: (e[0], e[1], e[2]["file"] if e[1] == 0 else ""))

    for t in tours:
        t["table"] = {}
        t["wchars"] = {}  # personaje con el que ganó su último duelo del torneo cada jugador
        t["pairs"] = Counter()
        t["gtables"] = {g: {} for g in t["groups"]}
        for u in t["everyone"]:
            row(t["table"], u.lower(), u)
        for g, members in t["groups"].items():
            for p in members:
                row(t["gtables"][g], p.lower(), p)
    for ts, kind, d in events:
        if kind == 1:  # bono al campeón al terminar el torneo
            if ts <= time.time():
                k = d["champion"].lower()
                s = row(players, k, d["champion"])
                s["pts"] = player_pts(k) + d["bonus"]
                history.setdefault(k, []).append((ts, s["pts"]))
            continue
        keys = [[n.lower() for n in d["team" + str(s)]] for s in (0, 1)]
        everyone = set(keys[0]) | set(keys[1])
        sides = [frozenset(keys[0]), frozenset(keys[1])]
        d["tour"] = next((t for t in tours if t["start"] <= d["ts"] < t["end"]
                          and sides[0] in t["unit_of"] and sides[1] in t["unit_of"]), None)
        k_factor = K_BASE * (K_TOURNAMENT if d["tour"] else 1)
        r0 = 0.5 if d["final"] == 2 else (1.0 if d["final"] == 0 else 0.0)
        side_chars = [[c for c, _p in d["chars"][s]] for s in (0, 1)]
        # fuerza de cada lado = puntos de sus jugadores + ventaja/desventaja de su personaje
        strength, cstr = [], []
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
                p["res"].append(result)
                p["pts"] = player_pts(k) + sign * delta
                history.setdefault(k, []).append((d["ts"], p["pts"]))
                if c:
                    p["fav"][c] += 1
                    cr = row(chars, c, c)
                    cr["spell"][c] += 1
                    cr[result] += 1
                    cr["pts"] = char_pts(c) + (0 if same else sign * cdelta)
        t = d["tour"]
        if t:
            units = [t["unit_of"][sides[0]], t["unit_of"][sides[1]]]
            if d["final"] in (0, 1):
                for k, c in zip(keys[d["final"]], side_chars[d["final"]]):
                    if c:
                        t["wchars"][k] = c
            ures = ["d" if d["final"] == 2 else ("w" if d["final"] == s_ else "l") for s_ in (0, 1)]
            for u, r_ in zip(units, ures):
                tr = row(t["table"], u.lower(), u)
                tr["spell"][u] += 1
                tr[r_] += 1
            group_phase = t["format"] in ("grupos", "grupos+eliminacion") and (
                t["ko_start"] is None or d["ts"] < t["ko_start"])
            d["phase"] = ""
            if group_phase:
                ul = {units[0].lower(), units[1].lower()}
                g = next((g for g, m in t["groups"].items() if ul <= {x.lower() for x in m}), None)
                if g is not None:
                    d["phase"] = f"Grupo {g}"
                    for u, r_ in zip(units, ures):
                        gr = row(t["gtables"][g], u.lower(), u)
                        gr["spell"][u] += 1
                        gr[r_] += 1
            elif t["format"] in ("eliminacion", "grupos+eliminacion"):
                d["phase"] = "Eliminatoria"
                if d["final"] in (0, 1):
                    w_, l_ = (units[0], units[1]) if d["final"] == 0 else (units[1], units[0])
                    t["pairs"][(w_.lower(), l_.lower())] += 1

    def finish(table, by_points=True):
        rows = list(table.values())
        for s in rows:
            s["name"] = s["spell"].most_common(1)[0][0] if s["spell"] else s["name"]
            s["key"] = s["name"].lower()
            s["total"] = s["w"] + s["l"] + s["d"]
            s["pct"] = round(100 * s["w"] / s["total"]) if s["total"] else 0
            s["favorite"] = s["fav"].most_common(1)[0][0] if s["fav"] else ""
            s["points"] = round(s["pts"]) if s["pts"] is not None else START_PLAYER
            s["tpts"] = 3 * s["w"] + s["d"]
            s["form"] = s["res"][-5:]
            streak = 0
            for r in reversed(s["res"]):
                if r != "w":
                    break
                streak += 1
            s["streak"] = streak
        if by_points:
            rows.sort(key=lambda s: (-s["points"], -s["w"], s["l"], s["name"].lower()))
        else:
            rows.sort(key=lambda s: (-s["tpts"], -s["w"], s["l"], s["name"].lower()))
        return rows

    prow = [s for s in finish(players) if s["total"]]
    for i, s in enumerate(prow, 1):
        s["pos"] = i
        s["history"] = history.get(s["key"], [])
    crow = finish(chars)
    for c in crow:
        c["tier"] = tier(c["name"])
    now = time.time()
    for t in tours:
        t["rows"] = finish(t["table"], by_points=False)
        t["state"] = "Próximo" if now < t["start"] else ("En curso" if now < t["end"] else "Terminado")
        t["group_rows"] = {g: finish(gt, by_points=False) for g, gt in t["gtables"].items()}
        seeds = None
        if t["format"] == "eliminacion":
            seeds = list(t["seeds"])
        elif t["format"] == "grupos+eliminacion":
            seeds = ko_seeds(t, now)
        if seeds is not None:
            t["bracket"], champ = bracket(t, seeds)
            if champ and not t["champion"]:
                t["auto_champion"] = champ
    shown = [t for t in tours if (end is None or t["start"] < end) and (start is None or t["end"] > start)]
    return prow, crow, shown


BYE = ""  # lugar vacío en las llaves (pasa directo el otro)


def ko_seeds(t, now):
    """Clasificados de la fase de grupos a la eliminatoria. Con 2 por grupo se cruzan: 1.º A vs 2.º B,
    1.º B vs 2.º A... Mientras no empiece la eliminatoria, los lugares salen como «Por definir»."""
    names = list(t["groups"])
    n = t["qualify"]
    total = n * len(names)
    if t["ko_start"] is None or now < t["ko_start"]:
        return [None] * max(2, total)
    q = {g: [r["name"] for r in t["group_rows"][g]][:n] for g in names}
    for g in names:
        q[g] += [None] * (n - len(q[g]))
    if n == 2 and len(names) % 2 == 0:
        top, bottom = [], []
        for i in range(0, len(names), 2):
            a, b = names[i], names[i + 1]
            top += [q[a][0], q[b][1]]
            bottom += [q[b][0], q[a][1]]
        return top + bottom
    order = [q[g][pos] for pos in range(n) for g in names]
    slots = []
    while order:
        slots.append(order.pop(0))
        if order:
            slots.append(order.pop())
    return slots


def bracket(t, seeds):
    """Llaves de eliminación: se emparejan en el orden dado (1 vs 2, 3 vs 4...). Gana cada llave quien
    llegue antes a las victorias necesarias (al mejor de N) en sus duelos de eliminatoria."""
    seeds = list(seeds)
    size = 1
    while size < max(2, len(seeds)):
        size *= 2
    current = seeds + [BYE] * (size - len(seeds))
    need = t["bo"] // 2 + 1
    rounds = []
    while len(current) > 1:
        matches, nxt = [], []
        for i in range(0, len(current), 2):
            a, b = current[i], current[i + 1]
            wa = wb = 0
            winner = None  # None = por jugar
            if a is None or b is None:
                winner = None
            elif a == BYE or b == BYE:
                winner = b if a == BYE else a
            else:
                wa = t["pairs"][(a.lower(), b.lower())]
                wb = t["pairs"][(b.lower(), a.lower())]
                if wa >= need:
                    winner = a
                elif wb >= need:
                    winner = b
            matches.append({"a": a, "b": b, "wa": wa, "wb": wb, "winner": winner})
            nxt.append(winner)
        rounds.append(matches)
        current = nxt
    champ = current[0] if current and current[0] not in (None, BYE) else None
    return rounds, champ


def head_to_head(duels):
    """Historial (de siempre) entre jugadores y entre personajes, solo en duelos 1 contra 1."""
    hp, hc = {}, {}
    for d in duels:
        if not valid_duel(d) or len(d["team0"]) != 1 or len(d["team1"]) != 1:
            continue
        for table, a, b in ((hp, d["team0"][0].lower(), d["team1"][0].lower()),
                            (hc, d["chars"][0][0][0], d["chars"][1][0][0])):
            if not a or not b or a == b:
                continue
            key = tuple(sorted((a, b)))
            rec = table.setdefault(key, {key[0]: 0, key[1]: 0, "d": 0})
            if d["final"] == 2:
                rec["d"] += 1
            else:
                rec[a if d["final"] == 0 else b] += 1
    return hp, hc


# ---------------------------------------------------------------- páginas
CSS = """
body{font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif;margin:0;background:#0f1320;color:#e8ecf5}
main{max-width:780px;margin:0 auto;padding:16px}a{color:#9fb3ff}
h1{font-size:1.35rem;margin:.2em 0}h2{font-size:1.05rem;margin:1.6em 0 .5em;color:#9fb3ff}
p.sub{color:#9aa3b8;margin:.2em 0 1em}
table{width:100%;border-collapse:collapse;background:#171c2e;border-radius:10px;overflow:hidden}
th,td{padding:8px 6px;text-align:center;border-bottom:1px solid #232a42;font-size:.93rem}
th{background:#1e2540;color:#b9c4e6;font-weight:600}td.n{text-align:left;font-weight:600}
td.n a{color:inherit;text-decoration:none}td.c{text-align:left;color:#c9b6ff;font-size:.85rem}
tr:last-child td{border-bottom:none}.top1 td.n{color:#ffd56b}.top2 td.n{color:#d9dde8}.top3 td.n{color:#e0a46a}
.duel{background:#171c2e;border-radius:10px;padding:8px 10px;margin:6px 0;font-size:.92rem}
.win{color:#7ee2a1;font-weight:700}
.ch{color:#d9ccff;background:#2a2550;border-radius:9px;padding:1px 7px;font-size:.78rem;white-space:nowrap}
.muted{color:#8d96ad;font-size:.82rem}.off{opacity:.45;text-decoration:line-through}
button{background:#2b355c;color:#e8ecf5;border:1px solid #3c4878;border-radius:7px;padding:5px 8px;margin:3px 2px;font-size:.85rem}
button.r{background:#5a2733;border-color:#7a3443}footer{color:#7f88a0;font-size:.8rem;margin:24px 0 8px}
.up{color:#7ee2a1;font-size:.8rem}.down{color:#ff8a8a;font-size:.8rem}
.tour{color:#ffd56b;background:#3a3216;border-radius:9px;padding:1px 7px;font-size:.78rem;white-space:nowrap}
.warn{color:#ffb3b3;background:#4a1f26;border-radius:9px;padding:1px 7px;font-size:.78rem}
.tier{display:inline-block;min-width:2.2em;border-radius:6px;padding:1px 4px;font-weight:700;font-size:.8rem;background:#2a3150}
.tSSS{background:#7a2030}.tSS{background:#7a4a20}.tS{background:#6a6020}.tAp{background:#2f6a30}.tA{background:#215a5a}
.tB{background:#26407a}.tC{background:#4a2f7a}.tD{background:#444a58}
td.p{font-weight:700;color:#ffe9a8}
.form{display:inline-flex;gap:2px;margin-left:4px;vertical-align:middle}
.form i{display:inline-block;width:14px;height:14px;border-radius:3px;font-style:normal;font-size:.62rem;line-height:14px;
text-align:center;color:#0f1320;font-weight:800}.fw{background:#7ee2a1}.fl{background:#ff8a8a}.fd{background:#aab2c5}
.streak{font-size:.78rem;color:#ffb36b;margin-left:3px}
.tabs{display:flex;gap:6px;flex-wrap:wrap;margin:8px 0}.tabs a{background:#1e2540;border:1px solid #2f3a62;border-radius:16px;
padding:4px 10px;font-size:.85rem;color:#c9d3f2;text-decoration:none}.tabs a.on{background:#3a4a8a;color:#fff;border-color:#5b6cc0}
.calc{background:#171c2e;border-radius:10px;padding:12px}
.calc .row{display:flex;gap:8px;align-items:center;flex-wrap:wrap}
.calc .side{flex:1;min-width:150px;display:flex;flex-direction:column;gap:6px}
.calc select{background:#0f1320;color:#e8ecf5;border:1px solid #3c4878;border-radius:7px;padding:7px;font-size:.92rem}
.calc .vs{font-weight:800;color:#9fb3ff;padding:0 4px}
.bar{display:flex;height:30px;border-radius:8px;overflow:hidden;margin:12px 0 6px;font-weight:700;font-size:.9rem}
.bar div{display:flex;align-items:center;justify-content:center;white-space:nowrap;transition:width .3s}
#fa{background:#2f6a9a}#fb{background:#9a3a4a}
.bracket{display:flex;gap:14px;overflow-x:auto;padding:6px 2px 10px}
.round{display:flex;flex-direction:column;justify-content:space-around;gap:10px;min-width:150px}
.round h4{margin:0 0 4px;font-size:.82rem;color:#9fb3ff;text-align:center}
.match{background:#171c2e;border:1px solid #2a3150;border-radius:8px;font-size:.85rem}
.match div{display:flex;justify-content:space-between;padding:5px 8px}.match div+div{border-top:1px solid #232a42}
.match .w{color:#7ee2a1;font-weight:700}.match .tbd{color:#7f88a0;font-style:italic}
.usage{display:flex;align-items:center;gap:8px;margin:4px 0;font-size:.88rem}
.usage .lbl{width:150px;flex-shrink:0}.usage .b{height:14px;background:#5b4bb0;border-radius:4px}
.dl{font-size:.78rem;margin-left:6px;white-space:nowrap}
svg.chart{width:100%;height:auto;background:#171c2e;border-radius:10px}
.picker{display:flex;gap:8px;align-items:center;flex-wrap:wrap;margin:10px 0}
.picker select{background:#171c2e;color:#e8ecf5;border:1px solid #3c4878;border-radius:8px;padding:7px 10px;font-size:.92rem}
details.tours{background:#171c2e;border-radius:10px;padding:4px 10px;margin:6px 0}
details.tours summary{cursor:pointer;padding:8px 0;font-weight:700;color:#ffd56b}
.titem{display:block;padding:8px 2px;border-top:1px solid #232a42;color:#e8ecf5;text-decoration:none}
.titem b{color:#ffe9a8}.live{background:#3a3216;border-radius:10px;padding:8px 10px;margin:6px 0;display:block;
color:#ffe9a8;text-decoration:none}
.groups{display:grid;grid-template-columns:repeat(auto-fit,minmax(230px,1fr));gap:10px}
.podium{display:flex;gap:8px;flex-wrap:wrap;margin:6px 0 10px}.podium div{flex:1;min-width:110px;background:#171c2e;
border-radius:10px;padding:10px;text-align:center;font-weight:700}.podium span{display:block;font-size:1.6rem}
.fame{display:grid;grid-template-columns:repeat(auto-fit,minmax(240px,1fr));gap:10px;margin-top:8px}
.fame .card{background:#171c2e;border-radius:10px;padding:10px 12px}.fame h4{margin:0 0 6px;color:#ffd56b;font-size:.9rem}
.fame .r{display:flex;justify-content:space-between;gap:6px;padding:3px 0;border-top:1px solid #232a42;font-size:.88rem}
.fame .r:first-of-type{border-top:none}.fame .st{white-space:nowrap;color:#ffe9a8}
.badges{display:flex;flex-wrap:wrap;gap:6px;margin:6px 0}.badge{background:#22294a;border:1px solid #34407a;border-radius:9px;
padding:5px 8px;font-size:.85rem}.badge small{display:block;color:#8d96ad;font-size:.75rem}
.icons{font-size:1.05rem;letter-spacing:2px}
.tierrow{display:flex;gap:8px;align-items:flex-start;padding:6px 0;border-top:1px solid #232a42}.tierrow:first-child{border-top:none}
.tierrow .chips{display:flex;flex-wrap:wrap;gap:5px}.chip{background:#22294a;border-radius:8px;padding:2px 7px;font-size:.82rem}
.chip .upc{color:#7ee2a1}.chip .dnc{color:#ff8a8a}
.av{display:inline-block;width:28px;height:28px;border-radius:50%;background:#2a2550 50% 14%/165% no-repeat;
vertical-align:middle;margin-right:5px;border:2px solid #7ee2a1;box-sizing:border-box}
.av.ini{display:inline-flex;align-items:center;justify-content:center;font-size:.6rem;font-weight:800;color:#d9ccff;
font-style:normal}
.avbig{display:inline-block;width:92px;height:92px;border-radius:14px;background:#1e2540 50% 0/cover no-repeat;
border:2px solid #ffd56b;box-sizing:border-box;vertical-align:middle}
.avbig.ini{display:inline-flex;align-items:center;justify-content:center;font-size:1.5rem;font-weight:800;color:#d9ccff}
.champ{display:flex;gap:12px;align-items:center;background:#3a3216;border-radius:12px;padding:10px 12px;margin:10px 0}
.champ .who{font-size:1.1rem;font-weight:800;color:#ffe9a8}.champ .pics{display:flex;gap:6px}
.podium .pics{display:flex;gap:6px;justify-content:center;margin-bottom:4px}
form.sign{display:flex;gap:6px;flex-wrap:wrap;margin:8px 0}form.sign input{flex:1;min-width:150px;background:#0f1320;
color:#e8ecf5;border:1px solid #3c4878;border-radius:7px;padding:7px}
"""


def page(body, title=TITLE):
    return f"""<!DOCTYPE html><html lang="es"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>{html.escape(title)}</title>
<style>{CSS}</style></head><body><main>{body}</main></body></html>"""


def fmt_ts(ts):
    return datetime.fromtimestamp(ts, TZ).strftime("%d/%m/%Y %H:%M")


def q(**kw):
    return "?" + urllib.parse.urlencode({k: v for k, v in kw.items() if v})


def player_link(name, period):
    return f'<a href="/jugador{q(n=name, t=period)}">{html.escape(name)}</a>'


def initials(name):
    words = re.findall(r"[A-Za-z0-9]+", name)
    if not words:
        return "?"
    return (words[0][0] + (words[1][0] if len(words) > 1 else words[0][1:2])).upper()


def avatar(char, cls="av"):
    """Imagen del personaje (o sus iniciales si no hay imagen)."""
    if not char:
        return ""
    title = html.escape(char)
    if char in PORTRAITS.data:
        url = f"/img/{urllib.parse.quote(char)}.jpg?v={int(PORTRAITS.mtime or 0)}"
        return f'<span class="{cls}" title="{title}" style="background-image:url(\'{url}\')"></span>'
    return f'<span class="{cls} ini" title="{title}">{html.escape(initials(char))}</span>'


def side_html(names, chars, won, delta=None, period=None):
    parts = []
    for name, (char, pct) in zip(names, chars):
        txt = player_link(name, period) if name and period else html.escape(name or "?")
        if won:
            txt = f'{avatar(char)}<span class="win">{txt}</span>'
        if delta is not None:
            txt += (f' <span class="up">+{delta}</span>' if delta >= 0 else
                    f' <span class="down">−{-delta}</span>')
        if char:
            txt += f' <span class="ch">{html.escape(char)} · {pct}%</span>'
        parts.append(txt)
    return " y ".join(parts) or "?"


def replay_exists(fn):
    return bool(re.fullmatch(r"\d+\.yrpX", fn)) and os.path.isfile(os.path.join(REPLAYS, fn))


def duel_line(d, period=None):
    f = d["final"]
    delta = d.get("delta") or [None, None]
    a = side_html(d["team0"], d["chars"][0], f == 0, delta[0], period)
    b = side_html(d["team1"], d["chars"][1], f == 1, delta[1], period)
    res = "· Empate" if f == 2 else ("· Sin resultado" if f not in (0, 1) else "")
    why = REASONS.get(d["reason"], "Efecto de carta" if (d["reason"] or 0) >= 0x10 else "")
    extra = []
    if d["corrected"] is not None:
        extra.append("corregido por 4RMAss")
    if why:
        extra.append(why)
    meta = html.escape(" · ".join([fmt_ts(d["ts"])] + extra))
    if replay_exists(d["file"]):
        meta += f' <a class="dl" href="/replay/{html.escape(d["file"])}" download>⬇ Repetición</a>'
    tour = (f' <a class="tour" style="text-decoration:none" href="/torneo{q(id=d["tour"]["id"])}">🏆 '
            f'{html.escape(d["tour"]["name"])}</a>' if d.get("tour") else "")
    warns = []
    for side in (0, 1):
        for name, bad in zip(d["team" + str(side)], d.get("nerf", [[], []])[side]):
            if bad:
                shown = ", ".join(bad[:4]) + (f" y {len(bad) - 4} más" if len(bad) > 4 else "")
                warns.append(f'<div class="muted" title="{html.escape(", ".join(bad))}"><span class="warn">⚠ Nerfeo</span> '
                             f'{html.escape(name)} usó: {html.escape(shown)}</div>')
    return f'{a} <b>vs</b> {b} {res}{tour}<div class="muted">{meta}</div>{"".join(warns)}'


def tier_badge(t):
    cls = "t" + t.replace("+", "p")
    return f'<span class="tier {cls}">{html.escape(t)}</span>'


def form_html(s):
    letters = {"w": ("V", "fw"), "l": ("D", "fl"), "d": ("E", "fd")}
    chips = "".join(f'<i class="{letters[r][1]}">{letters[r][0]}</i>' for r in s["form"])
    streak = f'<span class="streak" title="Victorias seguidas">🔥{s["streak"]}</span>' if s["streak"] >= 2 else ""
    return f'<span class="form" title="Últimos 5 duelos">{chips}</span>{streak}'


def players_table(rows, period):
    if not rows:
        return '<p class="sub">Todavía no hay duelos registrados en esta temporada.</p>'
    head = ('<tr><th>#</th><th>Jugador · forma</th><th>Puntos</th><th>V</th><th>D</th><th>E</th><th>%</th>'
            '<th>Favorito</th></tr>')
    trs = []
    for s in rows:
        trs.append(f'<tr class="top{s["pos"]}"><td>{s["pos"]}</td><td class="n">{player_link(s["name"], period)}'
                   f'<br>{form_html(s)}</td><td class="p">{s["points"]}</td><td>{s["w"]}</td><td>{s["l"]}</td>'
                   f'<td>{s["d"]}</td><td>{s["pct"]}%</td><td class="c">{html.escape(s["favorite"]) or "—"}</td></tr>')
    return f"<table>{head}{''.join(trs)}</table>"


def chars_table(rows):
    if not rows:
        return '<p class="sub">Todavía no hay duelos registrados en esta temporada.</p>'
    head = ('<tr><th>#</th><th>Personaje</th><th>Tier</th><th>Puntos</th><th>V</th><th>D</th><th>E</th>'
            '<th>%</th></tr>')
    trs = []
    for i, s in enumerate(rows, 1):
        trs.append(f'<tr class="top{i}"><td>{i}</td><td class="n">{html.escape(s["name"])}</td>'
                   f'<td>{tier_badge(s["tier"])}</td><td class="p">{s["points"]}</td><td>{s["w"]}</td>'
                   f'<td>{s["l"]}</td><td>{s["d"]}</td><td>{s["pct"]}%</td></tr>')
    return f"<table>{head}{''.join(trs)}</table>"


def usage_html(chars):
    if not chars:
        return '<p class="sub">Todavía no hay datos.</p>'
    total = sum(c["total"] for c in chars) or 1
    rows = sorted(chars, key=lambda c: (-c["total"], c["name"].lower()))[:10]
    top = rows[0]["total"] or 1
    return "".join(f'<div class="usage"><span class="lbl">{html.escape(c["name"])}</span>'
                   f'<span class="b" style="width:{max(4, round(60 * c["total"] / top))}%"></span>'
                   f'<span class="muted">{c["total"]} · {round(100 * c["total"] / total)}%</span></div>'
                   for c in rows)


def matchups_html(hc):
    if not hc:
        return '<p class="sub">Todavía no hay duelos entre personajes distintos.</p>'
    items = sorted(hc.items(), key=lambda kv: (-(sum(v for k, v in kv[1].items())), kv[0]))[:25]
    trs = []
    for (a, b), rec in items:
        n = rec[a] + rec[b] + rec["d"]
        pa = round(100 * (rec[a] + rec["d"] / 2) / n) if n else 50
        if rec[b] > rec[a]:
            a, b, pa = b, a, 100 - pa
        emp = f' <span class="muted">({rec["d"]} E)</span>' if rec["d"] else ""
        trs.append(f'<tr><td class="n">{html.escape(a)} <span class="muted">vs</span> {html.escape(b)}</td>'
                   f'<td>{rec[a]} - {rec[b]}{emp}</td><td>{pa}% - {100 - pa}%</td><td>{n}</td></tr>')
    return ('<table><tr><th>Enfrentamiento</th><th>Resultado</th><th>Porcentaje</th><th>Duelos</th></tr>'
            + "".join(trs) + "</table>")


def bracket_html(t):
    names = {1: "Final", 2: "Semifinal", 4: "Cuartos de final", 8: "Octavos de final"}
    cols = []
    for rnd in t["bracket"]:
        title = names.get(len(rnd), f"Ronda de {2 * len(rnd)}")
        boxes = []
        for m in rnd:
            def cell(p, w):
                if p is None:
                    return '<div><span class="tbd">Por definir</span></div>'
                if p == BYE:
                    return '<div><span class="tbd">—</span></div>'
                cls = ' class="w"' if m["winner"] == p else ""
                return f'<div><span{cls}>{html.escape(p)}</span><b>{w}</b></div>'
            boxes.append(f'<div class="match">{cell(m["a"], m["wa"])}{cell(m["b"], m["wb"])}</div>')
        cols.append(f'<div class="round"><h4>{title}</h4>{"".join(boxes)}</div>')
    return f'<div class="bracket">{"".join(cols)}</div>'


def tour_champion(t):
    return t["champion"] or t.get("auto_champion") or (
        t["rows"][0]["name"] if t["state"] == "Terminado" and t["rows"] and t["format"] == "liga"
        and t["rows"][0]["total"] else "")


def champ_chars(t):
    """[(jugador, personaje)] del campeón (o de cada miembro de la pareja campeona):
    el personaje con el que ganó su último duelo del torneo (en eliminatoria, la final)."""
    champ = tour_champion(t)
    if not champ:
        return []
    amap = alias_map()
    out = []
    for name in split_team(champ):
        out.append((name, (t.get("wchars") or {}).get(canon(name, amap).lower())))
    return out


def tour_summary(t):
    info = f'{t["label"]} · {t["start_txt"]} al {t["end_txt"]} · {t["state"]}'
    champ = tour_champion(t)
    if champ:
        info += f" · Campeón: {champ}"
    return info


def league_table(rows, qualify=0):
    if not rows:
        return '<p class="sub">Sin participantes.</p>'
    head = '<tr><th>#</th><th>Jugador</th><th>Pts</th><th>V</th><th>D</th><th>E</th><th>Duelos</th></tr>'
    trs = "".join(f'<tr class="top{i}"><td>{i}{" ✓" if qualify and i <= qualify else ""}</td>'
                  f'<td class="n">{html.escape(r["name"])}</td><td class="p">{r["tpts"]}</td><td>{r["w"]}</td>'
                  f'<td>{r["l"]}</td><td>{r["d"]}</td><td>{r["total"]}</td></tr>' for i, r in enumerate(rows, 1))
    return f"<table>{head}{trs}</table>"


def tournament_body(t):
    parts = []
    if t["format"] in ("grupos", "grupos+eliminacion"):
        q = t["qualify"] if t["format"] == "grupos+eliminacion" else 0
        boxes = "".join(f'<div><h3 style="margin:.4em 0">Grupo {html.escape(g)}</h3>{league_table(rows, q)}</div>'
                        for g, rows in t["group_rows"].items())
        note = (f'<p class="sub">✓ = clasifica a la eliminatoria ({q} por grupo).</p>' if q else "")
        parts.append(f'<h2>Fase de grupos</h2>{note}<div class="groups">{boxes}</div>')
    if t["format"] in ("eliminacion", "grupos+eliminacion"):
        when = (f' <span class="muted">(desde el {html.escape(t["ko_txt"])})</span>'
                if t["format"] == "grupos+eliminacion" and t["ko_txt"] else "")
        parts.append(f'<h2>Eliminatoria{when}</h2><p class="sub">Al mejor de {t["bo"]}: pasa quien gane '
                     f'{t["bo"] // 2 + 1} duelo(s) primero.</p>{bracket_html(t)}')
    if t["format"] == "liga":
        parts.append(f'<h2>Tabla</h2><p class="sub">3 puntos por victoria y 1 por empate.</p>{league_table(t["rows"])}')
    return "".join(parts)


def tournaments_list_html(tours):
    if not tours:
        return '<p class="sub">Todavía no hay torneos. 4RMAss los anuncia aquí cuando los organiza.</p>'
    ordered = sorted(tours, key=lambda t: -t["start"])
    live = "".join(f'<a class="live" href="/torneo{q(id=t["id"])}">🔴 En curso: <b>{html.escape(t["name"])}</b>'
                   f'<div class="muted">{html.escape(tour_summary(t))}</div></a>'
                   for t in ordered if t["state"] == "En curso")
    upcoming = sorted((t for t in ordered if t["state"] == "Próximo"), key=lambda t: t["start"])
    if upcoming:
        live += ('<details class="tours" open><summary>📅 Próximos torneos</summary>'
                 + "".join(f'<a class="titem" href="/torneo{q(id=t["id"])}"><b>{html.escape(t["name"])}</b>'
                           f'{" · inscripciones abiertas" if t["open"] else ""}'
                           f'<div class="muted">{html.escape(tour_summary(t))}</div></a>' for t in upcoming)
                 + "</details>")
    cats = {}
    for t in ordered:  # cada tipo en su apartado, del más reciente al primero
        cats.setdefault(t["category"], []).append(t)
    boxes = "".join(
        f'<details class="tours"><summary>🏆 {html.escape(cat)} ({len(lst)})</summary>'
        + "".join(f'<a class="titem" href="/torneo{q(id=t["id"])}">'
                  f'{"".join(avatar(c) for _n, c in champ_chars(t) if c)}<b>{html.escape(t["name"])}</b>'
                  f'<div class="muted">{html.escape(tour_summary(t))}</div></a>' for t in lst)
        + "</details>" for cat, lst in cats.items())
    return live + boxes


def render_tournament(params):
    tid = (params.get("id") or [""])[0]
    duels = load_duels()
    _p, _c, tours = stats(duels)
    t = next((x for x in tours if x["id"] == tid), None)
    back = '<p><a href="/">← Volver al ranking</a></p>'
    if not t:
        return page(f'{back}<p>No existe ese torneo.</p>', "Torneo · " + TITLE)
    mine = sorted((d for d in duels if d.get("tour") is t), key=lambda d: -d["ts"])
    def phase(d):
        return f'<div class="muted">{html.escape(d["phase"])}</div>' if d.get("phase") else ""

    dl = ("".join(f'<div class="duel">{phase(d)}{duel_line(d, "todo")}</div>' for d in mine)
          or '<p class="sub">Todavía no hay duelos.</p>')
    bonus = f" (+{round(t['bonus'])} puntos de bono)" if t["champion"] and t["bonus"] else ""
    signup = ""
    if t["open"]:
        lst = ", ".join(html.escape(n) for n in t["signups"]) or "—"
        form = ""
        if t["state"] == "Próximo":
            msg = '<p class="sub" style="color:#7ee2a1">¡Listo, quedaste inscrito!</p>' if params.get("ok") else ""
            form = (f'{msg}<form class="sign" method="post" action="/inscribir"><input type="hidden" name="id" '
                    f'value="{html.escape(t["id"])}"><input name="nombre" maxlength="30" required '
                    f'placeholder="Tu nombre en EDOPro"><button>Inscribirme</button></form>')
        signup = (f'<h2>Inscripciones</h2><p class="sub">Escribe tu nombre tal como lo usas en EDOPro.</p>{form}'
                  f'<p class="sub">Inscritos ({len(t["signups"])}): {lst}</p>')
    champ_box = ""
    cc = champ_chars(t)
    if cc:
        pics = "".join(avatar(c, "avbig") for _n, c in cc if c)
        with_ = " y ".join(f"{html.escape(n)} ({html.escape(c)})" if c else html.escape(n) for n, c in cc)
        champ_box = (f'<div class="champ">{f"<div class=pics>{pics}</div>" if pics else ""}<div>'
                     f'<div class="muted">🥇 Campeón</div><div class="who">{with_}</div></div></div>')
    body = f"""{back}<h1>🏆 {html.escape(t["name"])}</h1>
<p class="sub">{html.escape(tour_summary(t))}{html.escape(bonus)}</p>
{champ_box}
<p class="sub">Participantes: {html.escape(", ".join(t["everyone"]) or "—")}. Los duelos del torneo valen el doble
en la tabla general.</p>
{signup}
{tournament_body(t)}
<h2>Duelos del torneo</h2>{dl}
<footer>v{VERSION}</footer>"""
    return page(body, t["name"] + " · " + TITLE)


# ---------------------------------------------------------------- salón de la fama automático
def tour_podium(t):
    """Podio de un torneo terminado: 1.º, 2.º y 3.º (en eliminatoria, los que perdieron en semifinal)."""
    champ = tour_champion(t)
    if not champ:
        return []
    second, third = "", []
    if t.get("bracket"):
        rounds = t["bracket"]
        final = rounds[-1][0]
        if final["winner"]:
            second = final["b"] if final["winner"] == final["a"] else final["a"]
        if len(rounds) >= 2:
            for m in rounds[-2]:
                if m["winner"] and m["a"] not in (None, BYE) and m["b"] not in (None, BYE):
                    third.append(m["b"] if m["winner"] == m["a"] else m["a"])
    else:
        rows = [r for r in t["rows"] if r["total"] and r["name"] != champ]
        second = rows[0]["name"] if rows else ""
        third = [rows[1]["name"]] if len(rows) > 1 else []
    out = [["🥇", champ]]
    if second and second not in (None, BYE):
        out.append(["🥈", second])
    if third:
        out.append(["🥉", " & ".join(x for x in third if x)])
    return out


def salon_data(all_tours):
    """Salón de la Fama: lo escrito en salon_fama.json más los campeones de los torneos del servidor."""
    data = load_json(SALON, {})
    cats = [{"nombre": c.get("nombre", ""), "campeones": [list(x) for x in c.get("campeones") or []]}
            for c in data.get("categorias") or []]
    last = data.get("ultimo_torneo") or {}
    amap = alias_map()
    finished = sorted((t for t in all_tours if t["state"] == "Terminado" and tour_champion(t)),
                      key=lambda t: t["end"])
    for t in finished:
        champ = tour_champion(t)
        cat = next((c for c in cats if c["nombre"].strip().lower() == t["category"].strip().lower()), None)
        if cat is None:
            cat = {"nombre": t["category"], "campeones": []}
            cats.append(cat)
        key = canon(champ, amap).lower()
        entry = next((e for e in cat["campeones"] if canon(str(e[0]), amap).lower() == key), None)
        if entry:
            entry[1] = int(entry[1]) + 1
        else:
            cat["campeones"].append([champ, 1])
        cat["campeones"].sort(key=lambda e: -int(e[1]))
    if finished:
        pod = tour_podium(finished[-1])
        if pod:
            last = {"nombre": finished[-1]["name"], "podio": pod,
                    "personajes": [c for _n, c in champ_chars(finished[-1]) if c]}
    return cats, last


# ---------------------------------------------------------------- logros
ACHIEVEMENTS = [
    ("first", "🎉", "Primera victoria", "Ganó su primer duelo"),
    ("w10", "🔟", "10 victorias", "Ganó 10 duelos"),
    ("w25", "🏅", "25 victorias", "Ganó 25 duelos"),
    ("w50", "👑", "50 victorias", "Ganó 50 duelos"),
    ("s3", "🔥", "Racha de 3", "Ganó 3 duelos seguidos"),
    ("s5", "☄️", "Racha de 5", "Ganó 5 duelos seguidos"),
    ("s10", "🌋", "Racha de 10", "Ganó 10 duelos seguidos"),
    ("giant", "🗡️", "Matagigantes", "Le ganó a un personaje SSS o SS con uno de tier C o D"),
    ("upset", "⚡", "Gran sorpresa", "Ganó 40 puntos o más en un solo duelo"),
    ("collector", "🎭", "Coleccionista", "Jugó con 5 personajes distintos"),
    ("loyal", "❤️", "Fiel", "Jugó 10 duelos con el mismo personaje"),
    ("champ", "🏆", "Campeón", "Ganó un torneo del servidor"),
]


def achievements(duels, all_tours):
    """Logros de cada jugador con todos sus duelos (se llama justo después de stats() de todo el historial)."""
    tier, _points, _default = tiers_info()
    wins, streak, best, chars, got = Counter(), Counter(), Counter(), {}, {}

    def give(k, code):
        got.setdefault(k, set()).add(code)

    for d in sorted((d for d in duels if valid_duel(d)), key=lambda d: d["ts"]):
        for side in (0, 1):
            won = d["final"] == side
            opp = [c for c, _p in d["chars"][1 - side]]
            for name, (c, _pct) in zip(d["team" + str(side)], d["chars"][side]):
                k = name.lower()
                if c:
                    chars.setdefault(k, Counter())[c] += 1
                if won:
                    wins[k] += 1
                    streak[k] += 1
                    best[k] = max(best[k], streak[k])
                    if c and tier(c) in ("C", "D") and any(o and tier(o) in ("SSS", "SS") for o in opp):
                        give(k, "giant")
                    if (d.get("delta") or [0, 0])[side] >= 40:
                        give(k, "upset")
                elif d["final"] != 2:
                    streak[k] = 0
    for k, w in wins.items():
        for n, code in ((1, "first"), (10, "w10"), (25, "w25"), (50, "w50")):
            if w >= n:
                give(k, code)
    for k, b in best.items():
        for n, code in ((3, "s3"), (5, "s5"), (10, "s10")):
            if b >= n:
                give(k, code)
    for k, cs in chars.items():
        if len(cs) >= 5:
            give(k, "collector")
        if cs and max(cs.values()) >= 10:
            give(k, "loyal")
    for t in all_tours:
        champ = tour_champion(t)
        if t["state"] == "Terminado" and champ:
            for m in split_team(champ):
                give(m.lower(), "champ")
    return {k: [a for a in ACHIEVEMENTS if a[0] in codes] for k, codes in got.items()}


def achievements_html(players, ach):
    rows = [(s, ach.get(s["key"], [])) for s in players]
    rows = [(s, a) for s, a in rows if a]
    if not rows:
        return ""
    items = "".join(f'<div class="r"><span>{html.escape(s["name"])}</span><span class="icons" '
                    f'title="{html.escape(", ".join(x[2] for x in a))}">{"".join(x[1] for x in a)}</span></div>'
                    for s, a in sorted(rows, key=lambda r: -len(r[1])))
    legend = " · ".join(f"{a[1]} {a[2]}" for a in ACHIEVEMENTS)
    return (f'<h2>🏅 Logros</h2><details class="tours"><summary>Ver los logros de cada jugador</summary>'
            f'<div class="fame"><div class="card">{items}</div></div><p class="muted">{html.escape(legend)}</p>'
            f'</details>')


# ---------------------------------------------------------------- la mayor sorpresa
def biggest_upset(duels):
    best = None
    for d in duels:
        if not valid_duel(d) or d["final"] not in (0, 1) or not d.get("delta"):
            continue
        g = d["delta"][d["final"]]
        if g > 0 and (best is None or g > best[0]):
            best = (g, d)
    return best


def upsets_html(period_duels, key):
    week = [d for d in period_duels if d["ts"] >= time.time() - 7 * 86400]
    parts = []
    for label, lst in (("Esta semana", week), (period_label(key), period_duels)):
        b = biggest_upset(lst)
        if b:
            parts.append(f'<p class="sub"><b>{html.escape(label)}:</b> +{b[0]} puntos</p>'
                         f'<div class="duel">{duel_line(b[1], key)}</div>')
    if not parts:
        return ""
    return ('<h2>⚡ La mayor sorpresa</h2><p class="sub">El duelo en que el ganador sumó más puntos '
            'venciendo a alguien que era favorito.</p>' + "".join(parts))


# ---------------------------------------------------------------- estadísticas de cartas
CARD_NAMES = {"mtime": None, "names": {}}


def card_names():
    try:
        mtime = os.path.getmtime(CARDS)
    except OSError:
        return {}
    if CARD_NAMES["mtime"] != mtime:
        data = load_json(CARDS, {})
        CARD_NAMES["names"] = {int(k): v for k, v in (data.get("n") or {}).items()}
        CARD_NAMES["mtime"] = mtime
    return CARD_NAMES["names"]


def cards_html(period_duels):
    names = card_names()
    if not names:
        return ""
    used, won, decks = Counter(), Counter(), 0
    for d in period_duels:
        if not valid_duel(d):
            continue
        for side in (0, 1):
            for deck in (d.get("decks") or [[], []])[side]:
                cards = {names[c] for c in deck if c in names}
                if not cards:
                    continue
                decks += 1
                for c in cards:
                    used[c] += 1
                    if d["final"] == side:
                        won[c] += 1
    if not decks:
        return ""
    top = used.most_common(15)
    min_uses = max(3, round(decks * 0.1))
    best = sorted(((c, won[c] / n, n) for c, n in used.items() if n >= min_uses), key=lambda x: (-x[1], -x[2]))[:10]

    def table(rows, head):
        return (f'<table><tr><th>Carta</th><th>{head[0]}</th><th>{head[1]}</th></tr>'
                + "".join(f'<tr><td class="n">{html.escape(c)}</td><td>{a}</td><td>{b}</td></tr>' for c, a, b in rows)
                + "</table>")
    t1 = table([(c, f"{round(100 * n / decks)}%", f"{round(100 * won[c] / n)}%") for c, n in top],
               ("En decks", "Ganan"))
    t2 = (table([(c, f"{round(100 * w)}%", n) for c, w, n in best], ("Ganan", "Decks")) if best else
          f'<p class="sub">Todavía faltan duelos (cada carta necesita estar en {min_uses} decks).</p>')
    return (f'<h2>🃏 Estadísticas de cartas</h2><details class="tours"><summary>Ver las cartas más usadas y las que más '
            f'ganan ({decks} decks)</summary><h3 style="margin:.6em 0 .3em">Las más usadas</h3>{t1}'
            f'<h3 style="margin:.9em 0 .3em">Las que más ganan</h3><p class="muted">Solo cartas que estuvieron en '
            f'{min_uses} decks o más.</p>{t2}</details>')


# ---------------------------------------------------------------- tier list en vivo
def tierlist_html(chars):
    tier, points, _default = tiers_info()
    order = sorted(points, key=lambda t: -points[t])
    live = {c["name"]: c["points"] for c in chars}
    all_names = set(load_json(TIERS, {}).get("personajes") or {}) | set(live)

    def performs(p):
        return next((t for t in order if p >= points[t]), order[-1])

    rows = []
    for t in order:
        members = sorted((n for n in all_names if tier(n) == t), key=lambda n: (-live.get(n, points[t]), n.lower()))
        if not members:
            continue
        chips = []
        for n in members:
            p = live.get(n)
            if p is None:
                chips.append(f'<span class="chip muted">{html.escape(n)}</span>')
                continue
            pt = performs(p)
            arrow = ""
            if order.index(pt) < order.index(t):
                arrow = f' <span class="upc">▲ {html.escape(pt)}</span>'
            elif order.index(pt) > order.index(t):
                arrow = f' <span class="dnc">▼ {html.escape(pt)}</span>'
            chips.append(f'<span class="chip">{html.escape(n)} · {p}{arrow}</span>')
        rows.append(f'<div class="tierrow">{tier_badge(t)}<div class="chips">{"".join(chips)}</div></div>')
    return ('<h2>📊 Tier list en vivo</h2><details class="tours"><summary>Ver la tier list con los puntos de '
            'esta temporada</summary><p class="muted">▲/▼ = con sus puntos actuales rinde como otra tier. En gris, '
            f'los que aún no jugaron.</p>{"".join(rows)}</details>')


def salon_html(all_tours):
    cats, last = salon_data(all_tours)
    if not cats and not last.get("podio"):
        return ""
    champ_pics = "".join(avatar(c, "avbig") for c in last.get("personajes") or [])
    podium = "".join(f'<div>{f"<div class=pics>{champ_pics}</div>" if i == 0 and champ_pics else ""}'
                     f'<span>{html.escape(str(m))}</span>{html.escape(str(n))}</div>'
                     for i, (m, n) in enumerate(last.get("podio") or []))
    podium_html = (f'<p class="sub">Resultados del último torneo{": " + html.escape(last["nombre"]) if last.get("nombre") and last["nombre"] != "Último torneo" else ""}</p>'
                   f'<div class="podium">{podium}</div>' if podium else "")

    def stars(n):
        n = int(n)
        return ("🌟" * n if n <= 6 else "🌟 × " + str(n))

    cards = "".join(
        f'<div class="card"><h4>{html.escape(c.get("nombre", ""))}</h4>'
        + "".join(f'<div class="r"><span>{html.escape(str(n))}</span><span class="st">{stars(k)}</span></div>'
                  for n, k in c.get("campeones") or [])
        + "</div>" for c in cats)
    return (f'<h2>🏛️ Salón de la Fama</h2><p class="sub">Campeones de los torneos, desde antes del servidor. '
            f'Cada 🌟 es un torneo ganado.</p>{podium_html}'
            f'<details class="tours"><summary>Ver campeones por categoría ({len(cats)})</summary>'
            f'<div class="fame">{cards}</div></details>')


def favorites_html(players, chars, hp, hc):
    """Calculadora de favoritismo: probabilidad de ganar de cada jugador según sus puntos y los de
    su personaje (la misma cuenta que usan los puntos del ranking; no hay empates)."""
    tier, points, default = tiers_info()
    cdata = {}
    for name in (load_json(TIERS, {}).get("personajes") or {}):
        cdata[name] = {"p": points[tier(name)], "t": tier(name)}
    for c in chars:
        cdata[c["name"]] = {"p": c["points"], "t": c["tier"]}
    clist = [{"n": n, "p": v["p"], "t": v["t"]} for n, v in sorted(cdata.items(), key=lambda kv: kv[0].lower())]
    plist = [{"n": s["name"], "k": s["key"], "p": s["points"], "f": s["favorite"]} for s in players]
    plist.append({"n": "Otro jugador (sin duelos)", "k": "", "p": START_PLAYER, "f": ""})
    hpj = {f"{a}|{b}": [r[a], r[b], r["d"]] for (a, b), r in hp.items()}
    hcj = {f"{a}|{b}": [r[a], r[b], r["d"]] for (a, b), r in hc.items()}
    data = json.dumps({"P": plist, "C": clist, "D": points[default], "S": START_PLAYER, "HP": hpj, "HC": hcj},
                      ensure_ascii=False).replace("</", "<\\/")
    return f"""<h2>Favoritismo</h2>
<p class="sub">Elige a los dos jugadores y con qué personaje juega cada uno. Se calcula con los puntos del
jugador y los de su personaje, igual que el ranking. En Yu-Gi-Oh! no hay empates, así que entre los dos
siempre suman 100%. Debajo sale el historial entre ellos y entre sus personajes.</p>
<div class="calc"><div class="row">
<div class="side"><select id="pa"></select><select id="ca"></select></div>
<div class="vs">vs</div>
<div class="side"><select id="pb"></select><select id="cb"></select></div>
</div><div class="bar"><div id="fa"></div><div id="fb"></div></div>
<div class="muted" id="fr"></div><div class="muted" id="fh"></div></div>
<script>
(function(){{
const X={data};
const $=id=>document.getElementById(id);
function fill(sel,list,label){{sel.innerHTML="";list.forEach((o,i)=>{{const op=document.createElement("option");
op.value=i;op.textContent=label(o);sel.appendChild(op);}});}}
const none={{n:"Sin personaje reconocido",p:X.D,t:""}};
const C=[none].concat(X.C);
fill($("pa"),X.P,o=>o.n+" ("+o.p+" pts)");fill($("pb"),X.P,o=>o.n+" ("+o.p+" pts)");
fill($("ca"),C,o=>o.t?o.n+" · "+o.t+" ("+o.p+")":o.n);fill($("cb"),C,o=>o.t?o.n+" · "+o.t+" ("+o.p+")":o.n);
function fav(pi,cs){{const f=X.P[pi].f;const k=C.findIndex(c=>c.n===f);cs.value=k>0?k:0;}}
$("pb").value=X.P.length>2?1:0;fav($("pa").value,$("ca"));fav($("pb").value,$("cb"));
function rec(T,a,b){{if(!a||!b||a===b)return null;const k1=a+"|"+b,k2=b+"|"+a;
if(T[k1])return T[k1];if(T[k2]){{const r=T[k2];return [r[1],r[0],r[2]];}}return [0,0,0];}}
function hist(T,a,b,na,nb){{const r=rec(T,a,b);if(!r)return "";const e=r[2]?" ("+r[2]+(r[2]==1?" empate)":" empates)"):"";
return na+" "+r[0]+" - "+r[1]+" "+nb+e;}}
function upd(){{const a=X.P[$("pa").value],b=X.P[$("pb").value],ca=C[$("ca").value],cb=C[$("cb").value];
const sa=a.p+(ca.p-X.S),sb=b.p+(cb.p-X.S);const p=1/(1+Math.pow(10,(sb-sa)/400));
let pa=Math.round(100*p);if(pa<1)pa=1;if(pa>99)pa=99;const pb=100-pa;
$("fa").style.width=pa+"%";$("fb").style.width=pb+"%";
$("fa").textContent=pa+"%";$("fb").textContent=pb+"%";
const na=a.n+" ("+ca.n+")",nb=b.n+" ("+cb.n+")";
$("fr").textContent=pa===pb?"Duelo parejo: 50% y 50%.":(pa>pb?na:nb)+" es favorito: "+Math.max(pa,pb)+"% contra "+Math.min(pa,pb)+"%.";
const h1=hist(X.HP,a.k,b.k,a.n,b.n),h2=ca.t&&cb.t?hist(X.HC,ca.n,cb.n,ca.n,cb.n):"";
$("fh").textContent=[h1?"Historial: "+h1:"",h2?"Personajes: "+h2:""].filter(x=>x).join(" · ");}}
["pa","pb","ca","cb"].forEach(id=>$(id).addEventListener("change",e=>{{
if(id==="pa")fav($("pa").value,$("ca"));if(id==="pb")fav($("pb").value,$("cb"));upd();}}));
upd();
}})();
</script>"""


def tabs_html(duels, current, path="/", extra=None):
    """Selector compacto de temporada (lista desplegable)."""
    items = []
    for year, sems in seasons(duels):
        for k in sems:
            items.append((k, period_label(k)))
        items.append((year, f"Temporada {year} (año completo)"))
    items.append(("todo", "Histórico (todo)"))
    opts = "".join(f'<option value="{html.escape(k)}"{" selected" if k == current else ""}>{html.escape(lbl)}</option>'
                   for k, lbl in items)
    hidden = "".join(f'<input type="hidden" name="{html.escape(k)}" value="{html.escape(v)}">'
                     for k, v in (extra or {}).items())
    return (f'<form class="picker" method="get" action="{path}">{hidden}<span class="muted">Temporada:</span>'
            f'<select name="t" onchange="this.form.submit()">{opts}</select>'
            f'<noscript><button>Ver</button></noscript></form>')


def seasons_html(duels):
    rows = []
    now_key = current_period()
    for year, sems in seasons(duels):
        for k in sems + [year]:
            a, b = period_bounds(k)
            pl, ch, _t = stats(duels, a, b)
            if not pl:
                continue
            running = time.time() < b
            champ = f'{player_link(pl[0]["name"], k)} <span class="muted">({pl[0]["points"]} pts)</span>'
            best = html.escape(ch[0]["name"]) if ch else "—"
            label = period_label(k) + (" (en curso)" if running else "")
            cls = ' style="font-weight:700"' if "-" not in k else ""
            rows.append(f'<tr><td class="n"{cls}><a href="/{q(t=k)}">{html.escape(label)}</a></td>'
                        f'<td class="n">{"Líder: " if running else "🏆 "}{champ}</td><td>{best}</td></tr>')
    if not rows:
        return '<p class="sub">Todavía no hay temporadas con duelos.</p>'
    return ('<table><tr><th>Temporada</th><th>Campeón</th><th>Mejor personaje</th></tr>'
            + "".join(rows) + "</table>")


def render_public(params):
    duels = load_duels()
    key = period_key((params.get("t") or [""])[0])
    a, b = period_bounds(key)
    _p, _c, all_tours = stats(duels)  # torneos con todos sus duelos (antes de la temporada elegida)
    ach = achievements(duels, all_tours)  # con los puntos de todo el historial
    players, chars, _tours = stats(duels, a, b)
    hp, hc = head_to_head(duels)
    period_duels = [d for d in duels if not d["annulled"] and not d["self"]
                    and (a is None or d["ts"] >= a) and (b is None or d["ts"] < b)]
    duel_html = ("".join(f'<div class="duel">{duel_line(d, key)}</div>' for d in period_duels[:20])
                 or '<p class="sub">—</p>')
    extra_html = upsets_html(period_duels, key) + achievements_html(players, ach)
    stats_html = tierlist_html(chars) + cards_html(period_duels)
    tours_html = ('<h2>Torneos</h2><p class="sub">Cada tipo de torneo tiene su apartado: tócalo para ver sus '
                  'torneos, del más reciente al primero, y toca un torneo para ver su tabla, sus grupos o sus llaves. '
                  'Los duelos de torneo también suman, el doble, a la tabla general.</p>'
                  + tournaments_list_html(all_tours))
    body = f"""<h1>🏆 Ranking · {TITLE}</h1>
<p class="sub">Cada temporada es un año con 2 semestres: los puntos empiezan de cero en cada semestre y en cada
temporada. Estás viendo: <b>{html.escape(period_label(key))}</b>.</p>
{tabs_html(duels, key)}
<h2>Jugadores</h2>
<p class="sub">Todos empiezan con {START_PLAYER} puntos. En cada duelo el ganador le quita puntos al perdedor:
gana pocos si era el favorito y muchos si no lo era. El favorito se calcula con los puntos de cada jugador y la
tier de su personaje. Los duelos de torneo valen el doble. V = victorias · D = derrotas · E = empates. Los
cuadritos son los últimos 5 duelos y 🔥 las victorias seguidas. Toca un nombre para ver su ficha.</p>
{players_table(players, key)}
{extra_html}
<h2>Personajes</h2>
<p class="sub">Cada personaje empieza con los puntos de su tier (SSS {DEFAULT_POINTS["SSS"]} … D {DEFAULT_POINTS["D"]})
y sube o baja con sus duelos. Cada deck se compara con los decks de los personajes y cuenta para el más
parecido (desde un {MIN_PCT}% de parecido).</p>{chars_table(chars)}
<h2>Los más usados</h2>
<p class="sub">Cuántas veces se ha jugado con cada personaje en esta temporada.</p>{usage_html(chars)}
<h2>Enfrentamientos entre personajes</h2>
<p class="sub">Cómo le va a cada personaje contra otro, en todos los duelos 1 contra 1 jugados (de siempre).</p>
{matchups_html(hc)}
{stats_html}
{favorites_html(players, chars, hp, hc)}
{tours_html}
{salon_html(all_tours)}
<h2>Temporadas</h2>
<p class="sub">El campeón de cada temporada y de cada semestre es quien termina con más puntos.</p>
{seasons_html(duels)}
<h2>Últimos duelos</h2>
<p class="sub">⬇ Repetición: descarga el duelo para verlo en EDOPro (se guardan {KEEP_DAYS} días).
⚠ Nerfeo: el deck usó cartas nerfeadas para ese personaje; 4RMAss decide si lo anula.</p>{duel_html}
<footer>Se cuenta por el nombre que usas en EDOPro. 4RMAss revisa y corrige los resultados. · v{VERSION}</footer>"""
    return page(body)


def chart_svg(history):
    if len(history) < 1:
        return ""
    pts = [START_PLAYER] + [p for _ts, p in history]
    lo, hi = min(pts), max(pts)
    if hi - lo < 40:
        mid = (hi + lo) / 2
        lo, hi = mid - 20, mid + 20
    w, h, pad = 600, 200, 24
    n = len(pts)
    xy = [(pad + (w - 2 * pad) * i / max(1, n - 1), h - pad - (h - 2 * pad) * (p - lo) / (hi - lo))
          for i, p in enumerate(pts)]
    line = " ".join(f"{x:.1f},{y:.1f}" for x, y in xy)
    base_y = h - pad - (h - 2 * pad) * (START_PLAYER - lo) / (hi - lo)
    dots = "".join(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="3" fill="#ffd56b"/>' for x, y in xy[1:])
    return (f'<svg class="chart" viewBox="0 0 {w} {h}" role="img" aria-label="Puntos después de cada duelo">'
            f'<line x1="{pad}" y1="{base_y:.1f}" x2="{w - pad}" y2="{base_y:.1f}" stroke="#3a4468" stroke-dasharray="4 4"/>'
            f'<text x="{pad}" y="14" fill="#8d96ad" font-size="12">{round(hi)}</text>'
            f'<text x="{pad}" y="{h - 6}" fill="#8d96ad" font-size="12">{round(lo)}</text>'
            f'<polyline points="{line}" fill="none" stroke="#9fb3ff" stroke-width="2.5"/>{dots}</svg>')


def render_player(params):
    name = (params.get("n") or [""])[0].strip()
    key = period_key((params.get("t") or [""])[0])
    a, b = period_bounds(key)
    duels = load_duels()
    _p, _c, all_tours = stats(duels)
    ach = achievements(duels, all_tours).get(name.lower(), [])
    players, _chars, _tours = stats(duels, a, b)
    hp, _hc = head_to_head(duels)
    s = next((p for p in players if p["key"] == name.lower()), None)
    back = f'<p><a href="/{q(t=key)}">← Volver al ranking</a></p>'
    tabs = tabs_html(duels, key, "/jugador", {"n": name})
    if not s:
        return page(f"""{back}<h1>{html.escape(name or "?")}</h1>{tabs}
<p class="sub">No jugó duelos en {html.escape(period_label(key))}.</p>""", name)
    mine = [d for d in duels if valid_duel(d) and (a is None or d["ts"] >= a) and (b is None or d["ts"] < b)
            and name.lower() in {n.lower() for n in d["team0"] + d["team1"]}]
    by_char = {}
    for d in mine:
        for side in (0, 1):
            for n, (c, _p) in zip(d["team" + str(side)], d["chars"][side]):
                if n.lower() != name.lower():
                    continue
                r = by_char.setdefault(c or "Sin personaje reconocido", {"w": 0, "l": 0, "d": 0})
                r["d" if d["final"] == 2 else ("w" if d["final"] == side else "l")] += 1
    crow = "".join(f'<tr><td class="n">{html.escape(c)}</td><td>{r["w"] + r["l"] + r["d"]}</td><td>{r["w"]}</td>'
                   f'<td>{r["l"]}</td><td>{r["d"]}</td><td>{round(100 * r["w"] / (r["w"] + r["l"] + r["d"]))}%</td></tr>'
                   for c, r in sorted(by_char.items(), key=lambda kv: -(kv[1]["w"] + kv[1]["l"] + kv[1]["d"])))
    rivals = []
    for (x, y), r in hp.items():
        if name.lower() in (x, y):
            other = y if x == name.lower() else x
            disp = next((p["name"] for p in players if p["key"] == other), other)
            rivals.append((disp, r[name.lower()], r[other], r["d"]))
    rivals.sort(key=lambda t: -(t[1] + t[2] + t[3]))
    rrow = "".join(f'<tr><td class="n">{player_link(n, key)}</td><td>{w}</td><td>{l}</td><td>{e}</td></tr>'
                   for n, w, l, e in rivals) or '<tr><td colspan="4" class="muted">—</td></tr>'
    dlist = "".join(f'<div class="duel">{duel_line(d, key)}</div>' for d in sorted(mine, key=lambda d: -d["ts"]))
    body = f"""{back}<h1>{html.escape(s["name"])}</h1>
<p class="sub">{html.escape(period_label(key))} · Puesto {s["pos"]} de {len(players)} · <b>{s["points"]} puntos</b> ·
{s["w"]} V, {s["l"]} D, {s["d"]} E ({s["pct"]}%) · Forma: {form_html(s)}</p>
{tabs}
<h2>Logros</h2>{('<div class="badges">' + "".join(f'<div class="badge">{x[1]} {html.escape(x[2])}<small>{html.escape(x[3])}</small></div>' for x in ach) + '</div>') if ach else '<p class="sub">Todavía ninguno.</p>'}
<h2>Puntos después de cada duelo</h2>{chart_svg(s["history"])}
<h2>Personajes que usa</h2>
<table><tr><th>Personaje</th><th>Duelos</th><th>V</th><th>D</th><th>E</th><th>%</th></tr>{crow}</table>
<h2>Contra cada rival (de siempre)</h2>
<table><tr><th>Rival</th><th>V</th><th>D</th><th>E</th></tr>{rrow}</table>
<h2>Sus duelos</h2>{dlist}
<footer>v{VERSION}</footer>"""
    return page(body, s["name"] + " · " + TITLE)


def render_admin():
    items = []
    duels = load_duels(150)
    for d in duels:
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
    signs = []
    for t in tournaments_info():
        if t["open"] and t["signups"]:
            btns = "".join(f'<form method="post" action="/admin" style="display:inline"><input type="hidden" name="f" '
                           f'value="{html.escape(t["id"] + "|" + n.lower())}"><button class="r" name="a" value="quitar">'
                           f'Quitar {html.escape(n)}</button></form>' for n in t["signups"])
            signs.append(f'<div class="duel"><b>{html.escape(t["name"])}</b> · inscritos: {btns}</div>')
    signs_html = ("<h2>Inscripciones a torneos</h2>" + "".join(signs)) if signs else ""
    body = f"""<h1>Administrar resultados</h1>
<p><a href="/admin/respaldo">⬇ Descargar copia de seguridad de los resultados</a>
<span class="muted">(guárdala en tu PC o en Drive; si algún día se pierde el servidor, con ella se recupera todo)</span></p>
{signs_html}
<p class="sub">Los cambios se aplican al momento en el <a href="/">ranking</a>. Los duelos con
<span class="warn">⚠ Nerfeo</span> usaron cartas nerfeadas para su personaje: puedes anularlos.</p>
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

    def send_replay(self, fn):
        if not replay_exists(fn):
            return self.send_html(page("<p>Esa repetición ya no está guardada.</p>"), 404)
        data = open(os.path.join(REPLAYS, fn), "rb").read()
        self.send_response(200)
        self.send_header("Content-Type", "application/octet-stream")
        self.send_header("Content-Disposition", f'attachment; filename="AnimeServer4RMAss-{fn}"')
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def send_portrait(self, name):
        data = PORTRAITS.data.get(urllib.parse.unquote(name))
        if data is None:
            return self.send_html(page("<p>No existe esta imagen.</p>"), 404)
        self.send_response(200)
        self.send_header("Content-Type", "image/jpeg")
        self.send_header("Cache-Control", "public, max-age=604800")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        CHAR.load()
        NERF.load()
        PORTRAITS.load()
        url = urllib.parse.urlparse(self.path)
        params = urllib.parse.parse_qs(url.query)
        path = url.path
        if path == "/":
            self.send_html(render_public(params))
        elif path == "/jugador":
            self.send_html(render_player(params))
        elif path == "/torneo":
            self.send_html(render_tournament(params))
        elif path.startswith("/replay/"):
            self.send_replay(path[len("/replay/"):])
        elif path.startswith("/img/") and path.endswith(".jpg"):
            self.send_portrait(path[len("/img/"):-len(".jpg")])
        elif path == "/admin":
            if not self.authorized():
                return self.ask_auth()
            self.send_html(render_admin())
        elif path == "/admin/respaldo":
            if not self.authorized():
                return self.ask_auth()
            self.send_backup()
        else:
            self.send_html(page("<p>No existe esta página.</p>"), 404)

    def send_backup(self):
        tmp = DB + ".respaldo"
        with db_lock:
            src, dst = sqlite3.connect(DB), sqlite3.connect(tmp)
            src.backup(dst)
            dst.close()
            src.close()
        data = open(tmp, "rb").read()
        os.remove(tmp)
        stamp = datetime.now(TZ).strftime("%Y%m%d-%H%M")
        self.send_response(200)
        self.send_header("Content-Type", "application/octet-stream")
        self.send_header("Content-Disposition", f'attachment; filename="ranking-respaldo-{stamp}.db"')
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def redirect(self, where):
        self.send_response(303)
        self.send_header("Location", where)
        self.send_header("Content-Length", "0")
        self.end_headers()

    def do_signup(self):
        length = int(self.headers.get("Content-Length", "0") or 0)
        form = urllib.parse.parse_qs(self.rfile.read(min(length, 4000)).decode("utf-8"))
        tid = (form.get("id") or [""])[0]
        name = re.sub(r"\s+", " ", (form.get("nombre") or [""])[0]).strip()[:30]
        t = next((x for x in tournaments_info() if x["id"] == tid), None)
        if not t or not t["open"] or time.time() >= t["start"] or not name:
            return self.redirect(f"/torneo{q(id=tid)}")
        name = canon(name, alias_map())
        with db_lock, db() as con:
            n = con.execute("select count(*) from signups where tid=?", (tid,)).fetchone()[0]
            if n < 64:
                con.execute("insert or ignore into signups values (?,?,?,?)", (tid, name.lower(), name, int(time.time())))
        self.redirect(f"/torneo{q(id=tid, ok=1)}")

    def do_POST(self):
        if urllib.parse.urlparse(self.path).path == "/inscribir":
            return self.do_signup()
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
        if a == "quitar" and "|" in f:
            tid, key = f.split("|", 1)
            with db_lock, db() as con:
                con.execute("delete from signups where tid=? and key=?", (tid, key))
        elif sql and f:
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
        NERF.load()
        duels = load_duels()
        stats(duels)  # comprueba que todo funciona antes de abrir la página
        render_public({})
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
