#!/bin/bash

###############################################################################
# Script: clone-green-to-local.sh
# Descripción: Clona el ambiente Moodle 5.1 de Green a Docker local
# Autor: Oliver Castelblanco
# Fecha: 2026-01-09
###############################################################################

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables
GREEN_IP="3.94.80.17"
SSH_KEY="$HOME/.ssh/ClaveACG.pem"
PROJECT_DIR="/Users/ocastelblanco/Documents/ACG/Actualizacion2026/acg-gestor-certificados"
BACKUP_DIR="$PROJECT_DIR/backups"
DATE=$(date +%Y%m%d)

# RDS Database credentials
RDS_HOST="acgdb.c9f1mlfzllkw.us-east-1.rds.amazonaws.com"
RDS_USER="moodle"
RDS_PASS="m00dl3!"
RDS_DB="moodle51"

###############################################################################
# Funciones
###############################################################################

print_header() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC}  $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC}  $1"
}

check_requirements() {
    print_header "Verificando Requisitos"

    # Verificar Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker no está instalado"
        exit 1
    fi
    print_success "Docker instalado"

    # Verificar Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose no está instalado"
        exit 1
    fi
    print_success "Docker Compose instalado"

    # Verificar clave SSH
    if [ ! -f "$SSH_KEY" ]; then
        print_error "Clave SSH no encontrada: $SSH_KEY"
        exit 1
    fi
    print_success "Clave SSH encontrada"

    # Verificar espacio en disco (necesitamos al menos 10GB)
    AVAILABLE_SPACE=$(df -g "$PROJECT_DIR" | awk 'NR==2 {print $4}')
    if [ "$AVAILABLE_SPACE" -lt 10 ]; then
        print_warning "Espacio disponible: ${AVAILABLE_SPACE}GB (se recomienda al menos 10GB)"
    else
        print_success "Espacio en disco suficiente: ${AVAILABLE_SPACE}GB"
    fi
}

create_backup_on_green() {
    print_header "Creando Backup en Green"

    print_info "Conectando a Green ($GREEN_IP)..."

    # Crear backup de base de datos
    print_info "Creando backup de base de datos..."
    ssh -i "$SSH_KEY" ec2-user@$GREEN_IP << 'ENDSSH'
        cd ~

        # Backup de base de datos
        mysqldump \
          -h acgdb.c9f1mlfzllkw.us-east-1.rds.amazonaws.com \
          -u moodleadmin \
          -pMyNewPassword123! \
          moodle51 \
          --single-transaction \
          --quick \
          --lock-tables=false \
          > moodle51_backup_$(date +%Y%m%d).sql

        # Comprimir
        gzip -f moodle51_backup_$(date +%Y%m%d).sql

        echo "✓ Backup de BD creado y comprimido"
        ls -lh moodle51_backup_*.sql.gz | tail -1
ENDSSH

    if [ $? -eq 0 ]; then
        print_success "Backup de base de datos creado en Green"
    else
        print_error "Error al crear backup de base de datos"
        exit 1
    fi

    # Crear backup de moodledata
    print_info "Creando backup de moodledata..."
    ssh -i "$SSH_KEY" ec2-user@$GREEN_IP << 'ENDSSH'
        cd ~

        # Backup de moodledata (excluir cachés y temporales)
        sudo tar -czf moodledata_backup_$(date +%Y%m%d).tar.gz \
          -C /home/datos/aulavirtual \
          --exclude='cache' \
          --exclude='localcache' \
          --exclude='sessions' \
          --exclude='temp' \
          --exclude='trashdir' \
          .

        # Cambiar permisos
        sudo chown ec2-user:ec2-user moodledata_backup_$(date +%Y%m%d).tar.gz

        echo "✓ Backup de moodledata creado"
        ls -lh moodledata_backup_*.tar.gz | tail -1
ENDSSH

    if [ $? -eq 0 ]; then
        print_success "Backup de moodledata creado en Green"
    else
        print_error "Error al crear backup de moodledata"
        exit 1
    fi
}

download_backups() {
    print_header "Descargando Backups desde Green"

    # Crear directorio de backups
    mkdir -p "$BACKUP_DIR"

    # Descargar backup de BD
    print_info "Descargando backup de base de datos..."
    scp -i "$SSH_KEY" \
        ec2-user@$GREEN_IP:~/moodle51_backup_${DATE}.sql.gz \
        "$BACKUP_DIR/"

    if [ $? -eq 0 ]; then
        print_success "Backup de BD descargado"
        ls -lh "$BACKUP_DIR/moodle51_backup_${DATE}.sql.gz"
    else
        print_error "Error al descargar backup de BD"
        exit 1
    fi

    # Descargar backup de moodledata
    print_info "Descargando backup de moodledata (esto puede tardar varios minutos)..."
    scp -i "$SSH_KEY" \
        ec2-user@$GREEN_IP:~/moodledata_backup_${DATE}.tar.gz \
        "$BACKUP_DIR/"

    if [ $? -eq 0 ]; then
        print_success "Backup de moodledata descargado"
        ls -lh "$BACKUP_DIR/moodledata_backup_${DATE}.tar.gz"
    else
        print_error "Error al descargar backup de moodledata"
        exit 1
    fi
}

clone_moodle_files() {
    print_header "Clonando Archivos de Moodle"

    print_info "Sincronizando archivos de Moodle (esto puede tardar 5-10 minutos)..."

    rsync -avz --progress \
        -e "ssh -i $SSH_KEY" \
        --exclude='moodledata/cache' \
        --exclude='moodledata/localcache' \
        --exclude='moodledata/sessions' \
        --exclude='moodledata/temp' \
        --exclude='.git' \
        --exclude='*.log' \
        ec2-user@$GREEN_IP:/var/www/html/aulavirtual/ \
        "$PROJECT_DIR/moodle-files/"

    if [ $? -eq 0 ]; then
        print_success "Archivos de Moodle clonados"
    else
        print_error "Error al clonar archivos de Moodle"
        exit 1
    fi
}

setup_docker() {
    print_header "Configurando Docker"

    cd "$PROJECT_DIR"

    # Detener contenedores si están corriendo
    print_info "Deteniendo contenedores existentes..."
    docker-compose down

    # Levantar solo MariaDB
    print_info "Levantando MariaDB..."
    docker-compose up -d mariadb

    # Esperar a que MariaDB esté listo
    print_info "Esperando a que MariaDB esté listo (30 segundos)..."
    sleep 30

    # Verificar que MariaDB está corriendo
    if docker-compose ps mariadb | grep -q "Up"; then
        print_success "MariaDB está corriendo"
    else
        print_error "MariaDB no se inició correctamente"
        docker-compose logs mariadb
        exit 1
    fi
}

restore_database() {
    print_header "Restaurando Base de Datos"

    cd "$PROJECT_DIR"

    # Descomprimir backup
    print_info "Descomprimiendo backup de BD..."
    gunzip -f "$BACKUP_DIR/moodle51_backup_${DATE}.sql.gz"

    # Crear base de datos
    print_info "Creando base de datos moodle_dev..."
    docker-compose exec -T mariadb mysql -u root -proot_password_dev << 'EOSQL'
        DROP DATABASE IF EXISTS moodle_dev;
        CREATE DATABASE moodle_dev CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
        GRANT ALL PRIVILEGES ON moodle_dev.* TO 'moodle_user'@'%' IDENTIFIED BY 'moodle_password_dev';
        GRANT ALL PRIVILEGES ON moodle_dev.* TO 'certificates_app'@'%';
        FLUSH PRIVILEGES;
EOSQL

    if [ $? -eq 0 ]; then
        print_success "Base de datos moodle_dev creada"
    else
        print_error "Error al crear base de datos"
        exit 1
    fi

    # Restaurar backup
    print_info "Restaurando backup (esto puede tardar 5-15 minutos)..."
    docker-compose exec -T mariadb mysql \
        -u moodle_user \
        -pmoodle_password_dev \
        moodle_dev \
        < "$BACKUP_DIR/moodle51_backup_${DATE}.sql"

    if [ $? -eq 0 ]; then
        print_success "Base de datos restaurada"

        # Verificar restauración
        TABLE_COUNT=$(docker-compose exec -T mariadb mysql -u moodle_user -pmoodle_password_dev -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='moodle_dev';")
        print_info "Tablas restauradas: $TABLE_COUNT"
    else
        print_error "Error al restaurar base de datos"
        exit 1
    fi
}

setup_moodledata() {
    print_header "Configurando Moodledata"

    # Crear directorio
    print_info "Creando directorio moodle-data..."
    mkdir -p "$PROJECT_DIR/moodle-data"

    # Descomprimir backup
    print_info "Descomprimiendo moodledata..."
    tar -xzf "$BACKUP_DIR/moodledata_backup_${DATE}.tar.gz" -C "$PROJECT_DIR/moodle-data/"

    if [ $? -eq 0 ]; then
        print_success "Moodledata descomprimido"
    else
        print_error "Error al descomprimir moodledata"
        exit 1
    fi

    # Establecer permisos
    print_info "Estableciendo permisos..."
    chmod -R 777 "$PROJECT_DIR/moodle-data/"

    print_success "Permisos establecidos"
}

configure_moodle() {
    print_header "Configurando Moodle Local"

    # Backup del config.php original
    if [ -f "$PROJECT_DIR/moodle-files/config.php" ]; then
        print_info "Creando backup de config.php original..."
        cp "$PROJECT_DIR/moodle-files/config.php" "$PROJECT_DIR/moodle-files/config.php.green.backup"
    fi

    # Crear nuevo config.php para local
    print_info "Creando config.php para ambiente local..."
    cat > "$PROJECT_DIR/moodle-files/config.php" << 'EOPHP'
<?php
unset($CFG);
global $CFG;
$CFG = new stdClass();

// ============================================================================
// DATABASE CONFIGURATION - Docker Local
// ============================================================================
$CFG->dbtype    = 'mariadb';
$CFG->dblibrary = 'native';
$CFG->dbhost    = 'mariadb';
$CFG->dbname    = 'moodle_dev';
$CFG->dbuser    = 'moodle_user';
$CFG->dbpass    = 'moodle_password_dev';
$CFG->prefix    = 'mdl_';
$CFG->dboptions = array(
    'dbpersist' => false,
    'dbsocket'  => false,
    'dbport'    => '3306',
    'dbcollation' => 'utf8mb4_unicode_ci',
);

// ============================================================================
// WEB CONFIGURATION - Local
// ============================================================================
$CFG->wwwroot   = 'http://localhost:8082';

// ============================================================================
// DATA DIRECTORY
// ============================================================================
$CFG->dataroot  = '/var/www/moodledata';

// ============================================================================
// ADMIN DIRECTORY
// ============================================================================
$CFG->admin     = 'admin';

// ============================================================================
// DIRECTORIES
// ============================================================================
$CFG->dirroot   = '/var/www/html';
$CFG->libdir    = $CFG->dirroot . '/lib';

// ============================================================================
// DEBUG MODE (Development)
// ============================================================================
$CFG->debug = E_ALL;
$CFG->debugdisplay = 1;
@error_reporting(E_ALL);
@ini_set('display_errors', '1');

// ============================================================================
// PERFORMANCE
// ============================================================================
$CFG->cachedir = '/var/www/moodledata/cache';
$CFG->localcachedir = '/var/www/moodledata/localcache';

require_once(__DIR__ . '/lib/setup.php');

// There is no php closing tag in this file,
// it is intentional because it prevents trailing whitespace problems!
EOPHP

    print_success "config.php configurado para ambiente local"
}

start_all_services() {
    print_header "Iniciando Todos los Servicios"

    cd "$PROJECT_DIR"

    print_info "Levantando todos los servicios..."
    docker-compose up -d

    # Esperar a que todos los servicios estén listos
    print_info "Esperando a que los servicios estén listos (30 segundos)..."
    sleep 30

    # Mostrar estado de servicios
    echo ""
    docker-compose ps
    echo ""

    if docker-compose ps | grep -q "Up"; then
        print_success "Todos los servicios están corriendo"
    else
        print_error "Algunos servicios no se iniciaron correctamente"
        exit 1
    fi
}

print_summary() {
    print_header "Resumen de Instalación"

    echo -e "${GREEN}✓ Ambiente Moodle clonado exitosamente${NC}\n"

    echo "Servicios disponibles:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}Moodle Local:${NC}     http://localhost:8082"
    echo -e "${BLUE}Backend API:${NC}      http://localhost:8080"
    echo -e "${BLUE}phpMyAdmin:${NC}       http://localhost:8081"
    echo -e "${BLUE}MariaDB:${NC}          localhost:3307"
    echo ""
    echo "Credenciales de Moodle:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}Usuario:${NC}          adminav"
    echo -e "${BLUE}Contraseña:${NC}       4dm1n1str4d0rM00dl3!"
    echo ""
    echo "Próximos pasos:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "1. Abrir http://localhost:8082 en tu navegador"
    echo "2. Iniciar sesión con las credenciales de arriba"
    echo "3. Instalar plugin SSO desde la interfaz de Moodle"
    echo "4. Seguir manual: moodle-plugin/INSTALL-GREEN.md (desde Paso 3)"
    echo ""
    print_info "Ver logs: docker-compose logs -f moodle"
    print_info "Detener: docker-compose down"
    echo ""
}

###############################################################################
# Main
###############################################################################

main() {
    print_header "Clonación de Ambiente Green a Local"

    echo -e "Este script va a:"
    echo "  1. Crear backups en Green"
    echo "  2. Descargar backups a tu Mac"
    echo "  3. Clonar archivos de Moodle"
    echo "  4. Configurar Docker local"
    echo "  5. Restaurar base de datos"
    echo "  6. Configurar moodledata"
    echo "  7. Iniciar todos los servicios"
    echo ""
    echo -e "${YELLOW}Tiempo estimado: 20-30 minutos${NC}"
    echo -e "${YELLOW}Espacio requerido: ~5-10GB${NC}"
    echo ""
    read -p "¿Deseas continuar? (s/n): " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        print_info "Operación cancelada"
        exit 0
    fi

    # Ejecutar pasos
    check_requirements
    create_backup_on_green
    download_backups
    clone_moodle_files
    setup_docker
    restore_database
    setup_moodledata
    configure_moodle
    start_all_services
    print_summary
}

# Ejecutar script
main
