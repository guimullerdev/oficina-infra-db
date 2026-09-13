# Um database lógico + um usuário de app por ambiente (homolog/prod), na
# mesma instância RDS — decisão Fase 0. O usuário master (módulo raiz) nunca
# é usado pela app, só para provisionar isso aqui.
resource "random_password" "app_user" {
  for_each = toset(var.environments)

  length  = 24
  special = false
}

resource "postgresql_role" "app_user" {
  for_each = toset(var.environments)

  name     = "${var.db_name}_${each.key}_app"
  login    = true
  password = random_password.app_user[each.key].result
}

resource "postgresql_database" "this" {
  for_each = toset(var.environments)

  name  = "${var.db_name}_${each.key}"
  owner = postgresql_role.app_user[each.key].name
}
