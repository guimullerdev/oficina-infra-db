output "database_urls" {
  description = "DATABASE_URL por ambiente (homolog/prod), consumida por oficina-infra-k8s (Secret) e pela app — ver ADR 0001"
  value = {
    for env in var.environments :
    env => "postgresql://${postgresql_role.app_user[env].name}:${random_password.app_user[env].result}@${data.terraform_remote_state.root.outputs.db_address}:${data.terraform_remote_state.root.outputs.db_port}/${postgresql_database.this[env].name}?sslmode=require"
  }
  sensitive = true
}
