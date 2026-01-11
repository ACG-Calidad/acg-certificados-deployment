# ACG Gestor de Certificados

Sistema completo de gestión de certificados para ACG Calidad, integrado con Moodle 5.1.

## 📦 Componentes del Proyecto

Este proyecto está compuesto por tres repositorios independientes:

### 1. Frontend (Angular 21)
**Repositorio:** [acg-certificados-frontend](https://github.com/ACG-Calidad/acg-certificados-frontend)
- Aplicación web en Angular 21 + Angular Material
- Interfaz responsiva para gestores y participantes
- Autenticación SSO desde Moodle
- Dashboard de estadísticas y reportes

**Ubicación:** `./frontend/acg-certificados-frontend/`

### 2. Backend (PHP 8.4)
**Repositorio:** [acg-certificados-backend](https://github.com/ACG-Calidad/acg-certificados-backend)
- API REST en PHP 8.4
- Generación de PDFs con FPDF + FPDI
- Integración con Moodle Web Services
- Integración con Google Apps Script para emails

**Ubicación:** `./backend/`

### 3. Plugin Moodle SSO
**Repositorio:** [moodle-local_certificados_sso](https://github.com/ACG-Calidad/moodle-local_certificados_sso)
- Plugin local de Moodle para Single Sign-On
- Generación de tokens temporales
- Web Services para validación
- Enlace automático en navegación de Moodle

**Ubicación:** `./moodle-plugin/`

---

## 🚀 Inicio Rápido

### Prerrequisitos
- Docker & Docker Compose
- Node.js 20+ (para Angular)
- PHP 8.4.14
- Composer
- Angular CLI 21
- Acceso a servidor Moodle 5.1
- Acceso a base de datos MariaDB 10.11.15

### Instalación Local con Docker

#### 1. Clonar el repositorio principal
```bash
git clone https://github.com/ACG-Calidad/moodle-local_certificados_sso.git acg-gestor-certificados
cd acg-gestor-certificados
```

#### 2. Iniciar servicios Docker
```bash
docker-compose up -d
```

Esto levanta:
- **Moodle:** http://localhost:8082
- **Backend API:** http://localhost:8080
- **phpMyAdmin:** http://localhost:8081
- **Frontend:** http://localhost:4200

#### 3. Configurar Moodle

Seguir el manual de configuración:
- [SETUP-LOCAL-MOODLE.md](./docs/SETUP-LOCAL-MOODLE.md) - Setup completo del ambiente local
- [MANUAL-CONFIGURACION-PLUGIN.md](./docs/MANUAL-CONFIGURACION-PLUGIN.md) - Configuración del plugin SSO

---

## 📚 Documentación

### Manuales de Configuración
- [Setup Local Moodle](./docs/SETUP-LOCAL-MOODLE.md) - Instalación completa del ambiente de desarrollo
- [Manual de Configuración del Plugin](./docs/MANUAL-CONFIGURACION-PLUGIN.md) - Configuración paso a paso del plugin SSO

### Sesiones de Trabajo
- [Sesión 2026-01-08](./docs/SESION-2026-01-08.md) - Diseño inicial y arquitectura
- [Sesión 2026-01-09](./docs/SESION-2026-01-09.md) - Configuración Docker y clonado de Green
- [Sesión 2026-01-10](./docs/SESION-2026-01-10.md) - Configuración final del plugin

### Documentación Técnica Completa
En el repositorio de actualización:
- Diseño Técnico
- Arquitectura de Base de Datos
- Especificación de API
- Diseño de Interfaz
- Plan de Trabajo

---

## 🏗️ Arquitectura

```
┌─────────────────────────────────────────────────────────────────┐
│                     FRONTEND (Angular 21)                       │
│  • Dashboard de gestor/participante                             │
│  • Listado y descarga de certificados                           │
│  • Validación pública                                            │
└─────────────────────────────────────────────────────────────────┘
                              ↓ ↑ (HTTP REST)
┌─────────────────────────────────────────────────────────────────┐
│                      BACKEND (PHP 8.4)                          │
│  • API REST (19 endpoints)                                       │
│  • Generación de PDFs                                            │
│  • Lógica de negocio                                             │
└─────────────────────────────────────────────────────────────────┘
         ↓ ↑                   ↓ ↑                    ↓ ↑
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────┐
│  Moodle 5.1     │  │  MariaDB        │  │  Google Apps Script │
│  + Plugin SSO   │  │  10.11.15       │  │  (Emails con PDF)   │
└─────────────────┘  └─────────────────┘  └─────────────────────┘
```

---

## 🔑 Características Principales

### Plugin Moodle SSO
- ✅ **Generación de tokens temporales** con TTL de 5 minutos
- ✅ **Validación de tokens** vía Web Services REST
- ✅ **Enlace en navegación principal** de Moodle (compatible con Boost Union)
- ✅ **Limpieza automática** de tokens expirados (tarea programada cada 15 min)
- ✅ **Tokens de uso único** (se eliminan después de validar)
- ✅ **Auditoría completa** de generación y uso de tokens

### Para Gestores
- ✅ Dashboard con estadísticas en tiempo real
- ✅ Detección automática de usuarios aprobados
- ✅ Aprobación masiva de certificados
- ✅ Generación de PDFs en lote
- ✅ Envío de notificaciones por email
- ✅ Reportes exportables (CSV, Excel)
- ✅ Gestión de plantillas

### Para Participantes
- ✅ Acceso directo desde Moodle (SSO)
- ✅ Listado de todos sus certificados
- ✅ Descarga de PDFs
- ✅ Historial de certificados

### Validación Pública
- ✅ Verificación de autenticidad sin login
- ✅ Búsqueda por ID de certificado
- ✅ Información completa del certificado

---

## 🔐 Seguridad

- **Autenticación:** JWT + SSO desde Moodle
- **Autorización:** Role-based (Admin/Gestor/Participante)
- **Tokens SSO:** Aleatorios seguros (random_bytes + SHA-256)
- **TTL:** 5 minutos para tokens SSO
- **Uso único:** Tokens se invalidan después de usar
- **Validación:** Prevención de SQL injection y XSS
- **Rate Limiting:** Por endpoint
- **HTTPS:** Obligatorio en producción

---

## 📊 Estado del Proyecto

**Fase actual:** Desarrollo - Configuración Completa

### ✅ Completado
- [x] Ambiente Docker local funcional
- [x] Moodle 5.1 clonado y configurado
- [x] Plugin SSO instalado y configurado
- [x] Web Services habilitados
- [x] Enlace "Mis Certificados" funcional
- [x] Documentación completa

### 🔄 En Progreso
- [ ] Backend API (próxima sesión)
- [ ] Frontend Angular
- [ ] Integración completa

---

## 🛠️ Scripts Útiles

### Clone Green to Local
Clona el ambiente de producción (Green en AWS) al ambiente local:
```bash
./scripts/clone-green-to-local.sh
```

### Reset Database
Restaura la base de datos local a un backup específico:
```bash
# Usar backup más reciente
./scripts/reset-database.sh

# Usar backup de fecha específica
./scripts/reset-database.sh 20260109
```

---

## 🧪 Testing

### Probar SSO desde Moodle
1. Ir a http://localhost:8082
2. Login como `adminav`
3. Hacer clic en "Mis Certificados" en el menú
4. Verificar que abre nueva pestaña con token en URL
5. Verificar token en base de datos: `mdl_local_certsso_tokens`

### Probar Web Service de Validación
```bash
# Reemplazar TOKEN_GENERADO con un token real de la URL
curl "http://localhost:8082/webservice/rest/server.php?wstoken=YOUR_WS_TOKEN&wsfunction=local_certificados_sso_validate_token&moodlewsrestformat=json&token=TOKEN_GENERADO"
```

---

## 🚨 Troubleshooting

### Plugin
- **Enlace no aparece:** Purgar cachés (`Administración del sitio → Desarrollo → Purgar todas las cachés`)
- **Token inválido:** Verificar que no haya expirado (5 min) o ya usado
- **Web service error:** Verificar que Web Services y REST estén habilitados

### Docker
- **Contenedor no inicia:** `docker-compose logs [servicio]`
- **BD no conecta:** Verificar puertos en `docker-compose.yml`
- **Permisos:** `chown -R www-data:www-data moodle-files/`

---

## 👥 Equipo

**Desarrollador:** Oliver Castelblanco  
**Cliente:** ACG Calidad  
**Gestor Principal:** adminav (cursosvirtualesacg@gmail.com)

---

## 📄 Licencia

Proyecto privado - ACG Calidad © 2026

---

*Última actualización: 2026-01-10*
