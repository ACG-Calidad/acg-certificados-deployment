.PHONY: help build up down restart logs shell db-shell install migrate clean

# Colores para output
GREEN  := $(shell tput -Txterm setaf 2)
YELLOW := $(shell tput -Txterm setaf 3)
RESET  := $(shell tput -Txterm sgr0)

help: ## Mostrar ayuda
	@echo ''
	@echo '${GREEN}Makefile para ACG Certificados${RESET}'
	@echo ''
	@echo 'Uso:'
	@echo '  ${YELLOW}make${RESET} ${GREEN}<target>${RESET}'
	@echo ''
	@echo 'Targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  ${YELLOW}%-15s${RESET} %s\n", $$1, $$2}'

build: ## Construir imágenes Docker
	docker-compose build

up: ## Levantar servicios
	docker-compose up -d
	@echo ''
	@echo '${GREEN}✓ Servicios levantados${RESET}'
	@echo '  Backend:     http://localhost:8080'
	@echo '  phpMyAdmin:  http://localhost:8081'
	@echo ''

down: ## Detener servicios
	docker-compose down

restart: ## Reiniciar servicios
	docker-compose restart

logs: ## Ver logs en tiempo real
	docker-compose logs -f

logs-php: ## Ver logs de PHP
	docker-compose logs -f php

logs-db: ## Ver logs de MariaDB
	docker-compose logs -f mariadb

shell: ## Acceder a shell de PHP
	docker-compose exec php bash

db-shell: ## Acceder a shell de MariaDB
	docker-compose exec mariadb mysql -u certificates_app -pdev_password moodle51_dev

install: up ## Instalar dependencias
	docker-compose exec php composer install
	@echo '${GREEN}✓ Dependencias instaladas${RESET}'

migrate: ## Ejecutar migración de BD
	docker-compose exec php php /var/www/html/scripts/migrate_database.php

status: ## Ver estado de contenedores
	docker-compose ps

clean: ## Limpiar contenedores y volúmenes
	docker-compose down -v
	@echo '${YELLOW}⚠ Base de datos eliminada${RESET}'

rebuild: clean build up install ## Reconstruir todo desde cero
	@echo '${GREEN}✓ Ambiente reconstruido${RESET}'

# Comandos de desarrollo
dev: up ## Iniciar ambiente de desarrollo
	@echo '${GREEN}✓ Ambiente listo para desarrollo${RESET}'
	@echo ''
	@echo 'Servicios disponibles:'
	@echo '  Backend API:    ${YELLOW}http://localhost:8080${RESET}'
	@echo '  phpMyAdmin:     ${YELLOW}http://localhost:8081${RESET}'
	@echo '  Base de Datos:  ${YELLOW}127.0.0.1:3307${RESET}'
	@echo ''
	@echo 'Ejecuta ${YELLOW}make logs${RESET} para ver logs en tiempo real'

test: ## Ejecutar tests
	docker-compose exec php composer test

composer: ## Ejecutar comando de Composer (uso: make composer cmd="require vendor/package")
	docker-compose exec php composer $(cmd)

# Backup y restore
backup: ## Crear backup de BD
	@mkdir -p backups
	docker-compose exec mariadb mysqldump -u root -proot_password_dev moodle51_dev > backups/backup_$$(date +%Y%m%d_%H%M%S).sql
	@echo '${GREEN}✓ Backup creado en backups/${RESET}'

restore: ## Restaurar backup (uso: make restore file=backup.sql)
	@docker-compose exec -T mariadb mysql -u root -proot_password_dev moodle51_dev < $(file)
	@echo '${GREEN}✓ Backup restaurado${RESET}'
