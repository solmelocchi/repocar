import 'dart:async';

// =====================================================================
// SERVICIO: las preguntas, en crudo.
//
// Las preguntas solo tienen sentido COMPARTIDAS (las hace un teléfono y
// las ve otro), así que viven en el servidor: PreguntasFirestore. Son
// Streams porque llegan solas, como los pedidos. Firestore ya guarda una
// copia en el teléfono para cuando no hay señal.
//
// Sin servidor (y en las pruebas) se usa PreguntasEnMemoria.
// =====================================================================
abstract class PreguntasService {
  /// Las preguntas de una publicación (las ve cualquiera).
  Stream<List<Map<String, dynamic>>> dePieza(String piezaId);

  /// Las preguntas que le hicieron a un taller (para avisarle).
  Stream<List<Map<String, dynamic>>> deTaller(String tallerCuit);

  /// Las que hizo quien tiene la sesión (para avisarle cuando le
  /// respondan).
  Stream<List<Map<String, dynamic>>> mias();

  Future<void> crear(Map<String, dynamic> pregunta);

  Future<void> responder(
    String id, {
    required String respuesta,
    required DateTime cuando,
  });
}

/// Las preguntas en la memoria de este teléfono.
class PreguntasEnMemoria implements PreguntasService {
  PreguntasEnMemoria({this.quienSoy = 'yo'});

  /// Quién está preguntando (en Firestore, el usuario de la sesión).
  String quienSoy;

  final _todas = <String, Map<String, dynamic>>{};
  final _cambios = StreamController<void>.broadcast();

  List<Map<String, dynamic>> _foto(
    bool Function(Map<String, dynamic>) condicion,
  ) => [
    for (final pregunta in _todas.values)
      if (condicion(pregunta)) Map.of(pregunta),
  ];

  /// Como snapshots() de Firestore: apenas alguien escucha, manda lo que
  /// hay; después, una lista nueva cada vez que algo cambia.
  Stream<List<Map<String, dynamic>>> _donde(
    bool Function(Map<String, dynamic>) condicion,
  ) {
    late final StreamController<List<Map<String, dynamic>>> salida;
    StreamSubscription<void>? cambios;
    salida = StreamController(
      onListen: () {
        salida.add(_foto(condicion));
        cambios = _cambios.stream.listen((_) => salida.add(_foto(condicion)));
      },
      onCancel: () => cambios?.cancel(),
    );
    return salida.stream;
  }

  @override
  Stream<List<Map<String, dynamic>>> dePieza(String piezaId) =>
      _donde((p) => p['pieza_id'] == piezaId);

  @override
  Stream<List<Map<String, dynamic>>> deTaller(String tallerCuit) =>
      _donde((p) => p['taller_cuit'] == tallerCuit);

  @override
  Stream<List<Map<String, dynamic>>> mias() {
    final yo = quienSoy;
    return _donde((p) => p['autor_uid'] == yo);
  }

  @override
  Future<void> crear(Map<String, dynamic> pregunta) async {
    _todas[pregunta['id'] as String] = {...pregunta, 'autor_uid': quienSoy};
    _cambios.add(null);
  }

  @override
  Future<void> responder(
    String id, {
    required String respuesta,
    required DateTime cuando,
  }) async {
    final pregunta = _todas[id];
    if (pregunta == null) return;
    pregunta['respuesta'] = respuesta;
    pregunta['respondida'] = cuando.toIso8601String();
    _cambios.add(null);
  }
}
