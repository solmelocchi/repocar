/// Un aviso para alguien: el taller que recibió un pedido o el
/// comprador al que le llegó el repuesto.
class Notificacion {
  final String id;
  final String titulo;
  final String texto;

  /// A quién va dirigida: el CUIT del taller o el nombre del comprador.
  final String para;

  final DateTime fecha;
  bool leida;

  Notificacion({
    required this.id,
    required this.titulo,
    required this.texto,
    required this.para,
    required this.fecha,
    this.leida = false,
  });

  factory Notificacion.desdeJson(Map<String, dynamic> json) => Notificacion(
    id: json['id'] as String,
    titulo: json['titulo'] as String,
    texto: json['texto'] as String,
    para: json['para'] as String,
    fecha: DateTime.parse(json['fecha'] as String),
    leida: json['leida'] == true,
  );

  Map<String, dynamic> aJson() => {
    'id': id,
    'titulo': titulo,
    'texto': texto,
    'para': para,
    'fecha': fecha.toIso8601String(),
    'leida': leida,
  };
}
