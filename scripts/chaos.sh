#!/usr/bin/env bash
# Experimentos de caos para la demo. Correr MIENTRAS k6 genera carga y observar el dashboard.
#   ./scripts/chaos.sh az        → termina todas las instancias de una zona de disponibilidad
#   ./scripts/chaos.sh redis     → fuerza el failover de Redis (primario → réplica en la otra AZ)
#   ./scripts/chaos.sh instance  → termina una instancia al azar
set -euo pipefail
ASG="$(terraform -chdir="$(dirname "$0")/../infra" output -raw asg_name)"

case "${1:-}" in
  az)
    AZ="$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "$ASG" \
          --query 'AutoScalingGroups[0].Instances[0].AvailabilityZone' --output text)"
    IDS="$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "$ASG" \
          --query "AutoScalingGroups[0].Instances[?AvailabilityZone=='$AZ'].InstanceId" --output text)"
    echo "Terminando instancias de $AZ: $IDS"
    aws ec2 terminate-instances --instance-ids $IDS >/dev/null ;;
  redis)
    aws elasticache test-failover --replication-group-id kutnz-cache --node-group-id 0001 >/dev/null
    echo "Failover de Redis iniciado" ;;
  instance)
    ID="$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "$ASG" \
          --query 'AutoScalingGroups[0].Instances[0].InstanceId' --output text)"
    echo "Terminando $ID"
    aws ec2 terminate-instances --instance-ids "$ID" >/dev/null ;;
  *) echo "uso: $0 az|redis|instance"; exit 1 ;;
esac
echo "Observa: dashboard de CloudWatch (instancias en servicio, 5xx, p95) y el resumen de k6."
