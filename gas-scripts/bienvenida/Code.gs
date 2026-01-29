/**
 * ACG - Script de Notificaciones de Bienvenida
 *
 * Este script envía correos de bienvenida a participantes matriculados en cursos.
 * Se ejecuta desde Google Spreadsheet y usa plantillas de Google Docs.
 *
 * Configuración requerida:
 * 1. Crear una hoja de cálculo con la estructura definida
 * 2. Crear un documento de plantillas con pestañas para cada tipo de correo
 * 3. Configurar las variables en CONFIG
 */

// ============================================================================
// CONFIGURACIÓN - MODIFICAR SEGÚN NECESIDADES
// ============================================================================
const CONFIG = {
  // ID del documento de Google Docs con las plantillas
  PLANTILLAS_DOC_ID: 'ID_DE_DOCUMENTO_PLANTILLAS',

  // Nombre de la pestaña de plantilla de bienvenida en el documento
  PLANTILLA_BIENVENIDA: 'Bienvenida',

  // Asunto del correo de bienvenida
  ASUNTO_BIENVENIDA: 'ACG le da la bienvenida al curso {{curso}}',

  // Nombre del remitente
  NOMBRE_REMITENTE: 'Grupo capacitación ACG',

  // URL base de Moodle para el enlace de acceso
  MOODLE_URL: 'https://aulavirtual.acgcalidad.co',

  // Columnas de la hoja (índices base 0)
  COLUMNAS: {
    NOMBRES: 0,           // firstname
    APELLIDOS: 1,         // lastname
    USUARIO: 2,           // username
    CONTRASENA: 3,        // password
    EMAIL: 4,             // email
    INSTITUCION: 5,       // institution
    CIUDAD: 6,            // city
    PAIS: 7,              // country
    CURSO: 8,             // course1
    FECHA_INICIO: 9,      // enroltimestart1
    PERIODO: 10,          // enrolperiod1
    COHORTE: 11,          // cohort1
    DOCUMENTO: 12,        // idnumber
    FECHA_NOTIFICACION: 13,
    ESTADO_NOTIFICACION: 14
  },

  // Fila donde inician los datos (después del encabezado)
  FILA_INICIO_DATOS: 2
};

// ============================================================================
// MENÚ PERSONALIZADO
// ============================================================================

/**
 * Crea el menú personalizado al abrir la hoja de cálculo
 */
function onOpen() {
  const ui = SpreadsheetApp.getUi();
  ui.createMenu('ACG Notificaciones')
    .addItem('Enviar bienvenidas pendientes', 'enviarBienvenidas')
    .addItem('Reenviar fallidos', 'reenviarFallidos')
    .addSeparator()
    .addItem('Configuración', 'mostrarConfiguracion')
    .addToUi();
}

// ============================================================================
// FUNCIONES PRINCIPALES
// ============================================================================

/**
 * Envía correos de bienvenida a todos los registros pendientes
 */
function enviarBienvenidas() {
  const hoja = SpreadsheetApp.getActiveSpreadsheet().getActiveSheet();
  const datos = hoja.getDataRange().getValues();
  const plantilla = obtenerPlantilla(CONFIG.PLANTILLA_BIENVENIDA);

  if (!plantilla) {
    SpreadsheetApp.getUi().alert('Error: No se pudo obtener la plantilla de bienvenida');
    return;
  }

  let enviados = 0;
  let fallidos = 0;
  const col = CONFIG.COLUMNAS;

  // Procesar desde la fila de datos (saltar encabezado)
  for (let i = CONFIG.FILA_INICIO_DATOS - 1; i < datos.length; i++) {
    const fila = datos[i];
    const estadoActual = fila[col.ESTADO_NOTIFICACION];

    // Solo procesar pendientes o vacíos
    if (estadoActual && estadoActual !== 'Pendiente') {
      continue;
    }

    const email = fila[col.EMAIL];
    if (!email || !validarEmail(email)) {
      marcarFila(hoja, i + 1, 'Fallido', 'Email inválido o vacío');
      fallidos++;
      continue;
    }

    try {
      // Preparar datos para la plantilla
      const datosPlantilla = {
        nombre: `${fila[col.NOMBRES]} ${fila[col.APELLIDOS]}`.trim(),
        nombres: fila[col.NOMBRES],
        apellidos: fila[col.APELLIDOS],
        curso: fila[col.CURSO],
        usuario: fila[col.USUARIO],
        contrasena: fila[col.CONTRASENA],
        fecha_inicio: formatearFecha(fila[col.FECHA_INICIO]),
        fecha_cierre: calcularFechaCierre(fila[col.FECHA_INICIO], fila[col.PERIODO]),
        moodle_url: CONFIG.MOODLE_URL,
        institucion: fila[col.INSTITUCION],
        documento: fila[col.DOCUMENTO]
      };

      // Generar contenido del correo
      const cuerpoHtml = reemplazarPlaceholders(plantilla.html, datosPlantilla);
      const cuerpoTexto = reemplazarPlaceholders(plantilla.texto, datosPlantilla);
      const asunto = reemplazarPlaceholders(CONFIG.ASUNTO_BIENVENIDA, datosPlantilla);

      // Enviar correo
      GmailApp.sendEmail(email, asunto, cuerpoTexto, {
        htmlBody: cuerpoHtml,
        name: CONFIG.NOMBRE_REMITENTE
      });

      marcarFila(hoja, i + 1, 'Enviado', null);
      enviados++;

      // Pausa para evitar límites de cuota
      Utilities.sleep(100);

    } catch (error) {
      marcarFila(hoja, i + 1, 'Fallido', error.message);
      fallidos++;
      Logger.log(`Error enviando a ${email}: ${error.message}`);
    }
  }

  // Mostrar resumen
  SpreadsheetApp.getUi().alert(
    `Proceso completado:\n\n` +
    `✓ Enviados: ${enviados}\n` +
    `✗ Fallidos: ${fallidos}`
  );
}

/**
 * Reenvía correos a registros con estado "Fallido"
 */
function reenviarFallidos() {
  const hoja = SpreadsheetApp.getActiveSpreadsheet().getActiveSheet();
  const datos = hoja.getDataRange().getValues();
  const col = CONFIG.COLUMNAS;

  // Marcar fallidos como pendientes para reenviar
  for (let i = CONFIG.FILA_INICIO_DATOS - 1; i < datos.length; i++) {
    if (datos[i][col.ESTADO_NOTIFICACION] === 'Fallido') {
      hoja.getRange(i + 1, col.ESTADO_NOTIFICACION + 1).setValue('Pendiente');
      hoja.getRange(i + 1, col.FECHA_NOTIFICACION + 1).setValue('');
    }
  }

  // Ejecutar envío
  enviarBienvenidas();
}

// ============================================================================
// FUNCIONES DE PLANTILLAS
// ============================================================================

/**
 * Obtiene una plantilla del documento de Google Docs
 * @param {string} nombrePestana - Nombre de la pestaña del documento
 * @returns {Object|null} Objeto con {html, texto} o null si no se encuentra
 */
function obtenerPlantilla(nombrePestana) {
  try {
    const doc = DocumentApp.openById(CONFIG.PLANTILLAS_DOC_ID);
    const body = doc.getBody();

    // Buscar la sección de la plantilla
    // El documento debe tener encabezados con el nombre de la plantilla
    const texto = body.getText();
    const html = convertirAHtml(body);

    return {
      html: html,
      texto: texto
    };
  } catch (error) {
    Logger.log(`Error obteniendo plantilla: ${error.message}`);
    return null;
  }
}

/**
 * Convierte el contenido del documento a HTML
 * @param {GoogleAppsScript.Document.Body} body - Cuerpo del documento
 * @returns {string} Contenido en HTML
 */
function convertirAHtml(body) {
  let html = '';
  const numChildren = body.getNumChildren();

  for (let i = 0; i < numChildren; i++) {
    const child = body.getChild(i);
    html += elementoAHtml(child);
  }

  return html;
}

/**
 * Convierte un elemento del documento a HTML
 * @param {GoogleAppsScript.Document.Element} elemento
 * @returns {string}
 */
function elementoAHtml(elemento) {
  const tipo = elemento.getType();

  if (tipo === DocumentApp.ElementType.PARAGRAPH) {
    const parrafo = elemento.asParagraph();
    const texto = parrafo.getText();
    if (!texto.trim()) return '<br>';

    const alineacion = parrafo.getAlignment();
    let estilo = '';
    if (alineacion === DocumentApp.HorizontalAlignment.CENTER) {
      estilo = ' style="text-align: center;"';
    } else if (alineacion === DocumentApp.HorizontalAlignment.RIGHT) {
      estilo = ' style="text-align: right;"';
    }
    Logger.log(`<p${estilo}>${textoConFormato(parrafo)}</p>`);

    return `<p${estilo}>${textoConFormato(parrafo)}</p>`;
  }

  if (tipo === DocumentApp.ElementType.LIST_ITEM) {
    const item = elemento.asListItem();
    return `<li>${textoConFormato(item)}</li>`;
  }

  if (tipo === DocumentApp.ElementType.TABLE) {
    return tablaAHtml(elemento.asTable());
  }

  return '';
}

/**
 * Procesa texto con formato (negrita, cursiva, subrayado, tachado)
 * Usa los métodos isBold(), isItalic(), isUnderline(), isStrikethrough()
 * que son más confiables que getAttributes()
 * @param {GoogleAppsScript.Document.Paragraph|GoogleAppsScript.Document.ListItem} elemento
 * @returns {string}
 */
function textoConFormato(elemento) {
  let resultado = '';
  const textElement = elemento.editAsText();
  const texto = textElement.getText();

  if (!texto || texto.length === 0) return '';

  for (let i = 0; i < texto.length; i++) {
    const char = texto[i];

    let fragmento = char;
    // Escapar caracteres HTML
    fragmento = fragmento.replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;');

    // Usar métodos específicos para verificar formato (más confiables)
    const isBold = textElement.isBold(i);
    const isItalic = textElement.isItalic(i);
    const isUnderline = textElement.isUnderline(i);
    const isStrikethrough = textElement.isStrikethrough(i);

    if (isBold === true) {
      fragmento = `<strong>${fragmento}</strong>`;
    }
    if (isItalic === true) {
      fragmento = `<em>${fragmento}</em>`;
    }
    if (isUnderline === true) {
      fragmento = `<u>${fragmento}</u>`;
    }
    if (isStrikethrough === true) {
      fragmento = `<s>${fragmento}</s>`;
    }

    resultado += fragmento;
  }

  // Limpiar etiquetas consecutivas redundantes
  resultado = resultado.replace(/<\/strong><strong>/g, '');
  resultado = resultado.replace(/<\/em><em>/g, '');
  resultado = resultado.replace(/<\/u><u>/g, '');
  resultado = resultado.replace(/<\/s><s>/g, '');

  return resultado;
}

/**
 * Convierte una tabla a HTML
 * @param {GoogleAppsScript.Document.Table} tabla
 * @returns {string}
 */
function tablaAHtml(tabla) {
  let html = '<table border="1" cellpadding="5" cellspacing="0" style="border-collapse: collapse;">';

  for (let i = 0; i < tabla.getNumRows(); i++) {
    html += '<tr>';
    const fila = tabla.getRow(i);
    for (let j = 0; j < fila.getNumCells(); j++) {
      const celda = fila.getCell(j);
      const tag = i === 0 ? 'th' : 'td';
      html += `<${tag}>${celda.getText()}</${tag}>`;
    }
    html += '</tr>';
  }

  html += '</table>';
  return html;
}

// ============================================================================
// FUNCIONES AUXILIARES
// ============================================================================

/**
 * Reemplaza placeholders en un texto
 * @param {string} texto - Texto con placeholders {{variable}}
 * @param {Object} datos - Objeto con los valores
 * @returns {string}
 */
function reemplazarPlaceholders(texto, datos) {
  let resultado = texto;

  for (const [clave, valor] of Object.entries(datos)) {
    const placeholder = new RegExp(`\\{\\{${clave}\\}\\}`, 'gi');
    resultado = resultado.replace(placeholder, valor || '');
  }

  return resultado;
}

/**
 * Valida formato de email
 * @param {string} email
 * @returns {boolean}
 */
function validarEmail(email) {
  const regex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return regex.test(email);
}

/**
 * Formatea una fecha (timestamp o Date) a formato legible
 * @param {number|Date|string} fecha
 * @returns {string}
 */
function formatearFecha(fecha) {
  if (!fecha) return '';

  let date;
  if (typeof fecha === 'number') {
    // Unix timestamp
    date = new Date(fecha * 1000);
  } else if (fecha instanceof Date) {
    date = fecha;
  } else {
    date = new Date(fecha);
  }

  if (isNaN(date.getTime())) return '';

  const opciones = { year: 'numeric', month: 'long', day: 'numeric' };
  return date.toLocaleDateString('es-CO', opciones);
}

/**
 * Calcula la fecha de cierre sumando el período a la fecha de inicio
 * @param {number|Date|string} fechaInicio
 * @param {number} periodo - Período en días
 * @returns {string}
 */
function calcularFechaCierre(fechaInicio, periodo) {
  if (!fechaInicio || !periodo) return '';
  const periodoSegundos = periodo * 60 * 60 * 24; // Se convierte el número de días a un timestamp en segundos

  let timestamp;
  if (typeof fechaInicio === 'number') {
    timestamp = fechaInicio;
  } else if (fechaInicio instanceof Date) {
    timestamp = Math.floor(fechaInicio.getTime() / 1000);
  } else {
    timestamp = Math.floor(new Date(fechaInicio).getTime() / 1000);
  }

  const fechaCierre = new Date((timestamp + periodoSegundos) * 1000);
  const opciones = { year: 'numeric', month: 'long', day: 'numeric' };
  return fechaCierre.toLocaleDateString('es-CO', opciones);
}

/**
 * Marca una fila con el resultado del envío
 * @param {GoogleAppsScript.Spreadsheet.Sheet} hoja
 * @param {number} numFila - Número de fila (1-indexed)
 * @param {string} estado - 'Enviado' o 'Fallido'
 * @param {string|null} error - Mensaje de error si aplica
 */
function marcarFila(hoja, numFila, estado, error) {
  const col = CONFIG.COLUMNAS;
  const ahora = new Date();

  hoja.getRange(numFila, col.FECHA_NOTIFICACION + 1).setValue(ahora);
  hoja.getRange(numFila, col.ESTADO_NOTIFICACION + 1).setValue(estado);

  // Colorear según estado
  const rango = hoja.getRange(numFila, 1, 1, col.ESTADO_NOTIFICACION + 1);
  if (estado === 'Enviado') {
    rango.setBackground('#d4edda'); // Verde claro
  } else if (estado === 'Fallido') {
    rango.setBackground('#f8d7da'); // Rojo claro
    // Agregar nota con el error
    if (error) {
      hoja.getRange(numFila, col.ESTADO_NOTIFICACION + 1).setNote(error);
    }
  }
}

/**
 * Muestra la configuración actual
 */
function mostrarConfiguracion() {
  const mensaje =
    `Configuración actual:\n\n` +
    `ID Documento Plantillas: ${CONFIG.PLANTILLAS_DOC_ID}\n` +
    `Plantilla Bienvenida: ${CONFIG.PLANTILLA_BIENVENIDA}\n` +
    `URL Moodle: ${CONFIG.MOODLE_URL}\n\n` +
    `Para modificar, edita las constantes en el código.`;

  SpreadsheetApp.getUi().alert(mensaje);
}
