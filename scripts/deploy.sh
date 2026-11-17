#!/usr/bin/env bash
# Enciende kut.nz en AWS: crea el repositorio de imágenes, construye y sube la imagen, y aplica el resto.
#   ./scripts/deploy.sh            → despliega (o actualiza) todo; pide confirmación antes de aplicar
#   ./scripts/deploy.sh destroy    → apaga y borra todo (costo ≈ 0)
#   AUTO_APPROVE=1 ./scripts/deploy.sh   → sin confirmación interactiva (solo si ya revisaste el plan)
# Requiere: `aws login --profile kutnz --region us-east-1`, Terraform y Docker Desktop corriendo.
set -euo pipefail
cd "$(dirname "$0")/.."
TF="terraform -chdir=infra"
export AWS_DEFAULT_REGION=us-east-1 AWS_REGION=us-east-1
APPROVE=()
[[ "${AUTO_APPROVE:-0}" == "1" ]] && APPROVE=(-auto-approve)

# Sesión de `aws login`: Terraform aún no lee ese tipo de credencial, así que exportamos las
# credenciales temporales como variables de entorno (no se imprimen).
PROFILE="${AWS_PROFILE:-kutnz}"
CREDS="$(aws configure export-credentials --profile "$PROFILE" --region us-east-1 --format env)" \
  || { echo "Sesión vencida: aws login --profile $PROFILE --region us-east-1"; exit 1; }
eval "$CREDS"
unset AWS_PROFILE
aws sts get-caller-identity --query Account --output text

$TF init -input=false

if [[ "${1:-}" == "destroy" ]]; then
  $TF destroy -input=false "${APPROVE[@]}"
  exit 0
fi

docker info >/dev/null 2>&1 || { echo "Abre Docker Desktop y vuelve a intentar"; exit 1; }
TAG="v$(date +%Y%m%d%H%M%S)"

echo "### 1/3 repositorio de imágenes"
$TF apply -input=false "${APPROVE[@]}" -target=aws_ecr_repository.app -target=aws_ecr_lifecycle_policy.app
REPO="$($TF output -raw ecr_repository 2>/dev/null || true)"
[[ -n "$REPO" ]] || REPO="$(aws ecr describe-repositories --repository-names kutnz --query 'repositories[0].repositoryUri' --output text)"

echo "### 2/3 imagen $TAG"
aws ecr get-login-password | docker login --username AWS --password-stdin "${REPO%%/*}"
docker build --platform linux/amd64 -t "$REPO:$TAG" -t "$REPO:latest" .
docker push -q "$REPO:$TAG"
docker push -q "$REPO:latest"

echo "### 3/3 infraestructura"
$TF apply -input=false "${APPROVE[@]}" -var "image_tag=$TAG"
echo "### DEPLOY OK"
$TF output
