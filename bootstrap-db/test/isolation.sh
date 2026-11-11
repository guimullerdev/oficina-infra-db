#!/usr/bin/env bash
# Prova LOCAL (sem AWS) de que o bootstrap-db/ isola os databases dos serviços.
#
# O que prova, contra um Postgres 16 descartável em Docker:
#   - cada role de app (oficina_os_app, oficina_billing_app) NÃO conecta no
#     database do outro serviço (permission denied for database);
#   - cada role conecta no próprio banco e cria tabela normal e temporária;
#   - o master (não-superuser, como no RDS) conecta nos dois bancos;
#   - PUBLIC não tem CONNECT em nenhum dos dois bancos;
#   - o apply é idempotente (plan -detailed-exitcode sai 0).
#
# Requisitos: Docker (imagem postgres:16-alpine já em cache; não faz pull),
# terraform (providers em cache) e jq.
# Variável opcional: PG_PORT (default 55432).
#
# RESSALVA: é um indício, não a prova final. O RDS 16.4 tem o papel
# rds_superuser e o master dele difere de um role CREATEROLE/CREATEDB comum;
# a prova real fica na janela de apply (Fase 4 do plano de infra).
set -euo pipefail

IMAGEM="postgres:16-alpine"
PG_PORT="${PG_PORT:-55432}"
ESPERA_MAX=60 # segundos para o Postgres ficar pronto
CONTAINER="oficina-isolation-test-$$"
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="$(mktemp -d)"
FALHAS=0

# Sempre derruba o container e apaga o diretório temporário, mesmo em falha.
limpar() {
  docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
  rm -rf "$TMP"
}
trap limpar EXIT

for bin in docker terraform jq; do
  command -v "$bin" >/dev/null || { echo "ERRO: '$bin' não encontrado" >&2; exit 2; }
done

docker image inspect "$IMAGEM" >/dev/null 2>&1 \
  || { echo "ERRO: imagem $IMAGEM ausente localmente (sem pull)" >&2; exit 2; }

# Porta ocupada?
if docker ps --format '{{.Ports}}' | grep -q ":${PG_PORT}->" \
  || (command -v nc >/dev/null && nc -z localhost "$PG_PORT" >/dev/null 2>&1); then
  echo "ERRO: porta $PG_PORT já está em uso; defina PG_PORT com outra porta" >&2
  exit 2
fi

# 1. Sobe o Postgres.
docker run -d --name "$CONTAINER" -e POSTGRES_PASSWORD=superuser-descartavel \
  -p "${PG_PORT}:5432" "$IMAGEM" >/dev/null

fim=$((SECONDS + ESPERA_MAX))
until docker exec "$CONTAINER" pg_isready -U postgres -h 127.0.0.1 >/dev/null 2>&1; do
  if ((SECONDS >= fim)); then
    echo "ERRO: Postgres não ficou pronto em ${ESPERA_MAX}s" >&2
    exit 2
  fi
  sleep 1
done
# A imagem reinicia o servidor uma vez após o init; confirma estabilidade.
sleep 2
until docker exec "$CONTAINER" pg_isready -U postgres -h 127.0.0.1 >/dev/null 2>&1; do
  if ((SECONDS >= fim)); then echo "ERRO: timeout aguardando Postgres" >&2; exit 2; fi
  sleep 1
done

# 2. Master sem superuser, imitando o RDS.
docker exec "$CONTAINER" psql -U postgres -h 127.0.0.1 -v ON_ERROR_STOP=1 -q \
  -c "CREATE ROLE oficina_admin LOGIN CREATEROLE CREATEDB PASSWORD 'a'" >/dev/null

# 3. Cópia do módulo com backend e remote state locais.
mkdir "$TMP/mod"
(cd "$RAIZ/bootstrap-db" && tar --exclude=.terraform --exclude=test \
  --exclude='*.tfstate*' -cf - .) | tar -xf - -C "$TMP/mod"
cat >"$TMP/mod/backend_override.tf" <<'TF'
terraform {
  backend "local" {}
}
TF
cat >"$TMP/mod/remote_state_override.tf" <<'TF'
data "terraform_remote_state" "root" {
  backend = "local"
  config = {
    path = "${path.module}/root.tfstate"
  }
}
TF

# 4. root.tfstate fake.
cat >"$TMP/mod/root.tfstate" <<JSON
{"version":4,"terraform_version":"1.9.0","serial":1,"lineage":"local","outputs":{"db_address":{"value":"localhost","type":"string"},"db_port":{"value":${PG_PORT},"type":"number"},"db_master_username":{"value":"oficina_admin","type":"string"},"db_master_password":{"value":"a","type":"string","sensitive":true}},"resources":[]}
JSON

# 5. init, apply e plan (idempotência), sempre só na cópia.
export TF_IN_AUTOMATION=1
cd "$TMP/mod"
terraform init -input=false >"$TMP/init.log" 2>&1 \
  || { cat "$TMP/init.log"; echo "ERRO: terraform init falhou" >&2; exit 1; }
terraform apply -auto-approve -input=false -var "db_host_override=localhost:${PG_PORT}" \
  >"$TMP/apply.log" 2>&1 \
  || { tail -n 30 "$TMP/apply.log"; echo "ERRO: terraform apply falhou" >&2; exit 1; }

ok() { echo "OK $1"; }
falhou() { echo "FALHOU $1"; FALHAS=$((FALHAS + 1)); }

set +e
terraform plan -detailed-exitcode -input=false -var "db_host_override=localhost:${PG_PORT}" \
  >"$TMP/plan.log" 2>&1
rc=$?
set -e
if [ "$rc" -eq 0 ]; then
  ok "plan após apply sem mudanças (idempotente)"
else
  falhou "plan após apply sem mudanças (código $rc)"
  grep -E '^\s*[#~+-]|Plan:' "$TMP/plan.log" | head -n 20 || true
fi

# 6. Senhas das roles de app (sem imprimir).
URLS="$(terraform output -json database_urls)"
senha() { # $1 = serviço
  jq -r --arg s "$1" '.[$s]' <<<"$URLS" | sed -E 's#^postgresql://[^:]+:([^@]+)@.*#\1#'
}
PW_OS="$(senha os)"
PW_BILLING="$(senha billing)"

# Conecta pelo IP do próprio container: 127.0.0.1 é "trust" na imagem e
# ignoraria a senha; por eth0 vale scram.
IP="$(docker exec "$CONTAINER" hostname -i | awk '{print $1}')"

# psql_como USUARIO SENHA BANCO SQL -> saída combinada; retorna o código do psql
psql_como() {
  docker exec -e PGPASSWORD="$2" "$CONTAINER" \
    psql -h "$IP" -U "$1" -d "$3" -v ON_ERROR_STOP=1 -tA -c "$4" 2>&1
}

nega() { # descrição, usuário, senha, banco
  local saida
  if saida="$(psql_como "$2" "$3" "$4" 'SELECT 1')"; then
    falhou "$1 (conectou, deveria negar)"
  elif grep -q 'permission denied for database' <<<"$saida"; then
    ok "$1"
  else
    falhou "$1 (erro inesperado: $(head -n 1 <<<"$saida"))"
  fi
}

nega "oficina_os_app NÃO conecta em oficina_billing" oficina_os_app "$PW_OS" oficina_billing
nega "oficina_billing_app NÃO conecta em oficina_os" oficina_billing_app "$PW_BILLING" oficina_os

proprio() { # usuário, senha, banco
  if psql_como "$1" "$2" "$3" 'CREATE TABLE t_iso(id int); CREATE TEMP TABLE t_iso_tmp(id int); DROP TABLE t_iso;' >/dev/null; then
    ok "$1 conecta em $3 e cria tabela e tabela temporária"
  else
    falhou "$1 conecta em $3 e cria tabela e tabela temporária"
  fi
}
proprio oficina_os_app "$PW_OS" oficina_os
proprio oficina_billing_app "$PW_BILLING" oficina_billing

for db in oficina_os oficina_billing; do
  if psql_como oficina_admin a "$db" 'SELECT 1' >/dev/null; then
    ok "oficina_admin conecta em $db"
  else
    falhou "oficina_admin conecta em $db"
  fi
done

for db in oficina_os oficina_billing; do
  r="$(psql_como oficina_admin a "$db" "SELECT has_database_privilege('public','$db','CONNECT')" || true)"
  if [ "$r" = "f" ]; then
    ok "PUBLIC sem CONNECT em $db"
  else
    falhou "PUBLIC sem CONNECT em $db (retorno: $r)"
  fi
done

if [ "$FALHAS" -gt 0 ]; then
  echo "RESULTADO: $FALHAS checagem(ns) falharam" >&2
  exit 1
fi
echo "RESULTADO: todas as checagens passaram"
