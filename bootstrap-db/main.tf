# Um database lógico + uma role de app por serviço (os, billing), na mesma
# instância RDS — ADR 0008 (um RDS, dois bancos lógicos, zero grants
# cruzados). O usuário master (módulo raiz) nunca é usado pelos serviços, só
# para provisionar isto aqui. O isolamento (grants) fica em grants.tf.
resource "random_password" "app_user" {
  for_each = toset(var.services)

  length  = 24
  special = false
}

resource "postgresql_role" "app_user" {
  for_each = toset(var.services)

  name     = "${var.db_name}_${each.key}_app"
  login    = true
  password = random_password.app_user[each.key].result
}

resource "postgresql_database" "this" {
  for_each = toset(var.services)

  name  = "${var.db_name}_${each.key}"
  owner = postgresql_role.app_user[each.key].name

  # O master já tem de ser membro da role dona quando o CREATE DATABASE roda:
  # assim o provider pula o GRANT/REVOKE temporário dessa role, que apagaria a
  # mesma linha de pg_auth_members criada por master_member_of_app.
  depends_on = [postgresql_grant_role.master_member_of_app]
}
