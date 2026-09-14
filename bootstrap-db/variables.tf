variable "aws_region" {
  description = "Região do state remoto do módulo raiz (S3)"
  type        = string
  default     = "us-east-1"
}

variable "state_bucket" {
  description = "Bucket S3 onde o módulo raiz guarda seu state (deve bater com ../backend.hcl)"
  type        = string
  default     = "oficina-tfstate-guimullerdev"
}

variable "db_name" {
  description = "Nome base do banco (prefixo dos databases lógicos oficina_homolog/oficina_prod)"
  type        = string
  default     = "oficina"
}

variable "environments" {
  description = "Databases lógicos + usuário de app por ambiente, na mesma instância RDS (decisão Fase 0: 1 conta, 1 RDS, 2 databases lógicos)"
  type        = list(string)
  default     = ["homolog", "prod"]
}

variable "db_host_override" {
  description = <<-EOT
    Host/porta alternativos para alcançar o RDS, no formato "host:porta".

    O RDS é privado, então este módulo só roda de dentro da VPC — ou através
    de um túnel. Ao tunelar (kubectl port-forward, SSM port forwarding,
    bastion), informe aqui o endereço local do túnel; vazio usa o endpoint
    real vindo do remote state.
  EOT
  type        = string
  default     = ""
}
