#!/bin/bash
# =============================================================================
# ACG Certificados - Sincronización Blue → Green (Pre-GoLive)
# =============================================================================
# Este script sincroniza los datos de certificados de Blue a Green.
# EJECUTAR SOLO antes del go-live para asegurar datos actualizados.
#
# Uso: ./scripts/sync-blue-to-green.sh
# =============================================================================

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuración de BD
DB_HOST="acgdb.c2uujyoezwbf.us-east-1.rds.amazonaws.com"
DB_USER="root"
DB_PASS="cl4v3dbr00t!"
DB_BLUE="moodle"
DB_GREEN="moodle51"

# Directorio de trabajo
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="$PROJECT_DIR/backups/$(date +%Y%m%d)"
TIMESTAMP=$(date +%H%M%S)

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  Sincronización Blue → Green (Pre-GoLive)${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "${YELLOW}ADVERTENCIA: Este script modifica la base de datos de Green.${NC}"
echo -e "${YELLOW}Asegúrate de tener backups antes de continuar.${NC}"
echo ""
read -p "¿Continuar? (s/N): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Ss]$ ]]; then
    echo "Operación cancelada."
    exit 0
fi
echo ""

# -----------------------------------------------------------------------------
# Crear directorio de backups
# -----------------------------------------------------------------------------
echo -e "${YELLOW}[1/6] Preparando directorio de backups...${NC}"
mkdir -p "$BACKUP_DIR"
echo -e "${GREEN}  ✓ Directorio: $BACKUP_DIR${NC}"
echo ""

# -----------------------------------------------------------------------------
# Backup de Blue
# -----------------------------------------------------------------------------
echo -e "${YELLOW}[2/6] Creando backup de cc_certificados en Blue...${NC}"
BLUE_BACKUP="$BACKUP_DIR/cc_certificados_blue_$TIMESTAMP.sql"

mysqldump -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_BLUE" cc_certificados \
    > "$BLUE_BACKUP" 2>/dev/null

if [ ! -s "$BLUE_BACKUP" ]; then
    echo -e "${RED}Error: No se pudo crear backup de Blue${NC}"
    exit 1
fi

BLUE_COUNT=$(mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_BLUE" -N -e \
    "SELECT COUNT(*) FROM cc_certificados;" 2>/dev/null)

echo -e "${GREEN}  ✓ Backup creado: $BLUE_BACKUP${NC}"
echo -e "${GREEN}  ✓ Registros en Blue: $BLUE_COUNT${NC}"
echo ""

# -----------------------------------------------------------------------------
# Backup de Green (estado actual)
# -----------------------------------------------------------------------------
echo -e "${YELLOW}[3/6] Creando backup de Green (estado actual)...${NC}"

# Verificar si existen las tablas en Green
TABLES_EXIST=$(mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_GREEN" -N -e \
    "SELECT COUNT(*) FROM information_schema.tables
     WHERE table_schema='$DB_GREEN' AND table_name='cc_certificados';" 2>/dev/null)

if [ "$TABLES_EXIST" -gt 0 ]; then
    GREEN_BACKUP="$BACKUP_DIR/cc_certificados_green_$TIMESTAMP.sql"
    mysqldump -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_GREEN" cc_certificados \
        > "$GREEN_BACKUP" 2>/dev/null

    GREEN_COUNT=$(mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_GREEN" -N -e \
        "SELECT COUNT(*) FROM cc_certificados;" 2>/dev/null)

    echo -e "${GREEN}  ✓ Backup de Green creado: $GREEN_BACKUP${NC}"
    echo -e "${GREEN}  ✓ Registros actuales en Green: $GREEN_COUNT${NC}"
else
    echo -e "${YELLOW}  ⚠ No existe cc_certificados en Green (primera migración)${NC}"
fi

# Backup de legacy si existe
LEGACY_EXISTS=$(mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_GREEN" -N -e \
    "SELECT COUNT(*) FROM information_schema.tables
     WHERE table_schema='$DB_GREEN' AND table_name='cc_certificados_legacy';" 2>/dev/null)

if [ "$LEGACY_EXISTS" -gt 0 ]; then
    LEGACY_BACKUP="$BACKUP_DIR/cc_certificados_legacy_green_$TIMESTAMP.sql"
    mysqldump -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_GREEN" cc_certificados_legacy \
        > "$LEGACY_BACKUP" 2>/dev/null
    echo -e "${GREEN}  ✓ Backup de legacy creado${NC}"
fi
echo ""

# -----------------------------------------------------------------------------
# Preparar Green
# -----------------------------------------------------------------------------
echo -e "${YELLOW}[4/6] Preparando Green para recibir datos...${NC}"

mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_GREEN" 2>/dev/null << EOF
-- Renombrar tabla legacy existente (si existe)
DROP TABLE IF EXISTS cc_certificados_legacy_old;

-- Si existe legacy, guardarla como _old
SET @legacy_exists = (SELECT COUNT(*) FROM information_schema.tables
    WHERE table_schema='$DB_GREEN' AND table_name='cc_certificados_legacy');

SET @sql = IF(@legacy_exists > 0,
    'RENAME TABLE cc_certificados_legacy TO cc_certificados_legacy_old',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Mostrar estado
SELECT 'Preparación completada' as status;
EOF

echo -e "${GREEN}  ✓ Green preparada${NC}"
echo ""

# -----------------------------------------------------------------------------
# Importar datos de Blue
# -----------------------------------------------------------------------------
echo -e "${YELLOW}[5/6] Importando datos de Blue a Green...${NC}"

# Importar el backup de Blue
mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_GREEN" < "$BLUE_BACKUP" 2>/dev/null

# Renombrar a legacy
mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_GREEN" -e \
    "RENAME TABLE cc_certificados TO cc_certificados_legacy;" 2>/dev/null

IMPORTED_COUNT=$(mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_GREEN" -N -e \
    "SELECT COUNT(*) FROM cc_certificados_legacy;" 2>/dev/null)

echo -e "${GREEN}  ✓ Datos importados como cc_certificados_legacy${NC}"
echo -e "${GREEN}  ✓ Registros importados: $IMPORTED_COUNT${NC}"
echo ""

# -----------------------------------------------------------------------------
# Ejecutar migración
# -----------------------------------------------------------------------------
echo -e "${YELLOW}[6/6] Ejecutando migración de datos legacy...${NC}"

# Verificar que existe el script de migración
MIGRATION_SCRIPT="$PROJECT_DIR/backend/scripts/migrations/002_migrate_legacy_data.sql"
if [ ! -f "$MIGRATION_SCRIPT" ]; then
    echo -e "${RED}Error: No se encontró script de migración: $MIGRATION_SCRIPT${NC}"
    exit 1
fi

# Primero, asegurar que existe la tabla cc_certificados (nueva estructura)
CREATE_TABLES="$PROJECT_DIR/backend/scripts/migrations/001_create_tables.sql"
if [ -f "$CREATE_TABLES" ]; then
    echo "  Verificando/creando tablas..."
    mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_GREEN" < "$CREATE_TABLES" 2>/dev/null || true
fi

# Ejecutar migración
echo "  Migrando datos..."
mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_GREEN" < "$MIGRATION_SCRIPT" 2>/dev/null

# Verificar resultado
MIGRATED_COUNT=$(mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_GREEN" -N -e \
    "SELECT COUNT(*) FROM cc_certificados WHERE migrated_from_legacy = 1;" 2>/dev/null)

echo -e "${GREEN}  ✓ Migración completada${NC}"
echo -e "${GREEN}  ✓ Registros migrados: $MIGRATED_COUNT${NC}"
echo ""

# -----------------------------------------------------------------------------
# Resumen
# -----------------------------------------------------------------------------
echo -e "${BLUE}================================================${NC}"
echo -e "${GREEN}  SINCRONIZACIÓN COMPLETADA${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo "  Resumen:"
echo "    - Registros en Blue:        $BLUE_COUNT"
echo "    - Registros importados:     $IMPORTED_COUNT"
echo "    - Registros migrados:       $MIGRATED_COUNT"
echo ""
echo "  Backups guardados en:"
echo "    $BACKUP_DIR/"
echo ""
echo "  Verificación recomendada:"
echo "    mysql -h $DB_HOST -u $DB_USER -p$DB_PASS $DB_GREEN"
echo "    SELECT COUNT(*) FROM cc_certificados;"
echo "    SELECT COUNT(*) FROM cc_certificados_legacy;"
echo ""

# Verificar diferencia
if [ "$MIGRATED_COUNT" -lt "$IMPORTED_COUNT" ]; then
    DIFF=$((IMPORTED_COUNT - MIGRATED_COUNT))
    echo -e "${YELLOW}  NOTA: $DIFF registros no se migraron (usuarios/cursos eliminados)${NC}"
fi

echo ""
echo -e "${GREEN}Sincronización exitosa. Green está lista para go-live.${NC}"
