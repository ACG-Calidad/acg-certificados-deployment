#!/bin/bash

###############################################################################
# Script para Reiniciar Base de Datos Local desde Backup
# ACG Calidad - Gestor de Certificados
#
# Descripción:
#   Este script permite reiniciar la base de datos local de Moodle
#   desde un backup específico. Útil para pruebas donde necesitas
#   volver al estado inicial de los datos.
#
# Uso:
#   ./reset-database.sh [fecha_backup]
#
# Ejemplos:
#   ./reset-database.sh                  # Usa el backup más reciente
#   ./reset-database.sh 20260109         # Usa el backup del 9 de enero 2026
#
# Autor: Oliver Castelblanco
# Fecha: 2026-01-09
###############################################################################

set -e  # Salir si hay algún error

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables
PROJECT_DIR="/Users/ocastelblanco/Documents/ACG/Actualizacion2026/acg-gestor-certificados"
BACKUP_DIR="$PROJECT_DIR/backups"
DATE_PARAM=$1

###############################################################################
# Funciones
###############################################################################

print_header() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

find_backup() {
    print_header "Buscando Backup"

    cd "$BACKUP_DIR"

    if [ -z "$DATE_PARAM" ]; then
        # No se especificó fecha, buscar el más reciente
        print_info "No se especificó fecha, buscando el backup más reciente..."

        LATEST_BACKUP=$(ls -t moodle51_backup_*.sql.gz 2>/dev/null | head -1)

        if [ -z "$LATEST_BACKUP" ]; then
            # Buscar archivos .sql (ya descomprimidos)
            LATEST_BACKUP=$(ls -t moodle51_backup_*.sql 2>/dev/null | head -1)
        fi

        if [ -z "$LATEST_BACKUP" ]; then
            print_error "No se encontraron backups en $BACKUP_DIR"
            exit 1
        fi

        BACKUP_FILE="$BACKUP_DIR/$LATEST_BACKUP"
        print_success "Backup encontrado: $LATEST_BACKUP"
    else
        # Buscar backup con la fecha especificada
        print_info "Buscando backup de fecha: $DATE_PARAM"

        if [ -f "$BACKUP_DIR/moodle51_backup_${DATE_PARAM}.sql.gz" ]; then
            BACKUP_FILE="$BACKUP_DIR/moodle51_backup_${DATE_PARAM}.sql.gz"
        elif [ -f "$BACKUP_DIR/moodle51_backup_${DATE_PARAM}.sql" ]; then
            BACKUP_FILE="$BACKUP_DIR/moodle51_backup_${DATE_PARAM}.sql"
        else
            print_error "No se encontró backup para la fecha: $DATE_PARAM"
            print_info "Backups disponibles:"
            ls -1 moodle51_backup_*.sql* 2>/dev/null | sed 's/^/  - /'
            exit 1
        fi

        print_success "Backup encontrado: $(basename $BACKUP_FILE)"
    fi
}

check_docker() {
    print_header "Verificando Docker"

    cd "$PROJECT_DIR"

    # Verificar que Docker está corriendo
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker no está corriendo. Por favor, inicia Docker Desktop."
        exit 1
    fi
    print_success "Docker está corriendo"

    # Verificar que el contenedor de MariaDB existe
    if ! docker-compose ps mariadb | grep -q "Up"; then
        print_warning "MariaDB no está corriendo, levantando contenedor..."
        docker-compose up -d mariadb
        sleep 10
    fi
    print_success "MariaDB está corriendo"
}

confirm_reset() {
    print_header "Confirmación"

    echo -e "${YELLOW}⚠️  ADVERTENCIA:${NC}"
    echo -e "Esta operación eliminará TODOS los datos actuales de la base de datos"
    echo -e "local y los reemplazará con los datos del backup:"
    echo -e ""
    echo -e "  Backup: ${GREEN}$(basename $BACKUP_FILE)${NC}"
    echo -e "  Base de datos: ${RED}moodle_dev${NC}"
    echo -e ""
    echo -e "${YELLOW}Esta acción NO se puede deshacer.${NC}"
    echo -e ""
    read -p "¿Estás seguro que deseas continuar? (escribe 'SI' para confirmar): " -r
    echo

    if [[ ! $REPLY =~ ^SI$ ]]; then
        print_info "Operación cancelada por el usuario"
        exit 0
    fi
}

create_backup_before_reset() {
    print_header "Creando Backup de Seguridad"

    print_info "Creando backup de la BD actual antes de resetear..."

    SAFETY_BACKUP="$BACKUP_DIR/moodle_dev_before_reset_$(date +%Y%m%d_%H%M%S).sql.gz"

    docker-compose exec -T mariadb mysqldump \
        -u moodle_user \
        -pmoodle_password_dev \
        moodle_dev \
        2>/dev/null | gzip > "$SAFETY_BACKUP"

    if [ $? -eq 0 ]; then
        print_success "Backup de seguridad creado: $(basename $SAFETY_BACKUP)"
    else
        print_warning "No se pudo crear backup de seguridad (la BD podría no existir aún)"
    fi
}

decompress_if_needed() {
    print_header "Preparando Backup"

    # Si el archivo está comprimido, descomprimirlo
    if [[ $BACKUP_FILE == *.gz ]]; then
        print_info "Descomprimiendo backup..."
        gunzip -f "$BACKUP_FILE"
        BACKUP_FILE="${BACKUP_FILE%.gz}"  # Remover .gz de la ruta
        print_success "Backup descomprimido: $(basename $BACKUP_FILE)"
    else
        print_info "Backup ya está descomprimido"
    fi
}

reset_database() {
    print_header "Reseteando Base de Datos"

    cd "$PROJECT_DIR"

    # Eliminar y recrear base de datos
    print_info "Eliminando base de datos actual..."
    docker-compose exec -T mariadb mysql -u root -proot_password_dev << 'EOSQL'
        DROP DATABASE IF EXISTS moodle_dev;
        CREATE DATABASE moodle_dev CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
        GRANT ALL PRIVILEGES ON moodle_dev.* TO 'moodle_user'@'%';
        GRANT ALL PRIVILEGES ON moodle_dev.* TO 'certificates_app'@'%';
        FLUSH PRIVILEGES;
EOSQL

    if [ $? -eq 0 ]; then
        print_success "Base de datos recreada"
    else
        print_error "Error al recrear base de datos"
        exit 1
    fi

    # Restaurar backup
    print_info "Restaurando backup (esto puede tardar 5-15 minutos)..."
    print_info "Archivo: $(basename $BACKUP_FILE)"

    docker-compose exec -T mariadb mysql \
        -u moodle_user \
        -pmoodle_password_dev \
        moodle_dev \
        < "$BACKUP_FILE"

    if [ $? -eq 0 ]; then
        print_success "Backup restaurado exitosamente"
    else
        print_error "Error al restaurar backup"
        exit 1
    fi

    # Verificar restauración
    TABLE_COUNT=$(docker-compose exec -T mariadb mysql \
        -u moodle_user \
        -pmoodle_password_dev \
        -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='moodle_dev';")

    print_success "Tablas restauradas: $TABLE_COUNT"
}

purge_moodle_caches() {
    print_header "Limpiando Cachés de Moodle"

    cd "$PROJECT_DIR"

    # Verificar si el contenedor de Moodle está corriendo
    if docker-compose ps moodle | grep -q "Up"; then
        print_info "Purgando cachés de Moodle..."

        # Purgar cachés desde CLI
        docker-compose exec -T moodle php admin/cli/purge_caches.php 2>/dev/null

        if [ $? -eq 0 ]; then
            print_success "Cachés de Moodle purgadas"
        else
            print_warning "No se pudieron purgar las cachés automáticamente"
            print_info "Purga manualmente desde: Administración del sitio → Desarrollo → Purgar cachés"
        fi
    else
        print_warning "Contenedor de Moodle no está corriendo"
        print_info "Levanta Moodle con: docker-compose up -d moodle"
    fi
}

print_summary() {
    print_header "Resumen"

    echo -e "${GREEN}✓ Base de datos reseteada exitosamente${NC}\n"

    echo "Información del backup restaurado:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}Archivo:${NC}          $(basename $BACKUP_FILE)"
    echo -e "${BLUE}Tamaño:${NC}           $(du -h "$BACKUP_FILE" | cut -f1)"
    echo -e "${BLUE}Tablas:${NC}           $TABLE_COUNT"
    echo ""
    echo "Próximos pasos:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "1. Abrir Moodle: http://localhost:8082"
    echo "2. Iniciar sesión con las credenciales de producción"
    echo "3. Purgar cachés si no se hizo automáticamente"
    echo "4. Verificar que todo funciona correctamente"
    echo ""
    echo -e "${YELLOW}Nota:${NC} El backup de seguridad se guardó en:"
    echo "      $BACKUP_DIR/"
    echo ""
}

###############################################################################
# Ejecución Principal
###############################################################################

main() {
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                                                               ║"
    echo "║     RESET DE BASE DE DATOS LOCAL - ACG Certificados          ║"
    echo "║                                                               ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    find_backup
    check_docker
    confirm_reset
    create_backup_before_reset
    decompress_if_needed
    reset_database
    purge_moodle_caches
    print_summary
}

# Ejecutar script
main

exit 0
