# Mesmo bucket/tabela do módulo raiz (../backend.hcl), key própria para não
# colidir com o state do RDS/rede.
bucket         = "oficina-tfstate-guimullerdev"
key            = "infra-db/bootstrap/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "oficina-terraform-locks"
encrypt        = true
