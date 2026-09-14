# Conecta direto no RDS via usuário master — só funciona de uma máquina com
# rota de rede até a VPC (o RDS é publicly_accessible = false de propósito).
# Ver README.md deste diretório para como abrir esse acesso.
locals {
  host_efetivo  = var.db_host_override != "" ? split(":", var.db_host_override)[0] : data.terraform_remote_state.root.outputs.db_address
  porta_efetiva = var.db_host_override != "" ? tonumber(split(":", var.db_host_override)[1]) : data.terraform_remote_state.root.outputs.db_port
}

provider "postgresql" {
  host            = local.host_efetivo
  port            = local.porta_efetiva
  username        = data.terraform_remote_state.root.outputs.db_master_username
  password        = data.terraform_remote_state.root.outputs.db_master_password
  database        = "postgres"
  sslmode         = var.db_host_override != "" ? "prefer" : "require"
  connect_timeout = 15
  superuser       = false
}
