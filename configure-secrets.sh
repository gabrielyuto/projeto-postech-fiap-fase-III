#!/usr/bin/env bash

# Execução: 
# chmod +x configure-secrets.sh
# ./configure-secrets.sh

# Interrompe o script se algum comando falhar (-e) ou se houver erro em pipes (-o pipefail)
set -eo pipefail
# Desativa expansão de histórico com '!' no bash (equivalente ao NO_BANG_HIST do zsh)
set +H

# ============================================
# GENERAL VARIABLES
# ============================================
# Usa a variável de ambiente se já existir; caso contrário, busca no aws configure
AWS_REGION="${AWS_REGION:-$(aws configure get region || true)}"
AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-$(aws configure get aws_access_key_id || true)}"
AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-$(aws configure get aws_secret_access_key || true)}"
AWS_SESSION_TOKEN="${AWS_SESSION_TOKEN:-$(aws configure get aws_session_token || true)}"

CLUSTER_NAME="toggle-master-eks"
DB_INSTANCE_ID="toggle-master-rds"

# 1. Validação de variáveis obrigatórias
if [[ -z "$AWS_REGION" || -z "$AWS_ACCESS_KEY_ID" || -z "$AWS_SECRET_ACCESS_KEY" ]]; then
    echo "❌ Erro: Credenciais básicas da AWS ou Região estão vazias."
    echo "   Verifique seu 'aws configure' ou exporte AWS_REGION, AWS_ACCESS_KEY_ID e AWS_SECRET_ACCESS_KEY."
    exit 1
fi

# 2. Aviso sobre o Session Token
if [[ -z "$AWS_SESSION_TOKEN" ]]; then
    echo "⚠️  Aviso: AWS_SESSION_TOKEN está vazio (Normal para IAM User padrão, mas falhará se for AWS Academy/SSO)."
fi

# ============================================
# AWS AUTHENTICATION CHECK
# ============================================
if ! ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text 2>/dev/null); then
    echo "❌ Erro: Não foi possível autenticar na AWS. Verifique se suas credenciais são válidas ou se expiraram."
    exit 1
fi
echo "✅ Conta AWS identificada: ${ACCOUNT_ID} (Região: ${AWS_REGION})"


# ============================================
# RDS VARIABLES
# ============================================
# ============================================
# RDS VARIABLES
# ============================================
if ! DB_HOST=$(aws rds describe-db-instances --db-instance-identifier "${DB_INSTANCE_ID}" --query 'DBInstances[0].Endpoint.Address' --output text 2>/dev/null) || [[ -z "$DB_HOST" || "$DB_HOST" == "None" ]]; then
    echo "❌ Erro: Não foi possível obter o endpoint do RDS. Verifique se a instância '${DB_INSTANCE_ID}' existe e está disponível."
    exit 1
fi
echo "✅ Endpoint do RDS identificado: ${DB_HOST}"

if ! DB_ARN=$(aws rds describe-db-instances --db-instance-identifier "${DB_INSTANCE_ID}" --query 'DBInstances[0].MasterUserSecret.SecretArn' --output text 2>/dev/null) || [[ -z "$DB_ARN" || "$DB_ARN" == "None" ]]; then
    echo "❌ Erro: Não foi possível obter o ARN do segredo mestre do RDS."
    exit 1
fi
echo "✅ ARN do segredo mestre do RDS identificado: ${DB_ARN}"

if ! SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id "${DB_ARN}" --query SecretString --output text 2>/dev/null); then
    echo "❌ Erro: Não foi possível obter o segredo do RDS no Secrets Manager."
    exit 1
fi

DB_USER=$(echo "$SECRET_JSON" | jq -r '.username')
DB_PASS=$(echo "$SECRET_JSON" | jq -r '.password')
DB_PASS_ENC=$(python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=""))' "$DB_PASS")
DB_URL="postgres://${DB_USER}:${DB_PASS_ENC}@${DB_HOST}:5432/${DB_DATABASE_NAME}?sslmode=require"

echo "✅ Credenciais do RDS processadas com sucesso (Usuário: ${DB_USER})."

# ============================================
# DEFINE CONTEXT FOR KUBECTL
# ============================================
CTX="arn:aws:eks:${AWS_REGION}:${ACCOUNT_ID}:cluster/${CLUSTER_NAME}"
echo "⚙️  Atualizando o contexto do kubectl para o EKS (${CTX})..."
aws eks update-kubeconfig --region "${AWS_REGION}" --name "${CLUSTER_NAME}"

if ! kubectl --context "$CTX" -n kube-system get pods | grep -q sealed-secrets; then
    echo "❌ Erro: Pod do sealed-secrets não encontrado no namespace kube-system."
    exit 1
fi
echo "✅ Controller do Sealed Secrets ativo."

# ============================================
# TERRAFORM VARIABLES & VALIDATION
# ============================================
TF_DIR="terraform/environments/production"
echo "⚙️  Lendo outputs do Terraform em '${TF_DIR}'..."

VALKEY_ENDPOINT=$(terraform -chdir="$TF_DIR" output -raw valkey_endpoint)
VALKEY_PORT=$(terraform -chdir="$TF_DIR" output -raw valkey_port)
AWS_SQS_URL=$(terraform -chdir="$TF_DIR" output -raw sqs_queue_url)
DYNAMODB_TABLE_NAME=$(terraform -chdir="$TF_DIR" output -raw dynamodb_table_name)

if [[ -z "$VALKEY_ENDPOINT" || -z "$VALKEY_PORT" || -z "$AWS_SQS_URL" || -z "$DYNAMODB_TABLE_NAME" ]]; then
    echo "❌ Erro: Um ou mais outputs do Terraform retornaram vazios. Verifique se o 'terraform apply' foi concluído em '${TF_DIR}'."
    exit 1
fi

REDIS_URL="rediss://${VALKEY_ENDPOINT}:${VALKEY_PORT}"
echo "✅ Outputs do Terraform carregados com sucesso."

# ============================================
# KUBESEAL PROCESS
# ============================================
MASTER_KEY="admin-secreto-123"
SERVICE_API_KEY="trocar-na-implantacao"
OUT_DIR="k8s/overlays/production/sealed-secrets"

secrets=(
  "analytics-service-secret"
  "auth-service-secret"
  "evaluation-service-secret"
  "flag-service-secret"
  "targeting-service-secret"
  "postgres-admin-secret"
)

# Função auxiliar para atualizar o SealedSecret existente
seal_secret() {
  local target_file="$1"
  kubeseal \
    --context "$CTX" \
    --controller-namespace kube-system \
    --controller-name sealed-secrets-controller \
    --format yaml \
    --merge-into "$target_file"
}

for s in "${secrets[@]}"; do
  TARGET_FILE="${OUT_DIR}/${s}.yaml"

  if [[ ! -f "$TARGET_FILE" ]]; then
    echo "❌ Erro: O arquivo '${TARGET_FILE}' não foi encontrado para realizar o merge."
    exit 1
  fi

  echo "🔒 Atualizando segredo: ${s} -> ${TARGET_FILE}"

  case "$s" in
    "analytics-service-secret")
      kubectl create secret generic "$s" -n production --dry-run=client -o json \
        --from-literal=AWS_REGION="$AWS_REGION" \
        --from-literal=AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
        --from-literal=AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
        --from-literal=AWS_SESSION_TOKEN="$AWS_SESSION_TOKEN" \
        --from-literal=AWS_DYNAMODB_TABLE="$DYNAMODB_TABLE_NAME" \
        --from-literal=AWS_SQS_URL="$AWS_SQS_URL" \
      | seal_secret "$TARGET_FILE"
      ;;

    "auth-service-secret")
      kubectl create secret generic "$s" -n production --dry-run=client -o json \
        --from-literal=DATABASE_URL="$DB_URL" \
        --from-literal=MASTER_KEY="$MASTER_KEY" \
      | seal_secret "$TARGET_FILE"
      ;;

    "evaluation-service-secret")
      kubectl create secret generic "$s" -n production --dry-run=client -o json \
        --from-literal=AWS_REGION="$AWS_REGION" \
        --from-literal=AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
        --from-literal=AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
        --from-literal=AWS_SESSION_TOKEN="$AWS_SESSION_TOKEN" \
        --from-literal=AWS_SQS_URL="$AWS_SQS_URL" \
        --from-literal=REDIS_URL="$REDIS_URL" \
        --from-literal=SERVICE_API_KEY="$SERVICE_API_KEY" \
      | seal_secret "$TARGET_FILE"
      ;;

    "flag-service-secret"|"targeting-service-secret")
      kubectl create secret generic "$s" -n production --dry-run=client -o json \
        --from-literal=DATABASE_URL="$DB_URL" \
      | seal_secret "$TARGET_FILE"
      ;;
    
    "postgres-admin-secret")
      kubectl create secret generic "$s" -n production --dry-run=client -o json \
        --from-literal=DATABASE_URL="$DB_URL" \
      | seal_secret "$TARGET_FILE"
      ;;
  esac
done

echo "✨ Tudo pronto! Todos os SealedSecrets foram atualizados em '${OUT_DIR}'."