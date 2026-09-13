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

# Um database lógico + um usuário de app por ambiente (homolog/prod), na
# mesma instância — decisão Fase 0. O master user (acima) nunca é usado pela
# app, só para provisionar isso aqui.
resource "random_password" "app_user" {
  for_each = toset(var.environments)

  length  = 24
  special = false
}

resource "postgresql_database" "this" {
  for_each = toset(var.environments)

  name  = "${var.db_name}_${each.key}"
  owner = postgresql_role.app_user[each.key].name
}

resource "postgresql_role" "app_user" {
  for_each = toset(var.environments)

  name     = "${var.db_name}_${each.key}_app"
  login    = true
  password = random_password.app_user[each.key].result
}
