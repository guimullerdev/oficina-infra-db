# Usa a VPC default da conta em vez de criar uma própria: evita depender de
# remote state do oficina-infra-k8s (que só é provisionado na Fase 5, depois
# deste repo) só para saber VPC/subnets. Trade-off aceito para um projeto de
# curso com 1 conta/1 região — reavaliar se algum dia precisar de rede
# isolada por ambiente.
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_db_subnet_group" "this" {
  name       = "oficina-db-subnet-group"
  subnet_ids = data.aws_subnets.default.ids

  tags = {
    Name = "oficina-db-subnet-group"
  }
}

# Libera Postgres (5432) só para dentro da VPC default — não para a
# internet. EKS (repo 3) e a Lambda (repo 2) precisam rodar nessa mesma VPC
# para alcançar o banco (decisão Fase 0: Lambda acessa o RDS diretamente).
resource "aws_security_group" "rds" {
  name        = "oficina-rds-sg"
  description = "Permite Postgres apenas de dentro da VPC default"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "Postgres a partir da VPC default"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.default.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "oficina-rds-sg"
  }
}
