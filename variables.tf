variable "aws_region" {
  description = "Região AWS onde o RDS é provisionado"
  type        = string
  default     = "us-east-1"
}

variable "db_master_username" {
  description = "Usuário master da instância RDS (não é o usuário usado pela app)"
  type        = string
  default     = "oficina_admin"
}

variable "db_instance_class" {
  description = "Classe da instância RDS — db.t4g.micro cobre o free tier (12 meses, conta nova)"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "Armazenamento inicial em GB (gp3)"
  type        = number
  default     = 20
}

variable "db_engine_version" {
  description = "Versão do PostgreSQL — mesma major usada pelo Prisma/Postgres em pod da Fase 2"
  type        = string
  default     = "16.4"
}

variable "db_backup_retention_period" {
  description = <<-EOT
    Dias de retenção de backup automático.

    1, e não 7, porque contas no plano Free Tier da AWS rejeitam retenções
    maiores (`FreeTierRestrictionError`). 1 mantém o backup diário ativo —
    requisito do PDF — enquanto 0 o desligaria por completo. Numa conta
    paga, subir para 7 é seguro.
  EOT
  type        = number
  default     = 1
}
