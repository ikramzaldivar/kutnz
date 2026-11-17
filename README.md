# kut.nz

Acortador de enlaces escalable y de alta disponibilidad en AWS. Proyecto final de **Diseño de Sistemas Escalables** (ITESO, 2026).

Pegas un enlace largo y recibes `kut.nz/abc1234` con su QR. Con cuenta: alias, edición del destino, caducidad, límite de clics, contraseña, métricas y panel. Todo lo que hace la web se puede hacer con la API REST (`/api/docs`).

## Arquitectura

```
Visitante ─► Route 53 (kut.nz) ─► CloudFront + WAF ─┬─► S3 (/static/*, CDN)
                                                    └─► ALB (2 AZ, solo desde CloudFront)
                                                          └─► ASG EC2 en subredes privadas (2 AZ)
                                                                ├─ contenedor API (FastAPI)
                                                                └─ contenedor worker de clics
                                       ElastiCache Valkey Multi-AZ ◄─┤
                                       DynamoDB (enlaces, métricas) ◄┤
                                       SQS + DLQ (eventos de clic) ◄─┘
                                       Cognito (cuentas) · CloudWatch (dashboard, alarmas) · Budgets
```

Las decisiones y sus trade-offs están en [docs/adr.md](docs/adr.md).

## Estructura

| Carpeta | Contenido |
|---|---|
| `app/` | API FastAPI, redirección, páginas HTML y frontend (`app/static`) |
| `worker/` | Consumidor de SQS que agrega las métricas |
| `infra/` | Terraform (red, datos, cómputo, borde, auth, observabilidad) |
| `tests/` | Pruebas con DynamoDB/SQS simulados (moto) y Redis en memoria |
| `loadtest/` | k6: carga de redirección y prueba de concurrencia del límite de clics |
| `scripts/` | `dev_server.py`, `deploy.sh`, `chaos.sh` |
| `docs/` | ADRs y el póster de la ExpoDESI |

## Desarrollo local (sin Docker ni AWS)

```bash
python -m venv .venv && .venv/Scripts/pip install -r requirements-dev.txt
.venv/Scripts/python -m pytest -q          # 34 pruebas
.venv/Scripts/python scripts/dev_server.py # http://localhost:8000
```

En local el login es de prueba: cualquier nombre inicia sesión (`nombre:admin` para administrador).

## Desplegar en AWS

1. `aws configure sso` (o credenciales de un usuario IAM) y Docker Desktop abierto.
2. `cp infra/terraform.tfvars.example infra/terraform.tfvars` y llenar el correo de alertas y la API key de Safe Browsing.
3. `./scripts/deploy.sh` — crea todo (~15 min la primera vez; CloudFront tarda en propagarse).
4. Crear un administrador: registrarse en la web y luego
   `aws cognito-idp admin-add-user-to-group --user-pool-id <id> --username <correo> --group-name admin`.
5. **Al terminar:** `./scripts/deploy.sh destroy` (encendido cuesta ≈ 0.15 USD/h).

## Verificación

| Qué | Cómo |
|---|---|
| Reglas de negocio | `pytest` (34 pruebas, incluida la del límite de clics con 80 visitas concurrentes) |
| SLO de latencia y escalado | `k6 run -e BASE=https://kut.nz -e CODES=a,b,c loadtest/redirect.js` + dashboard |
| Límite de clics exacto | enlace con máximo 100 + `loadtest/click_limit.js` (1 000 visitas) → 100 × 302 |
| Tolerancia a fallos | `./scripts/chaos.sh az` durante la carga → 0 errores visibles |
| Seguridad de IaC y dependencias | CI: checkov + pip-audit (`.github/workflows/ci.yml`) |
