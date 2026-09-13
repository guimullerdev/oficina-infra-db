output "db_endpoint" {
  description = "Endpoint do RDS (host:port) — não é segredo, mas só é alcançável de dentro da VPC"
  value       = aws_db_instance.this.endpoint
}

output "db_address" {
  description = "Host do RDS, sem a porta (usado pelo bootstrap-db para montar a connection string)"
  value       = aws_db_instance.this.address
}

output "db_port" {
  value = aws_db_instance.this.port
}

output "db_master_username" {
  value = aws_db_instance.this.username
}

output "db_master_password" {
  description = "Senha do usuário master — consumida só pelo bootstrap-db (via remote state) para criar os databases/usuários de app; nunca usada pela aplicação"
  value       = random_password.master.result
  sensitive   = true
}

output "db_security_group_id" {
  description = "SG do RDS — infra-k8s/auth-lambda podem referenciar via remote state se precisarem liberar acesso mais restrito que o CIDR da VPC"
  value       = aws_security_group.rds.id
}

output "vpc_id" {
  description = "VPC default usada pelo RDS — EKS (repo 3) e Lambda (repo 2) devem rodar na mesma VPC"
  value       = data.aws_vpc.default.id
}
