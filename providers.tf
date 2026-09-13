provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "tech-challenge-fase3"
      Repo      = "oficina-infra-db"
      ManagedBy = "terraform"
    }
  }
}

# Conecta na própria instância RDS recém-criada (via master user) para criar
# os databases lógicos e usuários de app — ver database.tf. Precisa rodar
# depois do aws_db_instance existir, por isso os data/resource abaixo
# dependem do endpoint dele.
provider "postgresql" {
  host            = aws_db_instance.this.address
  port            = aws_db_instance.this.port
  username        = aws_db_instance.this.username
  password        = random_password.master.result
  database        = "postgres"
  sslmode         = "require"
  connect_timeout = 15
  superuser       = false
}
