# oficina-infra-db

> Repositório 4 de 4 — Tech Challenge Fase 3 (SOAT).

Terraform do banco de dados gerenciado da Fase 3 do Tech Challenge (deriva de
`TECH-CHALLENGE-FASE-ONE/infra/database.tf`, que rodava Postgres em pod no
`kind`). Provisiona uma instância **RDS PostgreSQL** real na AWS.

## Infraestrutura ativa

| Recurso | Valor |
|---|---|
| Instância | `oficina-db` · PostgreSQL 16.4 · `db.t4g.micro` |
| Região | `us-east-1`, na VPC default da conta |
| Acesso público | **não** — `publicly_accessible = false` |
| Databases | `oficina_os` e `oficina_billing` (um por serviço) |
| Retenção de backup | 1 dia (limite do Free Tier) |

**Não há endpoint público a divulgar, e isso é intencional.** O banco só é
alcançável de dentro da VPC: pelos pods do EKS e pela Lambda de autenticação.
Quem quiser ver o dado passa pela API:

- https://7eu2kz40xj.execute-api.us-east-1.amazonaws.com/prod
- Dashboard de observabilidade: https://onenr.io/0qwykVVv1jn

Para acesso administrativo direto (migrations manuais, inspeção), use um túnel
SSM — é assim que o `bootstrap-db/` cria os databases lógicos, já que
os runners do GitHub Actions também estão fora da VPC.

> Infraestrutura de curso, provisionada para a avaliação e destruída depois.

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
- **`bootstrap-db/` (aplicado manualmente, ver seu README)** — cria um
  database lógico por serviço (`oficina_os`, `oficina_billing`) e a role de app
  de cada um (`oficina_os_app`, `oficina_billing_app`) dentro do RDS, via
  provider `cyrilgdn/postgresql`, com isolamento entre os databases. **Não roda no CI**
  porque exige conexão TCP direta na porta 5432, e os runners hospedados do
  GitHub Actions não estão na VPC — manter o RDS público só para viabilizar
  isso não foi considerado um trade-off aceitável.

Decisão de 1 conta AWS / 1 RDS / 1 database lógico por serviço, em vez de
1 instância física por serviço: ADR 0008 do `oficina-os-service`
(`docs/adr/0008-um-rds-dois-bancos-logicos.md`). O motivo é custo —
duplicar a instância dobraria a conta sem isolamento real necessário para um
projeto de curso.

Segredo da connection string: nunca em texto plano. Senhas via
`random_password`, expostas só como output `sensitive = true`
(`database_urls`, em `bootstrap-db/outputs.tf`, com chaves `os` e `billing`).
O valor é copiado à mão para os secrets `DATABASE_URL` do environment `prod`
de cada serviço.

## Pré-requisitos

- Terraform >= 1.9
- Credenciais AWS configuradas (`aws configure` ou variáveis
  `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`/`AWS_SESSION_TOKEN`) com
  permissão para RDS, EC2 (VPC/SG), e Secrets/State (S3+DynamoDB)
- Bucket S3 + tabela DynamoDB do backend já criados (bootstrap manual único,
  fora deste Terraform — é o problema do ovo e da galinha de versionar o
  próprio backend do state)

## Como rodar (módulo raiz)

```bash
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

Para criar os databases/usuários de app depois disso, ver
`bootstrap-db/README.md` (passo manual, requer rede até a VPC).

## Pipeline (CI/CD)

`.github/workflows/terraform.yml`:

- **Pull request para `main`**: `terraform fmt -check`, `validate`, `plan`
  no módulo raiz — o plano é comentado no PR automaticamente. `fmt -check` e
  `validate` também rodam em `bootstrap-db/`.
- **Push em `main`** (pós-merge): `terraform apply -auto-approve`, só no
  módulo raiz (`.`). `bootstrap-db/` nunca é aplicado pelo CI.

Requer os secrets do repositório: `AWS_ACCESS_KEY_ID`,
`AWS_SECRET_ACCESS_KEY` e, se a conta usada for um AWS Academy Learner Lab
(credenciais temporárias), `AWS_SESSION_TOKEN` também.

## Migrations Prisma

Onde elas rodam está decidido na **ADR 0005** (repo da aplicação): um Job de
Kubernetes dentro do cluster, aplicado pelo pipeline da aplicação e aguardado
antes do rollout. Aqui não, porque este repositório não conhece o schema; e
não no start do pod, porque uma migration que falha derrubaria réplicas em
CrashLoop.

## Diagrama

Diagrama ER do modelo relacional (gerado a partir do `prisma/schema.prisma`
da app): `TECH-CHALLENGE-FASE-ONE/docs/diagrams/0004-diagrama-er.md` — ainda
precisa ser movido/referenciado formalmente aqui.
