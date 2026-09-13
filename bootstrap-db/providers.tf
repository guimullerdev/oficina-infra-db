# Conecta direto no RDS via usuário master — só funciona de uma máquina com
# rota de rede até a VPC (o RDS é publicly_accessible = false de propósito).
# Ver README.md deste diretório para como abrir esse acesso.
provider "postgresql" {
  host            = data.terraform_remote_state.root.outputs.db_address
  port            = data.terraform_remote_state.root.outputs.db_port
  username        = data.terraform_remote_state.root.outputs.db_master_username
  password        = data.terraform_remote_state.root.outputs.db_master_password
  database        = "postgres"
  sslmode         = "require"
  connect_timeout = 15
  superuser       = false
}
