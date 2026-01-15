# Flujo de Autenticación - Sistema de Certificados ACG

## Arquitectura Simplificada

El sistema NO requiere un endpoint de autenticación en el backend. La validación del token SSO se hace **directamente desde el frontend Angular al Web Service de Moodle**.

## Flujo Completo

```
┌─────────────┐         ┌──────────────┐         ┌─────────────────┐         ┌──────────────┐
│   Usuario   │         │    Moodle    │         │  Frontend       │         │   Backend    │
│             │         │   (Plugin)   │         │   Angular       │         │   PHP API    │
└──────┬──────┘         └──────┬───────┘         └────────┬────────┘         └──────┬───────┘
       │                       │                          │                         │
       │  1. Clic "Mis         │                          │                         │
       │     Certificados"     │                          │                         │
       ├──────────────────────>│                          │                         │
       │                       │                          │                         │
       │  2. Genera token SSO  │                          │                         │
       │     (64 caracteres)   │                          │                         │
       │                       │                          │                         │
       │  3. Redirect a        │                          │                         │
       │     Angular con token │                          │                         │
       │<──────────────────────┤                          │                         │
       │                       │                          │                         │
       │  4. Carga Angular     │                          │                         │
       │     (?token=xxx)      │                          │                         │
       ├────────────────────────────────────────────────> │                         │
       │                       │                          │                         │
       │                       │  5. Valida token         │                         │
       │                       │     (llamada directa)    │                         │
       │                       │<─────────────────────────┤                         │
       │                       │                          │                         │
       │                       │  6. Responde con         │                         │
       │                       │     datos del usuario    │                         │
       │                       ├─────────────────────────>│                         │
       │                       │                          │                         │
       │                       │                          │  7. Lista certificados  │
       │                       │                          │     GET /certificates/  │
       │                       │                          │     user/{userid}       │
       │                       │                          ├────────────────────────>│
       │                       │                          │                         │
       │                       │                          │  8. Retorna lista       │
       │                       │                          │<────────────────────────┤
       │                       │                          │                         │
       │  9. Muestra           │                          │                         │
       │     certificados      │                          │                         │
       │<──────────────────────────────────────────────── │                         │
       │                       │                          │                         │
       │  10. Descarga PDF     │                          │                         │
       ├────────────────────────────────────────────────> │                         │
       │                       │                          │                         │
       │                       │                          │  11. Genera/descarga    │
       │                       │                          │      GET /certificates/ │
       │                       │                          │      {id}/download      │
       │                       │                          ├────────────────────────>│
       │                       │                          │                         │
       │  12. Recibe PDF       │                          │  13. Envía PDF          │
       │<──────────────────────────────────────────────── │<────────────────────────┤
```

## Endpoints del Sistema

### Frontend → Moodle Web Service

**Validar Token SSO**
```http
GET http://localhost:8082/webservice/rest/server.php
  ?wstoken=bd327edf1c4e86ee7276600be6190ae2
  &wsfunction=local_certificados_sso_validate_token
  &moodlewsrestformat=json
  &token={TOKEN_SSO_DE_64_CHARS}
```

**Respuesta exitosa:**
```json
{
  "valid": true,
  "error": "",
  "userid": 2,
  "username": "adminav",
  "firstname": "Administrador",
  "lastname": "Aula Virtual",
  "email": "cursosvirtualesacg@gmail.com",
  "role": "admin"
}
```

**Respuesta error:**
```json
{
  "valid": false,
  "error": "Token inválido, expirado o ya utilizado",
  "userid": 0,
  "username": "",
  "firstname": "",
  "lastname": "",
  "email": "",
  "role": ""
}
```

### Frontend → Backend API

**Listar Certificados**
```http
GET http://localhost:8082/certificados/api/certificates/user/{userid}
```

**Descargar PDF**
```http
GET http://localhost:8082/certificados/api/certificates/{id}/download
```

## Ventajas de este Enfoque

1. **Simplicidad**: No duplicamos la lógica de validación de tokens
2. **Seguridad**: El backend confía en que el frontend ya validó al usuario
3. **Mantenibilidad**: Solo un punto de validación (el plugin de Moodle)
4. **Performance**: Una llamada menos en el flujo
5. **Menos complejidad**: No necesitamos manejar redirects entre backend y Moodle

## Seguridad

- Los tokens SSO son de **un solo uso** y **expiran rápidamente**
- El backend puede agregar validación adicional si es necesario (verificar que el userId existe en la BD)
- En producción, se pueden agregar headers de autenticación adicionales

## Configuración de Producción

En producción, las URLs serán:

**Moodle Web Service:**
```
https://aulavirtual.acgcalidad.co/webservice/rest/server.php
```

**Backend API:**
```
https://aulavirtual.acgcalidad.co/certificados/api/
```

**Frontend Angular:**
```
https://aulavirtual.acgcalidad.co/certificados/
```

Todo en el mismo dominio, sin problemas de CORS.
