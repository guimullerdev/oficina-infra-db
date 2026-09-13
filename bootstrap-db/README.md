# bootstrap-db

Cria os databases lógicos (`oficina_homolog`, `oficina_prod`) e os usuários
de app dentro do RDS provisionado pelo módulo raiz (`../`).

## Por que isso não está no CI/CD do repo

O RDS é `publicly_accessible = false` de propósito — só é alcançável de
dentro da VPC. Runners hospedados do GitHub Actions não estão na VPC, então
`terraform apply` deste diretório não pode rodar automaticamente na
pipeline. Precisa ser aplicado manualmente, uma vez, de uma máquina com rota
de rede até a VPC:

- Via AWS Systems Manager Session Manager (port forwarding através de uma
  instância na VPC), ou
- Uma vez que `oficina-infra-k8s` existir (Fase 5), de dentro do cluster
  (ex.: um pod temporário/Job com `terraform` instalado), ou
- De uma VPN/bastion, se o time tiver um configurado.

## Pré-requisitos

- O `terraform apply` do módulo raiz (`../`) já ter rodado com sucesso.
- Rede alcançando a porta 5432 do RDS (ver acima).

## Como rodar

```bash
cd bootstrap-db
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

```bash
terraform output -json database_urls | jq -r '.homolog'
terraform output -json database_urls | jq -r '.prod'
```
