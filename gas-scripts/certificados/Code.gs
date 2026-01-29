/**
 * ACG - Script de Notificaciones de Certificados
 *
 * Este script recibe solicitudes POST desde el sistema de gestión de certificados
 * y envía correos con el certificado PDF adjunto.
 *
 * Despliegue:
 * 1. Crear nuevo proyecto de Google Apps Script
 * 2. Copiar este código
 * 3. Configurar las variables en CONFIG
 * 4. Desplegar como Web App:
 *    - Ejecutar como: Tu cuenta (cursosvirtualesacg@gmail.com)
 *    - Acceso: Cualquier persona
 * 5. Copiar la URL del Web App y configurarla en el backend PHP
 */

// ============================================================================
// CONFIGURACIÓN - MODIFICAR SEGÚN NECESIDADES
// ============================================================================
const CONFIG = {
  // API Key para autenticación (debe coincidir con la del backend PHP)
  API_KEY: 'API_KEY_SECRETO_AQUI',

  // ID del documento de Google Docs con las plantillas
  PLANTILLAS_DOC_ID: 'ID_DE_DOCUMENTO_PLANTILLAS',

  // Nombre de la pestaña de plantilla de certificados
  PLANTILLA_CERTIFICADO: 'Certificado',

  // Asunto del correo de certificado
  ASUNTO_CERTIFICADO: 'Certificado de curso virtual {{curso}} en ACG Calidad',

  // Nombre del remitente
  NOMBRE_REMITENTE: 'Grupo capacitación ACG',

  // Nombre del archivo PDF adjunto
  NOMBRE_ARCHIVO_PDF: 'Certificado_{{numero_certificado}}.pdf'
};

// ============================================================================
// ENDPOINTS WEB APP
// ============================================================================

/**
 * Maneja solicitudes GET (para pruebas)
 */
function doGet(e) {
  return ContentService.createTextOutput(JSON.stringify({
    success: true,
    message: 'ACG Certificados API funcionando sin datos',
    timestamp: new Date().toISOString()
  })).setMimeType(ContentService.MimeType.JSON);
}

/**
 * Maneja solicitudes POST
 * @param {Object} e - Evento con parámetros de la solicitud
 */
function doPost(e) {
  try {
    // Parsear el contenido JSON
    const datos = JSON.parse(e.postData.contents);

    // Validar API Key
    if (!datos.api_key || datos.api_key !== CONFIG.API_KEY) {
      return respuestaError('API key inválido o no proporcionado', 401);
    }

    // Validar acción
    const accion = datos.action || 'send_certificate';

    switch (accion) {
      case 'send_certificate':
        return enviarCertificado(datos);

      case 'send_bulk':
        return enviarCertificadosMasivo(datos);

      case 'test':
        return respuestaExito({ message: 'Conexión exitosa' });

      default:
        return respuestaError(`Acción desconocida: ${accion}`, 400);
    }

  } catch (error) {
    Logger.log(`Error en doPost: ${error.message}`);
    return respuestaError(`Error procesando solicitud: ${error.message}`, 500);
  }
}

// ============================================================================
// FUNCIONES DE ENVÍO
// ============================================================================

/**
 * Envía un certificado individual
 * @param {Object} datos - Datos del certificado
 */
function enviarCertificado(datos) {
  // Validar campos requeridos
  const camposRequeridos = ['email', 'nombre', 'curso', 'pdf_base64', 'numero_certificado'];
  const faltantes = camposRequeridos.filter(campo => !datos[campo]);

  if (faltantes.length > 0) {
    return respuestaError(`Campos requeridos faltantes: ${faltantes.join(', ')}`, 400);
  }

  try {
    // Obtener plantilla
    const plantilla = obtenerPlantilla(CONFIG.PLANTILLA_CERTIFICADO);
    if (!plantilla) {
      return respuestaError('No se pudo obtener la plantilla de certificado', 500);
    }

    // Preparar datos para la plantilla
    const datosPlantilla = {
      nombre: datos.nombre,
      curso: datos.curso,
      numero_certificado: datos.numero_certificado,
      fecha_emision: datos.fecha_emision || formatearFechaActual(),
      intensidad: datos.intensidad || '',
      calificacion: datos.calificacion || ''
    };

    // Generar contenido del correo
    const cuerpoHtml = reemplazarPlaceholders(plantilla.html, datosPlantilla);
    const cuerpoTexto = reemplazarPlaceholders(plantilla.texto, datosPlantilla);
    const asunto = reemplazarPlaceholders(CONFIG.ASUNTO_CERTIFICADO, datosPlantilla);
    const nombreArchivo = reemplazarPlaceholders(CONFIG.NOMBRE_ARCHIVO_PDF, datosPlantilla);

    // Decodificar PDF de base64
    const pdfBlob = Utilities.newBlob(
      Utilities.base64Decode(datos.pdf_base64),
      'application/pdf',
      nombreArchivo
    );

    // Enviar correo con adjunto
    GmailApp.sendEmail(datos.email, asunto, cuerpoTexto, {
      htmlBody: cuerpoHtml,
      name: CONFIG.NOMBRE_REMITENTE,
      attachments: [pdfBlob]
    });

    Logger.log(`Certificado enviado a ${datos.email} - ${datos.numero_certificado}`);

    return respuestaExito({
      email: datos.email,
      numero_certificado: datos.numero_certificado,
      enviado_en: new Date().toISOString()
    });

  } catch (error) {
    Logger.log(`Error enviando certificado a ${datos.email}: ${error.message}`);
    return respuestaError(`Error enviando correo: ${error.message}`, 500);
  }
}

/**
 * Envía múltiples certificados
 * @param {Object} datos - Datos con array de certificados
 */
function enviarCertificadosMasivo(datos) {
  if (!datos.certificados || !Array.isArray(datos.certificados)) {
    return respuestaError('Se requiere un array de certificados', 400);
  }

  const resultados = [];
  let exitosos = 0;
  let fallidos = 0;

  for (const cert of datos.certificados) {
    try {
      // Agregar API key para reutilizar la función
      cert.api_key = datos.api_key;
      const resultado = enviarCertificadoInterno(cert);
      resultados.push({
        numero_certificado: cert.numero_certificado,
        email: cert.email,
        success: true
      });
      exitosos++;

      // Pausa entre envíos para evitar límites
      Utilities.sleep(200);

    } catch (error) {
      resultados.push({
        numero_certificado: cert.numero_certificado,
        email: cert.email,
        success: false,
        error: error.message
      });
      fallidos++;
    }
  }

  return respuestaExito({
    total: datos.certificados.length,
    exitosos: exitosos,
    fallidos: fallidos,
    detalles: resultados
  });
}

/**
 * Versión interna de enviarCertificado que lanza excepciones
 * @param {Object} datos
 */
function enviarCertificadoInterno(datos) {
  const camposRequeridos = ['email', 'nombre', 'curso', 'pdf_base64', 'numero_certificado'];
  const faltantes = camposRequeridos.filter(campo => !datos[campo]);

  if (faltantes.length > 0) {
    throw new Error(`Campos faltantes: ${faltantes.join(', ')}`);
  }

  const plantilla = obtenerPlantilla(CONFIG.PLANTILLA_CERTIFICADO);
  if (!plantilla) {
    throw new Error('No se pudo obtener la plantilla');
  }

  const datosPlantilla = {
    nombre: datos.nombre,
    curso: datos.curso,
    numero_certificado: datos.numero_certificado,
    fecha_emision: datos.fecha_emision || formatearFechaActual(),
    intensidad: datos.intensidad || '',
    calificacion: datos.calificacion || ''
  };

  const cuerpoHtml = reemplazarPlaceholders(plantilla.html, datosPlantilla);
  const cuerpoTexto = reemplazarPlaceholders(plantilla.texto, datosPlantilla);
  const asunto = reemplazarPlaceholders(CONFIG.ASUNTO_CERTIFICADO, datosPlantilla);
  const nombreArchivo = reemplazarPlaceholders(CONFIG.NOMBRE_ARCHIVO_PDF, datosPlantilla);

  const pdfBlob = Utilities.newBlob(
    Utilities.base64Decode(datos.pdf_base64),
    'application/pdf',
    nombreArchivo
  );

  GmailApp.sendEmail(datos.email, asunto, cuerpoTexto, {
    htmlBody: cuerpoHtml,
    name: CONFIG.NOMBRE_REMITENTE,
    attachments: [pdfBlob]
  });
}

// ============================================================================
// FUNCIONES DE PLANTILLAS
// ============================================================================

/**
 * Obtiene una plantilla del documento de Google Docs
 * Busca la pestaña (tab) cuyo título coincida con nombrePlantilla
 * @param {string} nombrePlantilla - Nombre de la pestaña del documento
 * @returns {Object|null} Objeto con {html, texto} o null si no se encuentra
 */
function obtenerPlantilla(nombrePlantilla) {
  try {
    const doc = DocumentApp.openById(CONFIG.PLANTILLAS_DOC_ID);
    const tabs = doc.getTabs();

    // Buscar la pestaña por nombre
    let tabEncontrada = null;
    for (const tab of tabs) {
      if (tab.getTitle() === nombrePlantilla) {
        tabEncontrada = tab;
        break;
      }
      // Buscar también en pestañas hijas (si existen)
      const childTabs = tab.getChildTabs();
      for (const childTab of childTabs) {
        if (childTab.getTitle() === nombrePlantilla) {
          tabEncontrada = childTab;
          break;
        }
      }
      if (tabEncontrada) break;
    }

    // Si no se encuentra la pestaña, usar la primera por defecto
    if (!tabEncontrada) {
      Logger.log(`Pestaña "${nombrePlantilla}" no encontrada. Usando la primera pestaña.`);
      tabEncontrada = tabs[0];
    }

    // Obtener el body de la pestaña específica
    const documentTab = tabEncontrada.asDocumentTab();
    const body = documentTab.getBody();

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
 * Formatea la fecha actual
 */
function formatearFechaActual() {
  const opciones = { year: 'numeric', month: 'long', day: 'numeric' };
  return new Date().toLocaleDateString('es-CO', opciones);
}

/**
 * Genera respuesta de éxito
 */
function respuestaExito(data) {
  return ContentService.createTextOutput(JSON.stringify({
    success: true,
    data: data,
    timestamp: new Date().toISOString()
  })).setMimeType(ContentService.MimeType.JSON);
}

/**
 * Genera respuesta de error
 */
function respuestaError(mensaje, codigo = 400) {
  return ContentService.createTextOutput(JSON.stringify({
    success: false,
    error: {
      message: mensaje,
      code: codigo
    },
    timestamp: new Date().toISOString()
  })).setMimeType(ContentService.MimeType.JSON);
}

// ============================================================================
// FUNCIONES DE PRUEBA
// ============================================================================

/**
 * Función para probar el envío localmente
 * Ejecutar desde el editor de Apps Script
 */
function testEnvio() {
  const datosPrueba = {
    api_key: CONFIG.API_KEY,
    action: 'send_certificate',
    email: 'ocastelblanco@gmail.com',
    nombre: 'Usuario de Prueba',
    curso: 'Curso de Prueba',
    numero_certificado: 'TEST-001',
    pdf_base64: '',
    fecha_emision: '15 de enero de 2026'
  };

  // Validar Base64 antes de enviar
  if (datosPrueba.pdf_base64) {
    const validacion = validarBase64(datosPrueba.pdf_base64);
    Logger.log('Validación Base64: ' + JSON.stringify(validacion));
    if (!validacion.valido) {
      Logger.log('ERROR: Base64 inválido - ' + validacion.error);
      return;
    }
  }

  // Simular el evento POST
  const e = {
    postData: {
      contents: JSON.stringify(datosPrueba)
    }
  };

  const resultado = doPost(e);
  Logger.log(resultado.getContent());
}

/**
 * Valida un string Base64 y verifica que sea un PDF válido
 * @param {string} base64String - String en Base64
 * @returns {Object} Resultado de la validación
 */
function validarBase64(base64String) {
  const resultado = {
    valido: false,
    longitudOriginal: base64String.length,
    tieneEspacios: /\s/.test(base64String),
    tieneSaltosLinea: /[\r\n]/.test(base64String),
    esBase64Valido: false,
    esPDF: false,
    tamanoDecodificado: 0,
    error: null
  };

  // Verificar caracteres inválidos
  if (resultado.tieneEspacios || resultado.tieneSaltosLinea) {
    resultado.error = 'El Base64 contiene espacios o saltos de línea. Límpialos antes de usar.';
    return resultado;
  }

  // Verificar que sea Base64 válido (solo caracteres permitidos)
  const base64Regex = /^[A-Za-z0-9+/]*={0,2}$/;
  resultado.esBase64Valido = base64Regex.test(base64String);

  if (!resultado.esBase64Valido) {
    resultado.error = 'El string contiene caracteres no válidos para Base64';
    return resultado;
  }

  try {
    // Intentar decodificar
    const decoded = Utilities.base64Decode(base64String);
    resultado.tamanoDecodificado = decoded.length;

    // Verificar que empiece con la firma PDF (%PDF)
    // Los primeros bytes deberían ser: 37, 80, 68, 70 (= %PDF)
    if (decoded.length >= 4) {
      const header = String.fromCharCode(decoded[0], decoded[1], decoded[2], decoded[3]);
      resultado.esPDF = (header === '%PDF');
    }

    if (!resultado.esPDF) {
      resultado.error = 'El archivo decodificado no parece ser un PDF válido (no empieza con %PDF)';
      return resultado;
    }

    resultado.valido = true;
  } catch (e) {
    resultado.error = 'Error al decodificar Base64: ' + e.message;
  }

  return resultado;
}

/**
 * Función de diagnóstico para probar la validación de Base64
 * Ejecutar desde el editor de Apps Script
 */
function testValidarBase64() {
  // Pegar aquí el Base64 para validar
  const base64Test = '';

  if (!base64Test) {
    Logger.log('Por favor, pega un string Base64 en la variable base64Test');
    return;
  }

  const resultado = validarBase64(base64Test);
  Logger.log('=== RESULTADO DE VALIDACIÓN ===');
  Logger.log('Longitud del string: ' + resultado.longitudOriginal + ' caracteres');
  Logger.log('Tiene espacios: ' + resultado.tieneEspacios);
  Logger.log('Tiene saltos de línea: ' + resultado.tieneSaltosLinea);
  Logger.log('Es Base64 válido: ' + resultado.esBase64Valido);
  Logger.log('Es PDF: ' + resultado.esPDF);
  Logger.log('Tamaño decodificado: ' + resultado.tamanoDecodificado + ' bytes (' + Math.round(resultado.tamanoDecodificado / 1024) + ' KB)');
  Logger.log('Válido para envío: ' + resultado.valido);
  if (resultado.error) {
    Logger.log('ERROR: ' + resultado.error);
  }
}
