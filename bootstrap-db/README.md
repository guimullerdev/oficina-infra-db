# bootstrap-db

Cria os databases lógicos (`oficina_os`, `oficina_billing`), um por serviço,
e as roles de app dentro do RDS provisionado pelo módulo raiz (`../`).

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

O apply é manual, por túnel SSM. Usar a variável
`db_host_override="localhost:<porta>"`, apontando para a porta local do túnel.

## Isolamento

- Cada serviço tem seu database e sua role de login: `oficina_os` /
  `oficina_os_app` e `oficina_billing` / `oficina_billing_app`. A senha de cada
  role é gerada por `random_password`, e a role é dona do seu database.
- `CONNECT` e `TEMPORARY` são revogados de `PUBLIC` em cada database, e `ALL`
  é revogado de `PUBLIC` no schema `public`.
- Só a própria role conecta ao seu database, além do usuário master (que o
  Terraform usa para configurar o schema). Ninguém de um serviço lê o banco do
  outro.
- O `permission denied` entre os bancos não é verificado neste PR: ele será
  comprovado na janela de apply (Fase 4 do plano de infra).

## Outputs

```bash
terraform output -json database_urls | jq -r '.os'
terraform output -json database_urls | jq -r '.billing'
```

Os valores são copiados à mão para os secrets `DATABASE_URL` do environment
`prod` de cada serviço.
