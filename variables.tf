variable "aws_region" {
  description = "Região AWS onde o RDS é provisionado"
  type        = string
  default     = "us-east-1"
}

variable "db_name" {
  description = "Nome base do banco (prefixo dos databases lógicos oficina_homolog/oficina_prod)"
  type        = string
  default     = "oficina"
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
  description = "Dias de retenção de backup automático"
  type        = number
  default     = 7
}

variable "environments" {
  description = "Databases lógicos + usuário de app por ambiente, na mesma instância RDS (decisão Fase 0: 1 conta, 1 RDS, 2 databases lógicos)"
  type        = list(string)
  default     = ["homolog", "prod"]
}
