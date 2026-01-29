# ACG - Google Apps Scripts para Notificaciones

Este directorio contiene los scripts de Google Apps Script para enviar notificaciones por correo electrónico a los participantes.

## Índice

1. [Requisitos Previos](#1-requisitos-previos)
2. [Crear el Documento de Plantillas](#2-crear-el-documento-de-plantillas)
3. [Configurar Script de Certificados (Web App)](#3-configurar-script-de-certificados-web-app)
4. [Configurar Script de Bienvenida](#4-configurar-script-de-bienvenida)
5. [Verificar la Integración](#5-verificar-la-integración)
6. [Solución de Problemas](#6-solución-de-problemas)

---

## 1. Requisitos Previos

Antes de comenzar, asegúrate de tener:

- [ ] Acceso a la cuenta de Google: `cursosvirtualesacg@gmail.com`
- [ ] El sistema de gestión de certificados funcionando
- [ ] Acceso de administrador al sistema

---

## 2. Crear el Documento de Plantillas

El documento de plantillas contiene el texto de los correos electrónicos con placeholders que serán reemplazados por los datos reales.

### Paso 2.1: Crear el documento

1. Inicia sesión en Google Drive con `cursosvirtualesacg@gmail.com`
2. Crea un nuevo **Google Docs** llamado `Plantillas de Correo ACG`
3. Escribe el contenido de la plantilla de certificados:

```
Estimado(a) {{nombre}},

Nos complace informarle que ha completado satisfactoriamente el curso "{{curso}}".

Adjunto a este correo encontrará su certificado digital con número {{numero_certificado}}.

Detalles del certificado:
• Fecha de emisión: {{fecha_emision}}
• Intensidad horaria: {{intensidad}}
• Calificación obtenida: {{calificacion}}

Este certificado puede ser validado en línea ingresando el número de certificado en nuestra plataforma.

Cordialmente,

Aula Certificada Global
cursosvirtualesacg@gmail.com
```

### Paso 2.2: Obtener el ID del documento

1. Con el documento abierto, mira la URL en el navegador:
   ```
   https://docs.google.com/document/d/1aBcDeFgHiJkLmNoPqRsTuVwXyZ/edit
                                      ^^^^^^^^^^^^^^^^^^^^^^^^
                                      Este es el ID del documento
   ```
2. Copia el ID (la parte entre `/d/` y `/edit`)
3. Guárdalo, lo necesitarás para configurar los scripts

### Placeholders disponibles

| Placeholder | Descripción | Ejemplo |
|-------------|-------------|---------|
| `{{nombre}}` | Nombre completo | Juan Pérez García |
| `{{curso}}` | Nombre del curso | Gestión de Calidad ISO 9001 |
| `{{numero_certificado}}` | Número único | CV-2026-0001 |
| `{{fecha_emision}}` | Fecha formateada | 15 de enero de 2026 |
| `{{intensidad}}` | Horas del curso | 40 horas |
| `{{calificacion}}` | Nota obtenida | 4.5 |

---

## 3. Configurar Script de Certificados (Web App)

Este script recibe solicitudes del sistema de gestión y envía los certificados por email.

### Paso 3.1: Generar un API Key

Antes de crear el script, genera una clave secreta. En una terminal ejecuta:

```bash
openssl rand -hex 32
```

Esto generará algo como:
```
a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456
```

**Guarda esta clave en un lugar seguro.** La necesitarás en el script Y en el sistema de gestión.

### Paso 3.2: Crear el proyecto en Google Apps Script

1. Ve a [script.google.com](https://script.google.com) (asegúrate de estar con la cuenta `cursosvirtualesacg@gmail.com`)

2. Click en **+ Nuevo proyecto**

3. Se abrirá el editor con un archivo `Code.gs`. Borra todo su contenido.

4. Abre el archivo `certificados/Code.gs` de esta carpeta y copia TODO su contenido

5. Pega el contenido en el editor de Google Apps Script

### Paso 3.3: Configurar las variables

En la parte superior del código, busca la sección `CONFIG` y modifica:

```javascript
const CONFIG = {
  // Pega aquí el API Key que generaste en el Paso 3.1
  API_KEY: 'a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456',

  // Pega aquí el ID del documento de plantillas (Paso 2.2)
  PLANTILLAS_DOC_ID: '1aBcDeFgHiJkLmNoPqRsTuVwXyZ',

  // Nombre de la plantilla (déjalo así)
  PLANTILLA_CERTIFICADO: 'Certificado',

  // Asunto del correo (puedes personalizarlo)
  ASUNTO_CERTIFICADO: 'Tu certificado del curso {{curso}} - ACG',

  // Nombre que aparece como remitente
  NOMBRE_REMITENTE: 'ACG Cursos Virtuales',

  // Nombre del archivo PDF adjunto
  NOMBRE_ARCHIVO_PDF: 'Certificado_{{numero_certificado}}.pdf'
};
```

### Paso 3.4: Guardar el proyecto

1. Click en el ícono de guardar (💾) o presiona `Ctrl+S`
2. Te pedirá un nombre para el proyecto: escribe `ACG Certificados`

### Paso 3.5: Desplegar como Web App

1. Click en **Desplegar** (botón azul arriba a la derecha)
2. Selecciona **Nueva implementación**
3. En el diálogo que aparece:
   - Click en el ícono de engranaje ⚙️ junto a "Seleccionar tipo"
   - Selecciona **Aplicación web**
4. Configura:
   - **Descripción**: `API para envío de certificados`
   - **Ejecutar como**: `Yo (cursosvirtualesacg@gmail.com)`
   - **Quién tiene acceso**: `Cualquier persona`
5. Click en **Implementar**
6. **IMPORTANTE**: Se te pedirá autorizar permisos. Click en **Autorizar acceso**
   - Selecciona la cuenta `cursosvirtualesacg@gmail.com`
   - Si aparece "Google no ha verificado esta app", click en **Avanzado** → **Ir a ACG Certificados (no seguro)**
   - Click en **Permitir**
7. Aparecerá la **URL de la aplicación web**. Cópiala, se ve así:
   ```
   https://script.google.com/macros/s/AKfycbx1234567890abcdefghijklmnop/exec
   ```

### Paso 3.6: Configurar en el Sistema de Gestión

1. Abre el sistema de gestión de certificados en tu navegador
2. Ve a **Configuración** en el menú lateral
3. En la sección **Google Apps Script**:
   - Activa el toggle **Habilitar integración GAS**
   - En **URL del Webhook**: pega la URL del Paso 3.5
   - En **API Key**: pega la misma clave que pusiste en el script (Paso 3.1)
4. Click en **Guardar configuración**

---

## 4. Configurar Script de Bienvenida

Este script se ejecuta desde una hoja de cálculo de Google para enviar correos de bienvenida.

### Paso 4.1: Crear la hoja de cálculo

1. En Google Drive, crea una nueva **Hoja de cálculo de Google**
2. Nombra la hoja: `Matriculados ACG`
3. En la primera fila, crea los encabezados:

| A | B | C | D | E | F | G | H | I | J | K | L | M | N | O |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Nombres | Apellidos | Usuario | Contraseña | Email | Institución | Ciudad | País | Curso | Fecha inicio | Período | Cohorte | Documento | Fecha notificación | Estado |

### Paso 4.2: Agregar el script a la hoja

1. Con la hoja de cálculo abierta, ve a **Extensiones** → **Apps Script**
2. Se abrirá el editor de Apps Script
3. Borra el contenido de `Code.gs`
4. Copia TODO el contenido de `bienvenida/Code.gs` y pégalo
5. Configura las variables en `CONFIG`:

```javascript
const CONFIG = {
  // ID del documento de plantillas (el mismo del Paso 2.2)
  PLANTILLAS_DOC_ID: '1aBcDeFgHiJkLmNoPqRsTuVwXyZ',

  // ... resto de la configuración
};
```

6. Guarda el proyecto (`Ctrl+S`)

### Paso 4.3: Autorizar el script

1. En el editor, selecciona la función `onOpen` del menú desplegable
2. Click en **Ejecutar** (▶️)
3. Autoriza los permisos cuando se soliciten (igual que en el Paso 3.5)

### Paso 4.4: Usar el script

1. Cierra la hoja de cálculo y vuélvela a abrir
2. Aparecerá un nuevo menú: **ACG Notificaciones**
3. Para enviar correos de bienvenida:
   - Pega los datos del CSV de Moodle en la hoja
   - Asegúrate de que la columna O (Estado) diga "Pendiente" o esté vacía
   - Click en **ACG Notificaciones** → **Enviar bienvenidas pendientes**

---

## 5. Verificar la Integración

### Probar el Script de Certificados

1. En el sistema de gestión, ve a **Notificaciones**
2. Selecciona un certificado de prueba
3. Click en **Enviar Notificaciones**
4. Verifica:
   - El sistema debe mostrar "Enviado exitosamente"
   - El participante debe recibir el correo con el PDF adjunto

### Probar desde Apps Script

1. En el editor del script de certificados, busca la función `testEnvio`
2. Modifica el email de prueba:
   ```javascript
   email: 'tu-email-de-prueba@gmail.com',
   ```
3. Click en **Ejecutar**
4. Revisa tu correo

---

## 6. Solución de Problemas

### "Google Apps Script no está configurado"

- Verifica que la URL del Webhook esté correctamente copiada en Configuración
- Verifica que el API Key sea exactamente igual en ambos lados (sin espacios extra)
- Asegúrate de que el toggle "Habilitar integración GAS" esté activado

### "API key inválido"

- El API Key del sistema no coincide con el del script
- Verifica que no haya espacios al inicio o final de la clave
- Genera una nueva clave y actualízala en ambos lugares

### "No se encontró el archivo PDF"

- El certificado no tiene un PDF generado
- Regenera el certificado desde **Certificados Generados**

### El correo no llega

1. Revisa la carpeta de spam del destinatario
2. En Apps Script, ve a **Ver** → **Registros de ejecución** para ver errores
3. Verifica que no hayas superado el límite diario de correos (100 para cuentas gratuitas)

### Error al desplegar "No tienes permiso"

- Asegúrate de estar en la cuenta correcta (`cursosvirtualesacg@gmail.com`)
- Intenta cerrar sesión de otras cuentas de Google

### El menú no aparece en la hoja de cálculo

1. Cierra completamente la hoja y vuélvela a abrir
2. Espera unos segundos a que cargue el menú
3. Si no aparece, ve a **Extensiones** → **Apps Script** y ejecuta `onOpen` manualmente

---

## Límites de Google Apps Script

| Recurso | Cuenta gratuita | Google Workspace |
|---------|-----------------|------------------|
| Correos por día | 100 | 1,500 |
| Tiempo de ejecución | 6 minutos | 6 minutos |
| Tamaño de adjuntos | 25 MB | 25 MB |

Para envíos masivos grandes, el sistema divide automáticamente en lotes.

---

## Archivos en este directorio

```
gas-scripts/
├── bienvenida/
│   └── Code.gs          # Script para correos de bienvenida (Spreadsheet)
├── certificados/
│   └── Code.gs          # Web App para envío de certificados
└── README.md            # Esta documentación
```

---

## Actualizar el Script

Si necesitas actualizar el código del script:

1. Ve a [script.google.com](https://script.google.com)
2. Abre el proyecto correspondiente
3. Reemplaza el código
4. Guarda
5. Para el script de certificados: **Desplegar** → **Administrar implementaciones** → **Editar** (lápiz) → **Nueva versión** → **Implementar**

**IMPORTANTE**: Después de actualizar, la URL del Web App permanece igual. No necesitas cambiarla en el sistema.
