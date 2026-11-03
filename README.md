# Projeto POS-TECH FIAP - Fase III

Plataforma de feature flags (ToggleMaster) composta por 5 microsserviços:

| Serviço | Linguagem | Porta | Função |
|---|---|---|---|
| `auth-service` | Go | 8001 | Emite/valida chaves de API |
| `flag-service` | Python | 8002 | CRUD de feature flags |
| `targeting-service` | Python | 8003 | Regras de segmentação |
| `evaluation-service` | Go | 8004 | Avalia flags para um usuário, publica evento no SQS |
| `analytics-service` | Python | 8005 | Consome o SQS e persiste eventos no DynamoDB |

O código de cada microsserviço está em [toggle-master/microsservices](toggle-master/microsservices)
— cada pasta `<serviço>-main` tem seu próprio `README.md` com instruções para rodar o serviço
isoladamente (sem Docker), fora do escopo deste README.

O provisionamento de infraestrutura (Kubernetes) usa [Kustomize](https://kubectl.docs.kubernetes.io/guides/introduction/kustomize/)
com uma base comum em [k8s/base](k8s/base) e dois overlays em [k8s/overlays](k8s/overlays):
`development` (Minikube, com toda a infra local) e `production` (EKS, com recursos reais da AWS).
Detalhes completos de cada overlay estão em [k8s/README.md](k8s/README.md) — este README traz
o passo a passo resumido para provisionar cada ambiente do zero.

## Opção mais simples: Docker Compose (sem Kubernetes)

Para rodar tudo localmente sem Kubernetes, com Postgres, Redis, ElasticMQ e DynamoDB local:

```bash
cd toggle-master
docker compose up --build
```

Os serviços sobem nas portas listadas na tabela acima. Cada serviço lê variáveis de um
`.env` próprio em `toggle-master/microsservices/<serviço>-main/.env` — crie esse arquivo antes
de subir o Compose, conforme o `README.md` de cada serviço.

> O `docker-compose.yaml` na raiz do repositório é um utilitário separado (mock local de S3/SQS
> para a rede `kind`), não relacionado aos microsserviços.

## Provisionando localmente com Kubernetes (overlay `development`)

Pré-requisitos: [Minikube](https://minikube.sigs.k8s.io/) e o addon de ingress habilitado.

```bash
minikube start
minikube addons enable ingress

# 1. Construir as imagens dentro do Minikube (imagePullPolicy: Never)
minikube image build -t projeto-postech-fiap-fase-ii-auth-service:latest ./toggle-master/microsservices/auth-service-main
minikube image build -t projeto-postech-fiap-fase-ii-flag-service:latest ./toggle-master/microsservices/flag-service-main
minikube image build -t projeto-postech-fiap-fase-ii-targeting-service:latest ./toggle-master/microsservices/targeting-service-main
minikube image build -t projeto-postech-fiap-fase-ii-evaluation-service:latest ./toggle-master/microsservices/evaluation-service-main
minikube image build -t projeto-postech-fiap-fase-ii-analytics-service:latest ./toggle-master/microsservices/analytics-service-main

# 2. Aplicar todo o overlay de desenvolvimento de uma vez
kubectl apply -k k8s/overlays/development

# 3. Acompanhar
kubectl get pods -n development
```

O overlay `development` já inclui, como pods no próprio cluster: Postgres, Redis, ElasticMQ
(emulando SQS) e DynamoDB local — além de segredos fake versionados em
[k8s/overlays/development/secrets](k8s/overlays/development/secrets). Nenhuma credencial
real da AWS é necessária neste ambiente.

Para inspecionar o YAML final gerado pelo Kustomize sem aplicar:

```bash
kubectl kustomize k8s/overlays/development
```

Para reaplicar após alterar código de um serviço, reconstrua a imagem (passo 1) e rode:

```bash
kubectl rollout restart deployment/<nome-do-serviço> -n development
```

## Provisionando em produção na AWS (overlay `production`, EKS)

Em produção, Postgres, Redis, SQS e DynamoDB **não rodam como pods**: o overlay aponta para
recursos reais da AWS (RDS, ElastiCache, SQS e DynamoDB) via ConfigMap/Secret. Pré-requisitos:

- Infra criada pelo Terraform em `terraform/environments/production` (VPC, EKS, RDS,
  ElastiCache, SQS, DynamoDB, ECR) — o mesmo `apply` instala Argo CD, metrics-server, Traefik e Sealed Secrets.
- Credenciais AWS válidas (`aws sts get-caller-identity` funcionando) para build/push de
  imagens e, neste laboratório, para autenticação do `evaluation-service`/`analytics-service`
  (veja a nota sobre IRSA abaixo).

O deploy da aplicação é feito pelo **Argo CD** (Application única em
[k8s/argocd/application.yaml](k8s/argocd/application.yaml)), não por `kubectl apply -k`.

```bash
# 1. Build e push das imagens para o ECR (repositórios sem prefixo, ex.: auth-service).
#    Após o merge em main, o CI faz este passo e o 2 automaticamente
#    (ver k8s/argocd/README.md, "Publicacao de tags pelo CI").
AWS_ACCOUNT_ID=<sua-conta>
AWS_REGION=us-east-1
TAG=$(git rev-parse --short HEAD)

aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

for svc in auth-service flag-service targeting-service evaluation-service analytics-service; do
  docker build --platform linux/amd64 -t "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$svc:$TAG" "./toggle-master/microsservices/${svc}-main"
  docker push "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$svc:$TAG"
done

# 2. Atualizar newTag para $TAG em k8s/overlays/production/kustomization.yaml, commit e push

# 3. Secrets versionados como SealedSecrets (criptografados com kubeseal), em
#    k8s/overlays/production/sealed-secrets/ — ver k8s/README.md

# 4. Registrar a Application (uma vez) e sincronizar pela UI/CLI do Argo CD
kubectl apply -f k8s/argocd/application.yaml

# 5. Acompanhar
kubectl get pods -n production
kubectl rollout status deployment/evaluation-service -n production
```

O schema do Postgres (`auth_db`, `flags_db`, `targeting_db`) é aplicado automaticamente pelo
Job `postgres-schema-init`, executado como hook do Argo CD a cada sync (os scripts são
idempotentes; o RDS não roda `docker-entrypoint-initdb.d`).

> **Nota sobre credenciais AWS (IRSA):** o padrão correto de produção é usar IRSA
> (ServiceAccount + IAM Role via OIDC do EKS) para o `evaluation-service` e o
> `analytics-service` autenticarem no SQS/DynamoDB. Neste laboratório (AWS Academy) não é
> possível criar as IAM Roles necessárias, então as credenciais são fornecidas via
> `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`/`AWS_SESSION_TOKEN` diretamente nos secrets
> desses dois serviços (o SDK da AWS prioriza variáveis de ambiente antes de tentar IRSA).
> Se a sessão da AWS Academy expirar, gere novamente esses valores nos SealedSecrets com
> `kubeseal --merge-into`, faça commit/push, sincronize no Argo CD e reinicie os dois
> deployments (passo a passo em [k8s/README.md](k8s/README.md)).
>
> Em uma conta AWS real (fora de lab), prefira recriar o IRSA em vez deste workaround.

Detalhes adicionais (segredos, geração da chave real do `evaluation-service`, migração da
estrutura antiga) estão em [k8s/README.md](k8s/README.md).

## Documentação por área

Cada parte do projeto tem seu próprio README, com o passo a passo completo:

| Área | README |
|---|---|
| Infraestrutura AWS (Terraform) | [terraform/README.md](terraform/README.md) |
| Kubernetes (Kustomize, bases e overlays) | [k8s/README.md](k8s/README.md) |
| Deploy via Argo CD | [k8s/argocd/README.md](k8s/argocd/README.md) |
| SealedSecrets de produção | [k8s/overlays/production/sealed-secrets/README.md](k8s/overlays/production/sealed-secrets/README.md) |
| `auth-service` | [toggle-master/microsservices/auth-service-main/README.md](toggle-master/microsservices/auth-service-main/README.md) |
| `flag-service` | [toggle-master/microsservices/flag-service-main/README.md](toggle-master/microsservices/flag-service-main/README.md) |
| `targeting-service` | [toggle-master/microsservices/targeting-service-main/README.md](toggle-master/microsservices/targeting-service-main/README.md) |
| `evaluation-service` | [toggle-master/microsservices/evaluation-service-main/README.md](toggle-master/microsservices/evaluation-service-main/README.md) |
| `analytics-service` | [toggle-master/microsservices/analytics-service-main/README.md](toggle-master/microsservices/analytics-service-main/README.md) |

