terraform {
  required_version = ">= 1.9"

  required_providers {
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = "~> 1.22"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Estado próprio, mesmo bucket/tabela do módulo raiz, key diferente (ver
  # ADR 0001). Valores reais em backend.hcl.
  backend "s3" {}
}
