SHELL := /bin/bash
.RECIPEPREFIX := >
COMPOSE := docker compose

.PHONY: help up stop restart status logs validate test \
        report readme audit targets results

help:
> @echo "MiniIdM FIS"
> @echo
> @echo "make up        Construir e iniciar los servicios"
> @echo "make stop      Detener sin eliminar datos"
> @echo "make restart   Reiniciar la infraestructura"
> @echo "make status    Mostrar los contenedores"
> @echo "make logs      Mostrar registros recientes"
> @echo "make validate  Validar Compose, TLS y Prometheus"
> @echo "make test      Ejecutar las pruebas finales"
> @echo "make targets   Mostrar targets de Prometheus"
> @echo "make results   Mostrar resumen de resultados"
> @echo "make readme    Regenerar README.md"
> @echo "make report    Generar el informe PDF"
> @echo "make audit     Comprobar que no se publiquen secretos"

up:
> $(COMPOSE) up -d --build

stop:
> $(COMPOSE) stop

restart:
> $(COMPOSE) restart

status:
> $(COMPOSE) ps

logs:
> $(COMPOSE) logs --tail=100

validate:
> $(COMPOSE) config --quiet
> openssl verify \
>   -CAfile web/tls/ca.cert.pem \
>   web/tls/web.cert.pem
> $(COMPOSE) exec -T prometheus \
>   promtool check config \
>   /etc/prometheus/prometheus.yml
> $(COMPOSE) exec -T prometheus \
>   promtool check rules \
>   /etc/prometheus/alerts.yml

test:
> ./tests/test-ldap-replication.sh
> ./tests/test-kdc-failover.sh
> ./tests/test-tls-overhead.sh
> ./tests/test-haproxy-load.sh
> ./tests/test-kill9-recovery.sh
> ./tests/test-network-partition.sh
> ./tests/test-expired-certificate.sh

targets:
> curl -s \
>   'http://localhost:9090/api/v1/targets?state=active' | \
> python3 -m json.tool

results:
> cat results/phase11/resumen-final.txt

readme:
> python3 scripts/generate_readme.py

report:
> python3 docs/generate_report.py

audit:
> ./tests/security-audit.sh
