output "db_endpoint" {
  description = "Endpoint do RDS (host:port) — não é segredo, mas só é alcançável de dentro da VPC"
  value       = aws_db_instance.this.endpoint
}

output "db_security_group_id" {
  description = "SG do RDS — infra-k8s/auth-lambda podem referenciar via remote state se precisarem liberar acesso mais restrito que o CIDR da VPC"
  value       = aws_security_group.rds.id
}

output "vpc_id" {
  description = "VPC default usada pelo RDS — EKS (repo 3) e Lambda (repo 2) devem rodar na mesma VPC"
  value       = data.aws_vpc.default.id
}

output "database_urls" {
  description = "DATABASE_URL por ambiente (homolog/prod), consumida por oficina-infra-k8s (Secret) e pela app — ver ADR 0001"
  value = {
    for env in var.environments :
    env => "postgresql://${postgresql_role.app_user[env].name}:${random_password.app_user[env].result}@${aws_db_instance.this.address}:${aws_db_instance.this.port}/${postgresql_database.this[env].name}?sslmode=require"
  }
  sensitive = true
}
