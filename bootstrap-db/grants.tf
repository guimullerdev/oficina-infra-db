# Isolamento entre serviços (ADR 0008): PUBLIC não conecta em nenhum database;
# só a role dona conecta (e o master, que a herda). Zero grants cruzados.
#
# O master não é superuser no RDS: para os REVOKE abaixo valerem ele precisa
# agir como dono, isto é, herdar a role dona. No PG16 o CREATE ROLE feito por
# ele só lhe dá ADMIN OPTION (sem INHERIT/SET); sem este grant os REVOKE viram
# WARNING "no privileges could be revoked" e nada muda. Não é grant cruzado:
# o master já podia conceder a si mesmo essa role.
resource "postgresql_grant_role" "master_member_of_app" {
  for_each = toset(var.services)

  role       = data.terraform_remote_state.root.outputs.db_master_username
  grant_role = postgresql_role.app_user[each.key].name

  lifecycle {
    # pg_auth_members fica com 2 linhas master->role (a implícita do CREATE
    # ROLE, admin_option = true, e esta); o read do provider pega a primeira.
    # Sem isto, with_admin_option (ForceNew) recriaria o recurso a cada plan.
    ignore_changes = [with_admin_option]
  }
}

# Grants no mesmo database em paralelo podem dar "tuple concurrently updated":
# ordem fixa via depends_on.
resource "postgresql_grant" "database_revoke_public" {
  for_each = toset(var.services)

  database    = postgresql_database.this[each.key].name
  role        = "public" # minúsculo: é o que o provider trata como PUBLIC
  object_type = "database"
  privileges  = []
}

resource "postgresql_grant" "database_owner" {
  for_each = toset(var.services)

  database    = postgresql_database.this[each.key].name
  role        = postgresql_role.app_user[each.key].name
  object_type = "database"
  # O provider faz REVOKE ALL antes do GRANT: declarar menos que isto tiraria
  # privilégios que o dono tem por padrão.
  privileges = ["CONNECT", "CREATE", "TEMPORARY"]

  depends_on = [postgresql_grant.database_revoke_public]
}

resource "postgresql_grant" "schema_public_revoke_public" {
  for_each = toset(var.services)

  database    = postgresql_database.this[each.key].name
  role        = "public"
  schema      = "public"
  object_type = "schema"
  privileges  = []

  depends_on = [postgresql_grant.database_owner]
}
