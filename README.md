# oficina-infra-db

> Repositório 4 de 4 — ver `../plan.md` na raiz do projeto centralizado.

Terraform do banco de dados gerenciado da Fase 3 do Tech Challenge (deriva de
`TECH-CHALLENGE-FASE-ONE/infra/database.tf`, que rodava Postgres em pod no
`kind`). Provisiona uma instância **RDS PostgreSQL** real na AWS.

## Stack

- Terraform >= 1.9
- Provider `hashicorp/aws` ~> 5.0
- Provider `cyrilgdn/postgresql` ~> 1.22 (cria os databases/usuários de app
  dentro da instância, depois que ela existe)
- AWS RDS PostgreSQL 16

## Arquitetura deste repo

- **1 instância RDS** (`db.t4g.micro`), **2 databases lógicos** na mesma
  instância — `oficina_homolog` e `oficina_prod` — cada um com seu próprio
  usuário de aplicação (o usuário master nunca é usado pela app). Decisão
  documentada na Fase 0 do `plan.md`: 1 conta AWS, 1 RDS, separação lógica
  por ambiente em vez de 2 instâncias físicas (custo).
- **Rede**: usa a VPC default da conta (data source, não cria VPC própria)
  para não depender de remote state do `oficina-infra-k8s`, que só existe a
  partir da Fase 5 — ver comentário em `network.tf`. Security Group libera
  Postgres (5432) só para dentro do CIDR da VPC, nunca para a internet.
- **Segredo da connection string**: nunca em texto plano no código. Senhas
  geradas via `random_password`, expostas só como output Terraform marcado
  `sensitive = true` (`database_urls`) — consumido por `oficina-infra-k8s`
  via remote state (ver ADR 0001).

## Pré-requisitos

- Terraform >= 1.9
- Credenciais AWS configuradas (`aws configure` ou variáveis
  `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`/`AWS_SESSION_TOKEN`) com
  permissão para RDS, EC2 (VPC/SG), e Secrets/State (S3+DynamoDB)
- Bucket S3 + tabela DynamoDB do backend já criados (bootstrap manual único,
  fora deste Terraform — ver Fase 0 do `plan.md`)

## Como rodar

```bash
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

Para obter a connection string de um ambiente específico depois do apply:

```bash
terraform output -json database_urls | jq -r '.homolog'
terraform output -json database_urls | jq -r '.prod'
```

## Pipeline (CI/CD)

Ainda não implementada — planejada: `terraform plan` comentado em PR,
`apply` automático pós-merge em `main`, usando o mesmo backend S3/DynamoDB.
Ver Fase 2 do `plan.md`.

## Migrations Prisma

Onde elas rodam contra este banco (pipeline deste repo, do repo 1, ou Job de
Kubernetes no repo 3) ainda não foi decidido/documentado como ADR — ver Fase
2 do `plan.md`.

## Diagrama

Diagrama ER do modelo relacional (gerado a partir do `prisma/schema.prisma`
da app): `TECH-CHALLENGE-FASE-ONE/docs/diagrams/0004-diagrama-er.md` — ainda
precisa ser movido/referenciado formalmente aqui.
