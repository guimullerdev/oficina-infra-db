resource "random_password" "master" {
  length  = 24
  special = false # evita caracteres que quebram connection string sem URL-encode
}

resource "aws_db_instance" "this" {
  identifier     = "oficina-db"
  engine         = "postgres"
  engine_version = var.db_engine_version

  instance_class    = var.db_instance_class
  allocated_storage = var.db_allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  username = var.db_master_username
  password = random_password.master.result
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  backup_retention_period = var.db_backup_retention_period
  backup_window           = "03:00-04:00"
  maintenance_window      = "mon:04:30-mon:05:30"

  multi_az            = false # custo: projeto de curso, não produção real
  deletion_protection = false
  skip_final_snapshot = true # simplifica terraform destroy entre sessões de trabalho

  tags = {
    Name = "oficina-db"
  }
}

# Os databases lógicos (oficina_homolog/oficina_prod) e usuários de app NÃO
# são criados aqui: exigiriam conexão TCP direta na porta 5432, e o RDS é
# `publicly_accessible = false` de propósito. Runners do GitHub Actions não
# estão na VPC, então isso não pode rodar no CI deste repo — ver
# `bootstrap-db/` (aplicado manualmente por quem tiver acesso à VPC).
