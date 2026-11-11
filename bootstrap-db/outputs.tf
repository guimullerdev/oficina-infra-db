output "database_urls" {
  description = "DATABASE_URL por serviço (chaves os e billing), cada uma com a role dona do próprio database (ADR 0008)"
  value = {
    for svc in var.services :
    svc => "postgresql://${postgresql_role.app_user[svc].name}:${random_password.app_user[svc].result}@${data.terraform_remote_state.root.outputs.db_address}:${data.terraform_remote_state.root.outputs.db_port}/${postgresql_database.this[svc].name}?sslmode=require"
  }
  sensitive = true
}
