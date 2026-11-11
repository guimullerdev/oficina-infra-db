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
  description = "Prefixo dos databases (<db_name>_<serviço>) e das roles (<db_name>_<serviço>_app)"
  type        = string
  default     = "oficina"
}

variable "services" {
  description = "Serviços com database lógico + role dona própria na mesma instância RDS (ADR 0008: um RDS, dois bancos lógicos, zero grants cruzados)"
  type        = list(string)
  default     = ["os", "billing"]

  validation {
    condition = (
      length(var.services) > 0 &&
      length(distinct(var.services)) == length(var.services) &&
      alltrue([for s in var.services : can(regex("^[a-z][a-z0-9]{1,20}$", s))])
    )
    error_message = "services: lista não vazia, sem repetição, cada item em minúsculas [a-z][a-z0-9] com 2 a 21 caracteres (vira parte de nome de database/role)."
  }
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
