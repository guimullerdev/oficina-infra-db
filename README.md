# oficina-infra-db

> Repositório 4 de 4 — ver `../plan.md` na raiz do projeto centralizado.

Terraform do banco de dados gerenciado da Fase 3 do Tech Challenge (deriva de
`TECH-CHALLENGE-FASE-ONE/infra/database.tf`, que rodava Postgres em pod no
`kind`). Provisiona uma instância **RDS PostgreSQL** real na AWS.

## Stack

- Terraform >= 1.9
- Provider `hashicorp/aws` ~> 5.0
- AWS RDS PostgreSQL 16
- GitHub Actions (`terraform plan`/`apply`)

## Arquitetura deste repo

Duas raízes Terraform separadas, com states independentes:

- **`.` (módulo raiz, aplicado pelo CI/CD)** — só recursos AWS puros:
  instância RDS (`db.t4g.micro`), VPC default (data source, não cria VPC
  própria — evita depender de remote state do `oficina-infra-k8s`, que só
  existe a partir da Fase 5), subnet group, Security Group liberando
  Postgres (5432) apenas para dentro do CIDR da VPC. `publicly_accessible =
  false`, sem exceção.
- **`bootstrap-db/` (aplicado manualmente, ver seu README)** — cria os 2
  databases lógicos (`oficina_homolog`, `oficina_prod`) e os usuários de app
  dentro do RDS, via provider `cyrilgdn/postgresql`. **Não roda no CI**
  porque exige conexão TCP direta na porta 5432, e os runners hospedados do
  GitHub Actions não estão na VPC — manter o RDS público só para viabilizar
  isso não foi considerado um trade-off aceitável.

Decisão de 1 conta AWS / 1 RDS / 2 databases lógicos por ambiente (em vez de
2 instâncias físicas): Fase 0 do `plan.md` (custo).

Segredo da connection string: nunca em texto plano. Senhas via
`random_password`, expostas só como output `sensitive = true`
(`database_urls`, em `bootstrap-db/outputs.tf`) — consumido por
`oficina-infra-k8s` via remote state (ver ADR 0001).

## Pré-requisitos

- Terraform >= 1.9
- Credenciais AWS configuradas (`aws configure` ou variáveis
  `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`/`AWS_SESSION_TOKEN`) com
  permissão para RDS, EC2 (VPC/SG), e Secrets/State (S3+DynamoDB)
- Bucket S3 + tabela DynamoDB do backend já criados (bootstrap manual único,
  fora deste Terraform — ver Fase 0 do `plan.md`)

## Como rodar (módulo raiz)

```bash
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

Para criar os databases/usuários de app depois disso, ver
`bootstrap-db/README.md` (passo manual, requer rede até a VPC).

## Pipeline (CI/CD)

`.github/workflows/terraform.yml`, só para o módulo raiz (`bootstrap-db/` é
sempre manual):

- **Pull request para `main`**: `terraform fmt -check`, `validate`, `plan`
  — o plano é comentado no PR automaticamente.
- **Push em `main`** (pós-merge): `terraform apply -auto-approve`.

Requer os secrets do repositório: `AWS_ACCESS_KEY_ID`,
`AWS_SECRET_ACCESS_KEY` e, se a conta usada for um AWS Academy Learner Lab
(credenciais temporárias), `AWS_SESSION_TOKEN` também.

## Migrations Prisma

Onde elas rodam contra este banco (pipeline deste repo, do repo 1, ou Job de
Kubernetes no repo 3) ainda não foi decidido/documentado como ADR — ver Fase
2 do `plan.md`.

## Diagrama

Diagrama ER do modelo relacional (gerado a partir do `prisma/schema.prisma`
da app): `TECH-CHALLENGE-FASE-ONE/docs/diagrams/0004-diagrama-er.md` — ainda
precisa ser movido/referenciado formalmente aqui.
