# Lê os outputs do módulo raiz (RDS já criado) para saber onde conectar e
# com qual credencial master. Requer que `terraform apply` do módulo raiz já
# tenha rodado com sucesso.
data "terraform_remote_state" "root" {
  backend = "s3"

  config = {
    bucket = var.state_bucket
    key    = "infra-db/terraform.tfstate"
    region = var.aws_region
  }
}
