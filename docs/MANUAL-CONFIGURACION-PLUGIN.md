# Manual de Configuración del Plugin Certificados SSO
## Ambiente de Producción - ACG Calidad

**Versión del Manual:** 1.0
**Fecha:** 2026-01-09
**Aplicable a:** Moodle 5.1 (Producción)
**Audiencia:** Administrador o gestor con conocimientos básicos en Moodle

---

## 📋 Tabla de Contenidos

1. [Antes de Comenzar](#antes-de-comenzar)
2. [Paso 1: Habilitar Web Services](#paso-1-habilitar-web-services)
3. [Paso 2: Configurar el Servicio Web](#paso-2-configurar-el-servicio-web)
4. [Paso 3: Crear Token para el Backend](#paso-3-crear-token-para-el-backend)
5. [Paso 4: Configurar URLs del Plugin](#paso-4-configurar-urls-del-plugin)
6. [Paso 5: Verificar Instalación](#paso-5-verificar-instalación)
7. [Solución de Problemas](#solución-de-problemas)

---

## Antes de Comenzar

### ¿Qué necesita tener listo?

Antes de seguir este manual, asegúrese de que:

- ✅ El plugin **ya está instalado** en Moodle (aparece en la lista de plugins locales)
- ✅ Tiene acceso administrativo a Moodle (usuario: `adminav` o equivalente)
- ✅ Tiene un navegador web actualizado (Chrome, Firefox, Safari o Edge)
- ✅ Tiene conexión a Internet estable

### ¿El plugin no está instalado todavía?

Si el plugin NO está instalado, solicite al desarrollador que lo instale primero. El desarrollador:
1. Subirá los archivos del plugin al servidor
2. Ejecutará la instalación desde la interfaz de Moodle
3. Le notificará cuando esté listo para que usted continúe con este manual

### Credenciales de Acceso

```
URL: https://aulavirtual.acgcalidad.co
Usuario: adminav (o su usuario administrador)
Contraseña: [Solicitar al equipo técnico]
```

---

## Paso 1: Habilitar Web Services

El plugin necesita que los **Web Services** de Moodle estén habilitados para funcionar correctamente.

### 1.1 Verificar si Web Services están habilitados

1. Inicie sesión en Moodle como administrador

2. Vaya a:
   ```
   Administración del sitio → Servidor → Servicios Web → Vista general
   ```

3. Busque la opción: **"Habilitar servicios web"**

4. Si el Estado es **Si**, puede saltar al [Paso 1.3](#13-activar-protocolo-rest)

### 1.2 Habilitar Web Services (si no están habilitados)

1. En la página de **Servidor → Servicios Web → Vista general**

2. Haga clic sobre el vínculo **Habilitar Servicios Web**

3. Desplácese hasta el final de la página

4. Haga clic en **"Guardar cambios"**

5. Espere a que aparezca el mensaje de confirmación

### 1.3 Activar protocolo REST

1. Vaya a:
   ```
   Administración del sitio → Servidor → Servicios web → Gestionar protocolos
   ```

2. En la lista de protocolos, busque: **"REST protocol"**

3. **Si tiene un ícono de ojo cerrado** 👁️‍🗨️ (deshabilitado):
   - Haga clic en el ícono del ojo para habilitarlo
   - Debería cambiar a un ojo abierto 👁️ (habilitado)

4. **Si ya tiene el ojo abierto** 👁️, el protocolo ya está habilitado

> ✅ **Punto de control:** El protocolo REST debe mostrar "Habilitado" en la columna de estado.

---

## Paso 2: Configurar el Servicio Web

Ahora debe crear un servicio web específico para el plugin de certificados.

### 2.1 Crear el servicio "ACG Certificados SSO"

1. Vaya a:
   ```
   Administración del sitio → Servidor → Servicios web → Servicios externos
   ```

2. Haga clic en el botón **"Agregar"**

3. **Complete el formulario** con la siguiente información:

   | Campo | Valor |
   |-------|-------|
   | **Nombre** | `ACG Certificados SSO` |
   | **Nombre corto** | `acg_certificados_sso` |
   | **Habilitado** | ☑️ Sí |
   | **Usuarios autorizados** | Solo usuarios autorizados |
   | **Capacidad requerida** | (dejar vacío) |
   | **Restricción de IP** | (dejar vacío) |
   | **Descargar archivos** | ☐ No |
   | **Subir archivos** | ☐ No |

4. Haga clic en **"Agregar servicio"**

### 2.2 Agregar funciones al servicio

Después de crear el servicio, debe agregarle las funciones específicas del plugin:

1. En la lista de servicios, localice **"ACG Certificados SSO"**

2. En la columna **"Funciones"**, haga clic en **"Agregar funciones"**

3. En la nueva pantalla, busque y **seleccione** las siguientes dos funciones:
   - ☑️ `local_certificados_sso_generate_token`
   - ☑️ `local_certificados_sso_validate_token`

   > **Ayuda para buscar:** Use el cuadro de búsqueda en la parte superior y escriba `certificados`

4. Después de seleccionar ambas funciones, haga clic en **"Agregar funciones"**

5. **Verificar que se agregaron:**
   - Vuelva a la lista de servicios externos
   - En **"ACG Certificados SSO"**, la columna "Funciones" debe mostrar: **"2"**

> ✅ **Punto de control:** El servicio debe estar habilitado y tener 2 funciones asignadas.

---

## Paso 3: Crear Token para el Backend

El backend de la aplicación de certificados necesita un **token permanente** para poder comunicarse con Moodle y validar los tokens SSO.

### 3.1 Crear el token

1. Vaya a:
   ```
   Administración del sitio → Servidor → Servicios web → Gestionar tokens
   ```

2. Haga clic en el botón **"Crear token"**

3. **Complete el formulario:**

   | Campo | Valor |
   |-------|-------|
   | **Usuario** | Seleccione: `adminav` (o el usuario administrador actual) |
   | **Servicio** | Seleccione: `ACG Certificados SSO` |
   | **Dirección IP válida** | (dejar vacío) |
   | **Fecha de vencimiento** | (dejar vacío - token permanente) |

4. Haga clic en **"Guardar cambios"**

### 3.2 Copiar el token generado

**⚠️ IMPORTANTE:** Esta es la única vez que verá el token completo.

1. Después de guardar, Moodle mostrará el token generado. Se verá algo como:
   ```
   a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6
   ```

2. **COPIE ESTE TOKEN COMPLETO** y guárdelo en un lugar seguro:
   - Puede copiarlo y pegarlo en un documento de texto
   - O anotarlo en papel
   - O enviárselo al desarrollador por email

3. **Importante:** Este token es como una contraseña. No lo comparta públicamente.

> 📋 **Acción requerida:** Envíe este token al desarrollador para que lo configure en el backend.

---

## Paso 4: Configurar URLs del Plugin

Ahora debe configurar las URLs donde estará disponible la aplicación de certificados.

### 4.1 Acceder a configuración del plugin

1. Vaya a:
   ```
   Administración del sitio → Extensiones → Extensiones locales → Certificados SSO
   ```

2. Verá un formulario con varias opciones de configuración

### 4.2 Configurar las URLs

Complete los campos con los siguientes valores:

#### URL de la aplicación (producción)
```
https://aulavirtual.acgcalidad.co/certificados/
```
> Esta será la URL final cuando la aplicación esté en producción.

#### URL de desarrollo
```
http://localhost:4200/
```
> Esta URL se usa automáticamente cuando Moodle está en modo debug.

#### Tiempo de expiración del token (segundos)
```
300
```
> Los tokens SSO expiran después de 5 minutos (300 segundos).

#### Modo debug

**Para ambiente de pruebas (Green/Staging):**
- ☑️ **Activar**

**Para ambiente de producción:**
- ☐ **Desactivar**

### 4.3 Guardar configuración

1. Revise que todos los valores estén correctos

2. Desplácese hasta el final de la página

3. Haga clic en **"Guardar cambios"**

4. Espere el mensaje de confirmación: **"Cambios guardados"**

> ✅ **Punto de control:** La configuración debe guardarse sin errores.

---

## Paso 5: Verificar Instalación

Ahora vamos a verificar que el plugin está funcionando correctamente.

### 5.1 Limpiar cachés de Moodle

Es importante limpiar las cachés para que Moodle reconozca todos los cambios:

1. Vaya a:
   ```
   Administración del sitio → Desarrollo → Purgar todas las cachés
   ```

2. Haga clic en el botón **"Purgar todas las cachés"**

3. Espere a que aparezca el mensaje de confirmación

### 5.2 Verificar enlace en la navegación

1. **Cierre sesión** de Moodle:
   - Haga clic en su nombre en la esquina superior derecha
   - Seleccione **"Salir"**

2. **Vuelva a iniciar sesión** como `adminav`

3. **Busque el nuevo enlace** en el menú de navegación principal:
   - Debería aparecer un enlace llamado: **"Mis Certificados"**
   - Puede estar en el menú superior o en el panel lateral

4. **⚠️ NO haga clic todavía** en "Mis Certificados" (el backend aún no está listo)

> ✅ **Punto de control:** Si ve el enlace "Mis Certificados", el plugin está correctamente configurado.

### 5.3 Verificar tarea programada

1. Vaya a:
   ```
   Administración del sitio → Servidor → Tareas programadas
   ```

2. Busque en la lista: **"Limpiar tokens SSO expirados"**

3. Verifique la información:
   - **Componente:** Plugin local: Certificados SSO
   - **Minuto:** */15 (se ejecuta cada 15 minutos)
   - **Estado:** ✅ Habilitado

4. **Probar ejecución manual (Opcional):**
   - Haga clic en el enlace **"Ejecutar ahora"** junto a la tarea
   - Debe ejecutarse sin errores
   - Mostrará: "Limpieza de tokens SSO: no hay tokens para eliminar" (normal la primera vez)

> ✅ **Punto de control:** La tarea debe estar habilitada y ejecutarse sin errores.

---

## ✅ Checklist Final de Configuración

Use esta lista para verificar que todo está correctamente configurado:

- [ ] Web Services están habilitados en Moodle
- [ ] Protocolo REST está activo
- [ ] Servicio "ACG Certificados SSO" está creado y habilitado
- [ ] Servicio tiene 2 funciones asignadas
- [ ] Token permanente creado y guardado
- [ ] Token enviado al desarrollador
- [ ] URLs configuradas en el plugin
- [ ] Modo debug configurado según ambiente (activado en staging, desactivado en producción)
- [ ] Cachés de Moodle purgadas
- [ ] Enlace "Mis Certificados" aparece en la navegación
- [ ] Tarea programada existe y está habilitada

---

## Solución de Problemas

### Problema 1: No encuentro la opción "Web Services"

**Solución:**
1. Verifique que está iniciado como administrador
2. La ruta correcta es: `Administración del sitio → Funcionalidades avanzadas`
3. Desplácese hacia abajo en la página para encontrar la opción

### Problema 2: No puedo crear el servicio web

**Mensaje de error:**
```
El nombre corto ya está en uso
```

**Solución:**
1. Ya existe un servicio con ese nombre
2. Busque en la lista de servicios externos si ya está creado
3. Si existe, use ese servicio en lugar de crear uno nuevo

### Problema 3: No encuentro las funciones para agregar al servicio

**Solución:**
1. Limpie las cachés de Moodle:
   ```
   Administración del sitio → Desarrollo → Purgar todas las cachés
   ```
2. Intente agregar las funciones nuevamente
3. Use el cuadro de búsqueda escribiendo: `local_certificados_sso`

### Problema 4: El enlace "Mis Certificados" no aparece

**Solución:**
1. Limpie las cachés: `Administración del sitio → Desarrollo → Purgar todas las cachés`
2. Cierre sesión y vuelva a iniciar sesión
3. Verifique que el plugin está habilitado en la lista de plugins locales
4. Asegúrese de estar autenticado (no como invitado)

### Problema 5: Al hacer clic en "Mis Certificados" aparece error 404

**Causa:**
- El backend de la aplicación de certificados aún no está instalado

**Solución:**
- Esto es **NORMAL** hasta que el desarrollador complete la instalación del backend
- El enlace solo funcionará cuando el backend esté completamente configurado
- No es un error del plugin de Moodle

---

## 📞 Contacto y Soporte

Si encuentra problemas durante la configuración que no se resuelven con esta guía:

**Desarrollador:** Oliver Castelblanco
**Email:** oliver@acgcalidad.co
**Soporte:** soporte@acgcalidad.co

**Información a proporcionar al solicitar soporte:**
1. Pantalla/paso donde ocurrió el problema
2. Mensaje de error completo (si hay)
3. Captura de pantalla (si es posible)
4. Versión de Moodle: 5.1
5. Ambiente: Producción / Staging

---

## 📝 Próximos Pasos

Después de completar esta configuración:

1. ✅ El desarrollador configurará el backend con el token que usted proporcionó
2. ✅ Se instalará la aplicación Angular de certificados
3. ✅ Se probará el flujo completo de SSO
4. ✅ Se le notificará cuando pueda hacer clic en "Mis Certificados"
5. ✅ Se capacitará al equipo en el uso de la nueva aplicación

---

## 🔒 Seguridad

### Buenas Prácticas

- ✅ El token permanente debe mantenerse confidencial
- ✅ No comparta el token en comunicaciones públicas
- ✅ No lo incluya en capturas de pantalla públicas
- ✅ Cámbielo periódicamente (cada 6 meses recomendado)

### Cambiar el Token (Mantenimiento)

Si necesita cambiar el token por seguridad:

1. Vaya a: `Administración del sitio → Servidor → Servicios web → Gestionar tokens`
2. Localice el token actual (busque por servicio: `ACG Certificados SSO`)
3. Haga clic en el ícono de **eliminar** (papelera) 🗑️
4. Confirme la eliminación
5. Cree un nuevo token siguiendo el [Paso 3](#paso-3-crear-token-para-el-backend)
6. Proporcione el nuevo token al desarrollador para que actualice el backend

---

## 📊 Información Técnica del Plugin

Para administradores técnicos:

| Aspecto | Detalle |
|---------|---------|
| **Nombre completo** | local_certificados_sso |
| **Tipo** | Plugin local de Moodle |
| **Versión** | 1.0.0 (2026010900) |
| **Compatibilidad** | Moodle 5.1+ |
| **PHP requerido** | 8.4+ |
| **Tabla de BD** | mdl_local_certsso_tokens |
| **Web Services** | 2 funciones (generate_token, validate_token) |
| **Tarea programada** | Limpieza cada 15 minutos |
| **Capabilities** | 3 (generatetoken, validatetoken, manage) |

---

*Manual de Configuración - Plugin Certificados SSO*
*ACG Calidad - Aula Virtual*
*Última actualización: 2026-01-09*
