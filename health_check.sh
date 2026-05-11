set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────
COMPOSE_FILE="${COMPOSE_FILE:-./compose/docker-compose.yml}"
MAX_WAIT="${MAX_WAIT:-120}"   # Timeout global en secondes
POLL_INTERVAL="${POLL_INTERVAL:-5}"  # Intervalle entre chaque vérification

# Services à surveiller (ceux qui ont un healthcheck ET qui importent)
WATCHED_SERVICES=("db" "mongo" "server")

# Couleurs pour les logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ─── Fonctions utilitaires ────────────────────────────────────────────────────
log()    { echo -e "${CYAN}[$(date '+%H:%M:%S')]${NC} $*"; }
ok()     { echo -e "${GREEN}[$(date '+%H:%M:%S')] ✓${NC} $*"; }
warn()   { echo -e "${YELLOW}[$(date '+%H:%M:%S')] ⚠${NC} $*"; }
error()  { echo -e "${RED}[$(date '+%H:%M:%S')] ✗${NC} $*" >&2; }

# ─── Récupère le statut health d'un service via docker compose ps ─────────────
# Retourne : "healthy" | "unhealthy" | "starting" | "none" | "exited"
get_service_health() {
  local service="$1"

  local status
  status=$(docker compose -f "$COMPOSE_FILE" ps --format json "$service" 2>/dev/null \
    | python3 -c "
import sys, json
data = sys.stdin.read().strip()
if not data:
    print('none')
    sys.exit(0)
# docker compose ps --format json retourne une ligne JSON par conteneur
for line in data.splitlines():
    try:
        obj = json.loads(line)
        health = obj.get('Health', '')
        state  = obj.get('State', '')
        if state in ('exited', 'dead'):
            print('exited')
        elif health == 'healthy':
            print('healthy')
        elif health == 'unhealthy':
            print('unhealthy')
        elif health in ('starting', ''):
            print('starting')
        else:
            print('none')
    except Exception:
        print('none')
" 2>/dev/null || echo "none")

  echo "${status:-none}"
}

# ─── Vérifie manuellement que l'API Python répond ─────────────────────────────
# Réplique le healthcheck du compose : GET /posts ET /users doivent répondre 2xx
check_server_endpoint() {
  local container
  container=$(docker compose -f "$COMPOSE_FILE" ps -q server 2>/dev/null | head -1)
  [[ -z "$container" ]] && return 1

  docker exec "$container" \
    sh -c 'curl -sf http://localhost:8000/posts && curl -sf http://localhost:8000/users' \
    > /dev/null 2>&1
}

# ─── Vérifie manuellement que MongoDB contient bien 5 posts ──────────────────
# Réplique le healthcheck du compose
check_mongo_data() {
  local container
  container=$(docker compose -f "$COMPOSE_FILE" ps -q mongo 2>/dev/null | head -1)
  [[ -z "$container" ]] && return 1

  docker exec "$container" \
    mongosh \
      --username "${MONGO_ROOT_USER:-root}" \
      --password "${MONGO_ROOT_PASSWORD:-root}" \
      --eval "const count = db.getSiblingDB('${MONGO_DATABASE:-blog_db}').posts.countDocuments(); if (count !== 5) { quit(1); }" \
    > /dev/null 2>&1
}

main() {
  log "Démarrage de la surveillance des services : ${WATCHED_SERVICES[*]}"
  log "Fichier Compose : $COMPOSE_FILE"
  log "Timeout : ${MAX_WAIT}s | Intervalle : ${POLL_INTERVAL}s"
  echo ""

  local elapsed=0
  local all_healthy

  while true; do
    all_healthy=true

    for service in "${WATCHED_SERVICES[@]}"; do
      local health
      health=$(get_service_health "$service")

      case "$health" in
        healthy)
          ok "[$service] healthy"
          ;;
        unhealthy)
          warn "[$service] unhealthy — vérification manuelle…"
          # Fallback : on re-teste manuellement selon le service
          if [[ "$service" == "mongo" ]]; then
            if check_mongo_data; then
              ok "[$service] données MongoDB OK (fallback)"
            else
              error "[$service] données MongoDB KO"
              all_healthy=false
            fi
          elif [[ "$service" == "server" ]]; then
            if check_server_endpoint; then
              ok "[$service] endpoints API OK (fallback)"
            else
              error "[$service] endpoints API KO"
              all_healthy=false
            fi
          else
            all_healthy=false
          fi
          ;;
        exited)
          error "[$service] conteneur arrêté (exited) — abandon"
          docker compose -f "$COMPOSE_FILE" logs --tail=20 "$service" >&2
          exit 1
          ;;
        starting|none|*)
          log "[$service] en cours de démarrage… (${elapsed}s écoulées)"
          all_healthy=false
          ;;
      esac
    done

    if $all_healthy; then
      echo ""
      ok "Tous les services sont opérationnels après ${elapsed}s."
      exit 0
    fi

    # Timeout ?
    if (( elapsed >= MAX_WAIT )); then
      echo ""
      error "Timeout atteint (${MAX_WAIT}s). Services toujours non disponibles."
      echo ""
      log "État final :"
      docker compose -f "$COMPOSE_FILE" ps >&2
      echo ""
      log "Logs des services surveillés :"
      for service in "${WATCHED_SERVICES[@]}"; do
        error "=== Logs : $service ==="
        docker compose -f "$COMPOSE_FILE" logs --tail=30 "$service" >&2
      done
      exit 1
    fi

    echo ""
    log "Nouvelle vérification dans ${POLL_INTERVAL}s… (${elapsed}/${MAX_WAIT}s)"
    sleep "$POLL_INTERVAL"
    elapsed=$(( elapsed + POLL_INTERVAL ))
  done
}

main "$@"
