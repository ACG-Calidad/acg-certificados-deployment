#!/bin/bash
# =============================================================================
# ACG Certificados - Script de Build para Producción
# =============================================================================
# Este script compila el frontend, prepara el backend y crea un paquete ZIP
# listo para desplegar en Green.
#
# Uso: ./scripts/build-production.sh
# =============================================================================

set -e  # Salir si hay error

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Directorio base del proyecto
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
FRONTEND_DIR="$PROJECT_DIR/frontend"
BACKEND_DIR="$PROJECT_DIR/backend"

# Fecha para el nombre del paquete
DATE_STAMP=$(date +%Y%m%d_%H%M%S)
DEPLOY_DIR="/tmp/certificados-deploy-$DATE_STAMP"
ZIP_FILE="/tmp/certificados-deploy-$DATE_STAMP.zip"

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  ACG Certificados - Build de Producción${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# -----------------------------------------------------------------------------
# Función: Verificar prerrequisitos
# -----------------------------------------------------------------------------
check_prerequisites() {
    echo -e "${YELLOW}[1/6] Verificando prerrequisitos...${NC}"

    # Node.js
    if ! command -v node &> /dev/null; then
        echo -e "${RED}Error: Node.js no está instalado${NC}"
        exit 1
    fi
    NODE_VERSION=$(node --version)
    echo "  Node.js: $NODE_VERSION"

    # npm
    if ! command -v npm &> /dev/null; then
        echo -e "${RED}Error: npm no está instalado${NC}"
        exit 1
    fi
    NPM_VERSION=$(npm --version)
    echo "  npm: $NPM_VERSION"

    # Angular CLI
    if ! command -v ng &> /dev/null; then
        echo -e "${RED}Error: Angular CLI no está instalado${NC}"
        echo "  Instalar con: npm install -g @angular/cli"
        exit 1
    fi
    NG_VERSION=$(ng version 2>/dev/null | grep "Angular CLI" | awk '{print $3}' || echo "unknown")
    echo "  Angular CLI: $NG_VERSION"

    # PHP
    if ! command -v php &> /dev/null; then
        echo -e "${RED}Error: PHP no está instalado${NC}"
        exit 1
    fi
    PHP_VERSION=$(php --version | head -n 1 | awk '{print $2}')
    echo "  PHP: $PHP_VERSION"

    # Composer
    if ! command -v composer &> /dev/null; then
        echo -e "${RED}Error: Composer no está instalado${NC}"
        exit 1
    fi
    COMPOSER_VERSION=$(composer --version | awk '{print $3}')
    echo "  Composer: $COMPOSER_VERSION"

    echo -e "${GREEN}  ✓ Prerrequisitos OK${NC}"
    echo ""
}

# -----------------------------------------------------------------------------
# Función: Build del Frontend
# -----------------------------------------------------------------------------
build_frontend() {
    echo -e "${YELLOW}[2/6] Compilando Frontend Angular...${NC}"

    cd "$FRONTEND_DIR"

    # Instalar dependencias si no existen
    if [ ! -d "node_modules" ]; then
        echo "  Instalando dependencias npm..."
        npm install --silent
    fi

    # Build de producción
    echo "  Ejecutando ng build..."
    ng build --configuration=production --base-href=/certificados/

    # Verificar que se creó
    if [ ! -d "dist/acg-certificados-frontend/browser" ]; then
        echo -e "${RED}Error: No se generó el build del frontend${NC}"
        exit 1
    fi

    FRONTEND_SIZE=$(du -sh dist/acg-certificados-frontend/browser | awk '{print $1}')
    echo -e "${GREEN}  ✓ Frontend compilado ($FRONTEND_SIZE)${NC}"
    echo ""
}

# -----------------------------------------------------------------------------
# Función: Preparar Backend
# -----------------------------------------------------------------------------
prepare_backend() {
    echo -e "${YELLOW}[3/6] Preparando Backend PHP...${NC}"

    cd "$BACKEND_DIR"

    # Instalar dependencias de Composer (solo producción)
    echo "  Instalando dependencias de Composer..."
    composer install --no-dev --optimize-autoloader --quiet

    # Verificar que se instalaron
    if [ ! -f "vendor/autoload.php" ]; then
        echo -e "${RED}Error: Composer no instaló las dependencias${NC}"
        exit 1
    fi

    VENDOR_SIZE=$(du -sh vendor | awk '{print $1}')
    echo -e "${GREEN}  ✓ Dependencias instaladas ($VENDOR_SIZE)${NC}"
    echo ""
}

# -----------------------------------------------------------------------------
# Función: Crear estructura de despliegue
# -----------------------------------------------------------------------------
create_deploy_structure() {
    echo -e "${YELLOW}[4/6] Creando estructura de despliegue...${NC}"

    # Limpiar si existe
    rm -rf "$DEPLOY_DIR"
    mkdir -p "$DEPLOY_DIR"

    # ----- Frontend -----
    echo "  Copiando frontend..."
    cp -r "$FRONTEND_DIR/dist/acg-certificados-frontend/browser/"* "$DEPLOY_DIR/"

    # ----- Backend (API) -----
    echo "  Copiando backend..."
    mkdir -p "$DEPLOY_DIR/api"
    cp "$BACKEND_DIR/public/index.php" "$DEPLOY_DIR/api/"

    # .htaccess para API
    cat > "$DEPLOY_DIR/api/.htaccess" << 'HTACCESS'
# API Rewrite Rules
<IfModule mod_rewrite.c>
    RewriteEngine On
    RewriteBase /certificados/api/

    # Handle OPTIONS (CORS preflight)
    RewriteCond %{REQUEST_METHOD} OPTIONS
    RewriteRule ^(.*)$ index.php [QSA,L]

    # Redirect all to index.php
    RewriteCond %{REQUEST_FILENAME} !-f
    RewriteCond %{REQUEST_FILENAME} !-d
    RewriteRule ^(.*)$ index.php [QSA,L]
</IfModule>

# CORS Headers
<IfModule mod_headers.c>
    Header always set Access-Control-Allow-Origin "https://aulavirtual.acgcalidad.co"
    Header always set Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS"
    Header always set Access-Control-Allow-Headers "Content-Type, Authorization"
    Header always set Access-Control-Allow-Credentials "true"
</IfModule>
HTACCESS

    # ----- Directorios del backend -----
    echo "  Copiando configuración y librerías..."
    cp -r "$BACKEND_DIR/config" "$DEPLOY_DIR/"
    cp -r "$BACKEND_DIR/lib" "$DEPLOY_DIR/"
    cp -r "$BACKEND_DIR/vendor" "$DEPLOY_DIR/"

    # ----- Storage -----
    echo "  Creando estructura de storage..."
    mkdir -p "$DEPLOY_DIR/storage/pdfs"
    mkdir -p "$DEPLOY_DIR/storage/templates"
    mkdir -p "$DEPLOY_DIR/storage/temp"
    mkdir -p "$DEPLOY_DIR/storage/logs"

    # ----- Scripts de migración -----
    echo "  Copiando scripts de migración..."
    mkdir -p "$DEPLOY_DIR/scripts"
    cp -r "$BACKEND_DIR/scripts/migrations" "$DEPLOY_DIR/scripts/"

    # ----- Archivos de protección -----
    echo "  Creando archivos de protección..."
    echo "Deny from all" > "$DEPLOY_DIR/config/.htaccess"
    echo "Deny from all" > "$DEPLOY_DIR/lib/.htaccess"
    echo "Deny from all" > "$DEPLOY_DIR/vendor/.htaccess"
    echo "Deny from all" > "$DEPLOY_DIR/scripts/.htaccess"
    echo "Deny from all" > "$DEPLOY_DIR/storage/.htaccess"

    # ----- .htaccess principal -----
    echo "  Creando .htaccess principal..."
    cat > "$DEPLOY_DIR/.htaccess" << 'HTACCESS'
# =============================================================================
# ACG Sistema de Certificados - Configuración Apache
# =============================================================================

<IfModule mod_rewrite.c>
    RewriteEngine On
    RewriteBase /certificados/

    # No reescribir archivos y directorios existentes
    RewriteCond %{REQUEST_FILENAME} -f [OR]
    RewriteCond %{REQUEST_FILENAME} -d
    RewriteRule ^ - [L]

    # Requests a /api/ van al backend PHP
    RewriteRule ^api/(.*)$ api/index.php [QSA,L]

    # Todo lo demás va a index.html (Angular SPA)
    RewriteRule ^ index.html [L]
</IfModule>

# Security Headers
<IfModule mod_headers.c>
    Header set X-Content-Type-Options "nosniff"
    Header set X-Frame-Options "SAMEORIGIN"
    Header set X-XSS-Protection "1; mode=block"
    Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"
</IfModule>

# Cache para assets estáticos (1 año para archivos con hash)
<IfModule mod_expires.c>
    ExpiresActive On
    ExpiresByType text/css "access plus 1 year"
    ExpiresByType application/javascript "access plus 1 year"
    ExpiresByType image/png "access plus 1 year"
    ExpiresByType image/jpeg "access plus 1 year"
    ExpiresByType image/gif "access plus 1 year"
    ExpiresByType image/svg+xml "access plus 1 year"
    ExpiresByType font/woff2 "access plus 1 year"
    ExpiresByType font/woff "access plus 1 year"
</IfModule>

# Compresión GZIP
<IfModule mod_deflate.c>
    AddOutputFilterByType DEFLATE text/html text/plain text/css
    AddOutputFilterByType DEFLATE application/javascript application/json
    AddOutputFilterByType DEFLATE image/svg+xml
</IfModule>

# Proteger archivos sensibles
<FilesMatch "^\.">
    Require all denied
</FilesMatch>

<FilesMatch "(config\.php|\.env)$">
    Require all denied
</FilesMatch>
HTACCESS

    echo -e "${GREEN}  ✓ Estructura creada${NC}"
    echo ""
}

# -----------------------------------------------------------------------------
# Función: Crear archivo ZIP
# -----------------------------------------------------------------------------
create_zip() {
    echo -e "${YELLOW}[5/6] Creando archivo ZIP...${NC}"

    cd /tmp

    # Eliminar ZIP anterior si existe
    rm -f "$ZIP_FILE"

    # Crear ZIP
    zip -r -q "$ZIP_FILE" "$(basename $DEPLOY_DIR)"

    # Verificar
    if [ ! -f "$ZIP_FILE" ]; then
        echo -e "${RED}Error: No se pudo crear el archivo ZIP${NC}"
        exit 1
    fi

    ZIP_SIZE=$(du -sh "$ZIP_FILE" | awk '{print $1}')
    echo -e "${GREEN}  ✓ ZIP creado: $ZIP_FILE ($ZIP_SIZE)${NC}"
    echo ""
}

# -----------------------------------------------------------------------------
# Función: Resumen final
# -----------------------------------------------------------------------------
show_summary() {
    echo -e "${YELLOW}[6/6] Resumen${NC}"
    echo ""
    echo -e "${BLUE}================================================${NC}"
    echo -e "${GREEN}  BUILD COMPLETADO EXITOSAMENTE${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo ""
    echo "  Archivo generado:"
    echo "    $ZIP_FILE"
    echo ""
    echo "  Contenido:"
    echo "    - Frontend Angular compilado"
    echo "    - Backend PHP con dependencias"
    echo "    - Scripts de migración SQL"
    echo "    - Archivos de configuración Apache"
    echo ""
    echo "  Próximos pasos:"
    echo "    1. Editar config/config.php con valores de producción"
    echo "    2. Subir ZIP a Green:"
    echo "       scp -i ~/.ssh/ClaveACG.pem $ZIP_FILE ec2-user@GREEN_IP:/tmp/"
    echo "    3. Seguir instrucciones en docs/DEPLOY-GREEN.md"
    echo ""
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    check_prerequisites
    build_frontend
    prepare_backend
    create_deploy_structure
    create_zip
    show_summary
}

# Ejecutar
main
