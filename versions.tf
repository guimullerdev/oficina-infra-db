terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Bucket/tabela criados manualmente uma única vez (bootstrap, fora do
  # Terraform gerenciado — ver ADR 0001). Valores reais passados via
  # `terraform init -backend-config=backend.hcl`.
  backend "s3" {}
}
