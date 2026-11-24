import '../../domain/models/pieza.dart';
import '../../domain/models/pregunta.dart';
import '../services/preguntas_service.dart';

/// Lo que se quiso preguntar o responder no cumple las reglas.
class PreguntaInvalida implements Exception {
  const PreguntaInvalida(this.mensaje);

  final String mensaje;

  @override
  String toString() => mensaje;
}

// =====================================================================
// REPOSITORIO de las preguntas. Las reglas:
//   · no vacía y de 300 letras como máximo;
//   · sin teléfonos, mails ni WhatsApp (para que la venta quede en la app);
//   · la más nueva, primero.
// Lo crudo del servicio se convierte en Preguntas (el dominio).
// =====================================================================
class PreguntasRepository {
  PreguntasRepository({required PreguntasService servicio})
    : _servicio = servicio;

  final PreguntasService _servicio;

  static const largoMaximo = 300;

  Stream<List<Pregunta>> dePieza(String piezaId) =>
      _servicio.dePieza(piezaId).map(_armar);

  Stream<List<Pregunta>> deTaller(String tallerCuit) =>
      _servicio.deTaller(tallerCuit).map(_armar);

  Stream<List<Pregunta>> mias() => _servicio.mias().map(_armar);

  Stream<List<Pregunta>> todas() => _servicio.todas().map(_armar);

  static List<Pregunta> _armar(List<Map<String, dynamic>> crudas) {
    final preguntas = <Pregunta>[];
    for (final cruda in crudas) {
      try {
        preguntas.add(Pregunta.desdeJson(cruda));
      } catch (_) {
        // Un dato roto no tira abajo toda la lista.
      }
    }
    return preguntas..sort((a, b) => b.fecha.compareTo(a.fecha));
  }

  /// Devuelve el texto limpio, o lanza PreguntaInvalida con el motivo.
  static String validar(String texto) {
    final limpio = texto.trim();
    if (limpio.isEmpty) {
      throw const PreguntaInvalida('Escribí algo antes de enviar.');
    }
    if (limpio.length > largoMaximo) {
      throw const PreguntaInvalida('Es muy largo: hasta 300 letras.');
    }
    if (tieneDatosDeContacto(limpio)) {
      throw const PreguntaInvalida(
        'No se pueden pasar teléfonos, mails ni WhatsApp: la compra se hace '
        'por RepoCar.',
      );
    }
    return limpio;
  }

  Future<void> preguntar({
    required Pieza pieza,
    required String autor,
    required String texto,
  }) async {
    final limpio = validar(texto);
    final ahora = DateTime.now();
    final pregunta = Pregunta(
      id: '${pieza.id}-${ahora.microsecondsSinceEpoch}',
      piezaId: pieza.id,
      piezaTitulo: pieza.titulo,
      tallerCuit: pieza.taller.cuit,
      autor: autor,
      texto: limpio,
      fecha: ahora,
    );
    await _servicio.crear(pregunta.aJson());
  }

  Future<void> responder(Pregunta pregunta, String texto) async {
    final limpio = validar(texto);
    await _servicio.responder(
      pregunta.id,
      respuesta: limpio,
      cuando: DateTime.now(),
    );
  }
}
