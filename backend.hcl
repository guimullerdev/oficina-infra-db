# Config do backend remoto (S3 + DynamoDB), compartilhado com oficina-infra-k8s
# com prefixo de key diferente por repo (ver ADR 0001). Não contém segredo —
# só nomes de recursos. O bucket/tabela precisam existir antes do primeiro
# `terraform init` (bootstrap manual — não dá para o Terraform versionar o
# backend do próprio state).
bucket         = "oficina-tfstate-guimullerdev"
key            = "infra-db/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "oficina-terraform-locks"
encrypt        = true
