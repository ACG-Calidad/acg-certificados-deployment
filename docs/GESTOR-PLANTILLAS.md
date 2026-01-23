# Desarrollo de un Gestor de plantillas

## Justificación

Dentro de la aplicación **Gestor de certificados ACG Calidad** es necesario tener un **Gestor de plantillas** robusto y, sobre todo, fácil de usar. Debe ser intuitivo y _user-friendly_.

## Objetivo

Desarrollar una serie de interfaces que simplifiquen y garanticen la correcta aplicación de campos de contenido a las plantillas de certificado de los cursos virtuales de ACG Calidad.

La sección **Plantillas** de la aplicación le debe permitir obtener al sistema las variables para cada uno de los campos de contenido que se agregan como textos a las plantillas y, de tal forma, se obtienen los certificados de cada partipante.

### Variables

|Tipo de campo|Campo|Unidad|Tipo de dato|
|---|---|---|---|
|Coordenadas|Posición en X|Milímetros|`number`|
|Coordenadas|Posición en Y|Milímetros|`number`|
|Estilo|Alineación del texto|Tipo de alineación|`enum['left','right','center']`|
|Estilo|Fuente|Tipografía|`enum['arial','cinzel','norms']`|
|Estilo|Tamaño|Puntos|`enum[5,6,7,8,9,10,11,12,14,16,18,20,24,32,36,48]`|
|Estilo|Estilo|Tipo|`enum['normal','bold','italic','underline']`|

## Alcance

Se deberá modificar la interfaz actual, de tal forma que permita ubicar los campos de texto espacialmente en la plantila y aplicarles estilo.

Los campos variables de un certificado, tal como ya está definido, son:

- Primera hoja
  - Nombres y apellidos del participante
  - Documento de identidad del participante
  - Nombre largo del curso virtual
  - Intensidad del curso
  - Mes y año de generación del certificado
  - ID del certificado
- Segunda hoja
  - ID del certificado

## Flujo modelo

**Importante:** los pasos 1 a 5 son los que existen actualmente. La interfaz cambia a partir del paso 6.

1. Usuario selecciona **Plantillas** en el menú lateral.
2. Usuario selecciona **Plantilla Base** (seleccionado por defecto) o **Plantillas de Cursos** en las pestañas internas.
3. Sistema indica si se ha cargado alguna plantilla.
4. Si no se ha cargado una plantilla, el sistema permite la carga.
5. Si hay carga, el sistema indica los datos de la plantilla cargada.
6. Usuario selecciona botón **Definir campos**. Este botón es uno solo para cada pestaña, por lo que el botón **Campos** actual, por cada plantilla, es innecesario.
7. Sistema abre un diálogo que ocupa el 90% de la pantalla de ancho y alto, con las siguientes características:
   - Ancho: 90% del ancho de la pantalla.
   - Alto: 90% del alto de la pantalla.
   - Imagen de fondo estática con la plantilla.
   - Selector de curso. Si se están definiendo los campos de la **Plantilla Base** el selector de curso cambiará el valor del campo **Nombre largo del curso virtual**. Si se están definiendo los campos de la **Plantilla de Curso**, el selector cambiará la imagen de fondo con la plantilla correspondiente.
   - **Campos de contenido**: objetos arrastrables con los datos de ejemplo definidos en `./backend/lib/services/TemplateService.php` en las líneas 628 a 635.
   - Botón **Cancelar**.
   - Botón **Guardar**.
8. Usuario arrastra los **Campos de contenido** y los suelta en la ubicación que considere. Sistema obtiene punto de inserción de cada campo y determina coordenadas X e Y de cada campo.
9. Usuario oprime botón de estilos al lado izquierdo del **Campo de contenido** y sistema genera una _mini toolbar_ con los estilos permitidos:
   - Como botones _toggle_ individuales: negrita, itálica y subrayado.
   - Como botones _toogle_ grupal: alineación de texto.
   - Como desplegables: tipografías y tamaños de fuente.
10. Usuario selecciona estilos y sistema los aplica y obtiene valores.
11. Usuario oprime botón de edición al lado derecho del **Campo de contenido** y sistema permite la edición del contenido del campo, con las siguientes aclaraciones:
   - El campo **Nombre largo del curso virtual** no es editable (para eso se usa el desplegable **Selector del curso** descrito en el paso 7), pero tiene un prefijo (por defecto 'EN EL CURSO ') que **SI** puede ser editado y que, por lo tanto, debe ser almacenado por el sistema.
   - El campo **Mes y año de generación del certificado** no es editable (se usará la fecha actual como modelo), pero tiene un prefijo (por defecto 'BOGOTÁ, COLOMBIA, ') que **SI** puede ser editado y que, por lo tanto, debe ser almacenado por el sistema.
   - Los campos **ID del certificado** e **Intensidad del curso** no son editables, no tienen botón de edición al lado derecho. Por lo tanto, siempre se usarán los datos de ejemplo.
12. Usuario termina de ubicar y definir el estilo de los **Campos de contenido** y oprime el botón **Guardar**.
13. Sistema cierra el diálogo y almacena las variables de cada campo (coordenadas y estilo), así como los prefijos de los campos que los tengan, tal como se indica en el paso 11.

**Nota importante:** en el caso de la segunda hoja (plantilla de contenido de curso) el campo siempre es el mismo (**ID del certificado**) y las variables del mismo, también. Por lo tanto, en el paso 7 se abre la primera plantilla de curso disponible y el usuario podrá definir qué plantilla quiere usar como ejemplo con el desplegable definido, solo a modo de prevista. Los datos de coordenadas y estilo definidos se aplicarán a la segunda hoja de **TODOS** los certificados generados, sin importar el curso.

## Notas finales

- La tipografía 'cinzel' se refiere a [Cinzel](https://fonts.google.com/specimen/Cinzel).
- La tipografía 'norms' se refiere a [TT Norms](https://font.download/font/tt-norms).
- Se deben obtener y almacenar en la base da datos las variables indicadas en la sección [Variables](#variables) y, además, los prefijos de los campos **Nombre largo del curso virtual** y **Mes y año de generación del certificado**, tal como se indica en el paso 11 del [Flujo modelo](#flujo-modelo).
