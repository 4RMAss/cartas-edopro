#!/usr/bin/env bash
# =====================================================================
#  Anime Server by 4RMAss — servidor EDOPro (Multirole) con cartas propias
#  Para Ubuntu en Oracle Cloud (forma VM.Standard.E2.1.Micro, x86_64)
#
#  Uso (en la consola del servidor):
#    curl -fsSL https://raw.githubusercontent.com/USUARIO/REPO/main/instalar.sh \
#      | sudo bash -s -- https://github.com/USUARIO/REPO
#
#  Se puede volver a ejecutar sin problema: rehace la configuración
#  y reinicia el servidor.
# =====================================================================
set -euo pipefail

REPO_CARTAS="${1:-}"
DIR=/opt/multirole
IMAGEN=dyxel/multirole:latest
PUERTO_DUELO=7911
PUERTO_LISTA=7922
PUERTO_WEBHOOK_CARTAS=45454

msg()   { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
error() { printf '\n\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || error "Ejecútalo con sudo."
[ -n "$REPO_CARTAS" ] || error "Falta la dirección del repositorio de cartas. Ejemplo: sudo bash instalar.sh https://github.com/USUARIO/REPO"
case "$REPO_CARTAS" in
  https://github.com/*/*) ;;
  *) error "La dirección del repositorio debe ser del tipo https://github.com/USUARIO/REPO" ;;
esac
REPO_CARTAS="${REPO_CARTAS%/}"
REPO_CARTAS="${REPO_CARTAS%.git}"

ARQ="$(uname -m)"
[ "$ARQ" = "x86_64" ] || error "Esta máquina es $ARQ. La imagen de Multirole sólo existe para x86_64: crea la instancia con la forma VM.Standard.E2.1.Micro (AMD), no con Ampere (ARM)."

# ---------------------------------------------------------------------
msg "1/6 Memoria de intercambio (la máquina gratuita sólo tiene 1 GB de RAM)"
if ! swapon --show | grep -q .; then
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile >/dev/null
  swapon /swapfile
  grep -q '^/swapfile ' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
  echo "Creados 2 GB de intercambio."
else
  echo "Ya había intercambio; no se toca."
fi

# ---------------------------------------------------------------------
msg "2/6 Instalando Docker"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq docker.io curl openssl cron >/dev/null
systemctl enable --now docker >/dev/null 2>&1 || true
systemctl enable --now cron   >/dev/null 2>&1 || true

# ---------------------------------------------------------------------
msg "3/6 Ajustes de red recomendados por Multirole"
cat > /etc/sysctl.d/99-multirole.conf <<'EOF'
# Detectar antes las conexiones muertas (recomendación del README de Multirole)
net.ipv4.tcp_keepalive_time = 60
net.ipv4.tcp_keepalive_intvl = 10
net.ipv4.tcp_keepalive_probes = 6
EOF
sysctl --system >/dev/null

# Las imágenes de Ubuntu de Oracle traen un cortafuegos que rechaza todo
# menos SSH. Abrimos los dos puertos del juego.
for p in "$PUERTO_DUELO" "$PUERTO_LISTA"; do
  iptables -C INPUT -p tcp --dport "$p" -j ACCEPT 2>/dev/null \
    || iptables -I INPUT 1 -p tcp --dport "$p" -j ACCEPT
done
if command -v netfilter-persistent >/dev/null 2>&1; then
  netfilter-persistent save >/dev/null 2>&1 || true
elif [ -d /etc/iptables ]; then
  iptables-save > /etc/iptables/rules.v4
fi

# ---------------------------------------------------------------------
msg "4/6 Configuración de Multirole"
mkdir -p "$DIR"
tok() { openssl rand -hex 16; }
T_SCRIPTS=$(tok); T_DBS=$(tok); T_LFL=$(tok); T_BIN=$(tok); T_CARTAS=$(tok)

cat > "$DIR/config.json" <<EOF
{
  "concurrencyHint": -1,
  "lobbyListingPort": $PUERTO_LISTA,
  "lobbyMaxConnections": 16,
  "roomHostingPort": $PUERTO_DUELO,
  "repos": [
    { "name": "scripts",   "remote": "https://github.com/ProjectIgnis/CardScripts", "path": "./sync/scripts/",   "webhookPort": 34343, "webhookToken": "$T_SCRIPTS" },
    { "name": "databases", "remote": "https://github.com/ProjectIgnis/BabelCDB",    "path": "./sync/databases/", "webhookPort": 62672, "webhookToken": "$T_DBS" },
    { "name": "banlists",  "remote": "https://github.com/ProjectIgnis/LFLists",     "path": "./sync/banlists/",  "webhookPort": 49382, "webhookToken": "$T_LFL" },
    { "name": "bin",       "remote": "https://github.com/ProjectIgnis/bin",         "path": "./sync/bin/",       "webhookPort": 43632, "webhookToken": "$T_BIN" },
    { "name": "cartas",    "remote": "$REPO_CARTAS",                                "path": "./sync/cartas/",    "webhookPort": $PUERTO_WEBHOOK_CARTAS, "webhookToken": "$T_CARTAS" }
  ],
  "banlistProvider": { "observedRepos": ["banlists", "cartas"], "fileRegex": ".*\\\\.lflist\\\\.conf" },
  "coreProvider": {
    "observedRepos": ["bin"],
    "fileRegex": ".*libocgcore\\\\.so",
    "tmpPath": "./tmp/",
    "coreType": "hornet",
    "loadPerRoom": true
  },
  "dataProvider":   { "observedRepos": ["databases", "cartas"], "fileRegex": ".*\\\\.cdb" },
  "scriptProvider": { "observedRepos": ["scripts", "cartas"],   "fileRegex": ".*\\\\.lua" },
  "logHandler": {
    "serviceSinks": {
      "gitRepo":         { "type": "stdout", "properties": {} },
      "multirole":       { "type": "stdout", "properties": {} },
      "banlistProvider": { "type": "stdout", "properties": {} },
      "coreProvider":    { "type": "stdout", "properties": {} },
      "dataProvider":    { "type": "stdout", "properties": {} },
      "logHandler":      { "type": "stdout", "properties": {} },
      "replayManager":   { "type": "stdout", "properties": {} },
      "scriptProvider":  { "type": "stdout", "properties": {} },
      "other":           { "type": "stdout", "properties": {} }
    },
    "ecSinks": {
      "core":     { "type": "stderr", "properties": {} },
      "official": { "type": "stderr", "properties": {} },
      "speed":    { "type": "stderr", "properties": {} },
      "rush":     { "type": "stderr", "properties": {} },
      "other":    { "type": "stderr", "properties": {} }
    },
    "roomLogging": { "enabled": false, "path": "./room-logs/" }
  },
  "replayManager": { "save": false, "path": "./replays/" }
}
EOF
chmod 600 "$DIR/config.json"

# Comando para recargar las cartas al momento (tras subir cambios a GitHub)
cat > /usr/local/bin/actualizar-cartas <<EOF
#!/bin/sh
curl -fsS -X POST "http://127.0.0.1:$PUERTO_WEBHOOK_CARTAS/$T_CARTAS" >/dev/null && echo "Cartas recargadas desde GitHub."
EOF
chmod 755 /usr/local/bin/actualizar-cartas

# Actualización automática: tus cartas cada 15 min, lo oficial cada día
cat > /etc/cron.d/multirole <<EOF
*/15 * * * * root curl -fsS -X POST http://127.0.0.1:$PUERTO_WEBHOOK_CARTAS/$T_CARTAS >/dev/null 2>&1
30 9 * * *   root for x in 34343/$T_SCRIPTS 62672/$T_DBS 49382/$T_LFL 43632/$T_BIN; do curl -fsS -X POST http://127.0.0.1:\$x >/dev/null 2>&1; sleep 60; done
EOF
chmod 644 /etc/cron.d/multirole

# ---------------------------------------------------------------------
msg "5/6 Descargando y arrancando Multirole (la primera vez tarda varios minutos)"
docker pull -q "$IMAGEN" >/dev/null
docker rm -f multirole >/dev/null 2>&1 || true
docker run -d --name multirole \
  --restart unless-stopped \
  --network host \
  --ulimit nofile=65536:65536 \
  -v "$DIR/config.json:/multirole/config.json:ro" \
  "$IMAGEN" >/dev/null

# ---------------------------------------------------------------------
msg "6/6 Comprobando"
IP_PUBLICA="$(curl -fsS --max-time 10 https://api.ipify.org || echo 'TU_IP_PUBLICA')"
printf 'Esperando a que descargue las cartas y abra los puertos'
for _ in $(seq 1 90); do
  if (ss -ltn 2>/dev/null | grep -q ":$PUERTO_LISTA ") && (ss -ltn 2>/dev/null | grep -q ":$PUERTO_DUELO "); then
    LISTO=1; break
  fi
  printf '.'; sleep 10
done
echo

if [ "${LISTO:-0}" = 1 ]; then
  msg "¡Anime Server by 4RMAss en marcha!"
else
  msg "Multirole sigue arrancando. Mira el registro con:  sudo docker logs --tail 50 multirole"
fi

cat <<EOF

  IP del servidor:       $IP_PUBLICA
  Puerto de duelo:       $PUERTO_DUELO
  Puerto de salas:       $PUERTO_LISTA
  Repo de cartas:        $REPO_CARTAS

  Recuerda abrir los puertos $PUERTO_DUELO y $PUERTO_LISTA (TCP) también en la
  "Security List" de la red de Oracle, o nadie podrá entrar.

  Comandos útiles:
    sudo actualizar-cartas               recargar tus cartas ya mismo
    sudo docker logs --tail 50 multirole ver el registro
    sudo docker restart multirole        reiniciar el servidor

  Pega esto en config/user_configs.json de cada EDOPro:
{
  "repos": [
    {
      "url": "$REPO_CARTAS",
      "repo_name": "Anime Server by 4RMAss - Cartas",
      "repo_path": "./repositories/anime-server-4rmass",
      "data_path": "expansions",
      "script_path": "script",
      "should_update": true,
      "should_read": true
    }
  ],
  "servers": [
    {
      "name": "Anime Server by 4RMAss",
      "address": "$IP_PUBLICA",
      "duelport": $PUERTO_DUELO,
      "roomaddress": "$IP_PUBLICA",
      "roomlistprotocol": "http",
      "roomlistport": $PUERTO_LISTA
    }
  ]
}
EOF
