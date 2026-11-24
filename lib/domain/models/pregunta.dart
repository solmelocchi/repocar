// =====================================================================
// DOMINIO: una pregunta sobre una publicación, y la respuesta del taller.
//
// Es lo que pidió Ramallo en lugar del chat: "preguntas y respuestas en
// la publicación, como Mercado Libre". Así el comprador consulta adentro
// de RepoCar, y la venta (con su comisión) no se va a WhatsApp.
// =====================================================================
class Pregunta {
  const Pregunta({
    required this.id,
    required this.piezaId,
    required this.piezaTitulo,
    required this.tallerCuit,
    required this.autor,
    required this.texto,
    required this.fecha,
    this.respuesta,
    this.fechaRespuesta,
  });

  final String id;
  final String piezaId;

  /// El título de la pieza, para mostrarlo en los avisos sin buscarla.
  final String piezaTitulo;

  /// El taller dueño de la pieza: es el único que puede responder.
  final String tallerCuit;

  /// El nombre de quien preguntó (no su mail: las preguntas son públicas).
  final String autor;
  final String texto;
  final DateTime fecha;
  final String? respuesta;
  final DateTime? fechaRespuesta;

  bool get respondida => respuesta != null;

  factory Pregunta.desdeJson(Map<String, dynamic> json) => Pregunta(
    id: json['id'] as String,
    piezaId: json['pieza_id'] as String,
    piezaTitulo: json['pieza_titulo'] as String? ?? '',
    tallerCuit: json['taller_cuit'] as String,
    autor: json['autor'] as String? ?? 'Comprador',
    texto: json['texto'] as String,
    fecha: DateTime.parse(json['fecha'] as String),
    respuesta: json['respuesta'] as String?,
    fechaRespuesta: json['respondida'] == null
        ? null
        : DateTime.parse(json['respondida'] as String),
  );

  /// La respuesta va siempre, aunque sea null: las reglas del servidor
  /// piden que una pregunta NUEVA llegue sin respuesta.
  Map<String, dynamic> aJson() => {
    'id': id,
    'pieza_id': piezaId,
    'pieza_titulo': piezaTitulo,
    'taller_cuit': tallerCuit,
    'autor': autor,
    'texto': texto,
    'fecha': fecha.toIso8601String(),
    'respuesta': respuesta,
    'respondida': fechaRespuesta?.toIso8601String(),
  };
}

/// REGLA DEL NEGOCIO: en las preguntas no se pasan datos de contacto.
///
/// Si el comprador y el taller se pasan el teléfono, arreglan por fuera y
/// la venta no deja comisión (lo que le preocupa a Ramallo). Como en
/// Mercado Libre, se rechazan teléfonos (10 números o más, aunque tengan
/// espacios o guiones), mails y menciones a WhatsApp. Un año o un modelo
/// ("Gol 2012") no llega a 10 números.
bool tieneDatosDeContacto(String texto) {
  final minuscula = texto.toLowerCase();
  if (minuscula.contains('@') ||
      minuscula.contains('whatsapp') ||
      minuscula.contains('wa.me')) {
    return true;
  }
  return RegExp(r'(?:\d[\s.\-]?){10,}').hasMatch(texto);
}
