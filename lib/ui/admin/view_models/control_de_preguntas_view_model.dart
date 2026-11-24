import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/preguntas_repository.dart';
import '../../../domain/control_de_ventas.dart';
import '../../../domain/models/pieza.dart';
import '../../../domain/models/pregunta.dart';

/// Una publicación para revisar: tuvo preguntas y no se vendió por la app.
typedef SenalParaRevisar = ({Pieza pieza, int preguntas, String motivo});

// =====================================================================
// VIEWMODEL del control de TalleresYa sobre las preguntas.
//
// Ramallo ve TODAS las preguntas y respuestas (como un moderador),
// cuántas faltan responder, y las publicaciones que conviene revisar
// porque pueden ser ventas que se fueron por fuera de la app.
// =====================================================================
class ControlDePreguntasViewModel extends ChangeNotifier {
  ControlDePreguntasViewModel({
    required PreguntasRepository repositorio,
    required Pieza? Function(String id) buscarPieza,
  }) : _repositorio = repositorio,
       _buscarPieza = buscarPieza;

  final PreguntasRepository _repositorio;

  /// Busca la pieza en el catálogo (incluidas pausadas y borradas).
  final Pieza? Function(String id) _buscarPieza;

  StreamSubscription<List<Pregunta>>? _suscripcion;
  List<Pregunta> _todas = const [];

  List<Pregunta> get todas => _todas;

  int get sinResponder => _todas.where((p) => !p.respondida).length;

  /// Escucha todas las preguntas (un Stream: las nuevas aparecen solas).
  void iniciar() {
    _suscripcion ??= _repositorio.todas().listen((lista) {
      _todas = lista;
      notifyListeners();
    });
  }

  /// Las publicaciones con preguntas que el taller pausó o borró sin
  /// venderlas por RepoCar. Se calcula cada vez, porque el estado de las
  /// piezas también cambia (llega por el Stream del catálogo).
  List<SenalParaRevisar> get paraRevisar {
    final porPieza = <String, int>{};
    for (final pregunta in _todas) {
      porPieza[pregunta.piezaId] = (porPieza[pregunta.piezaId] ?? 0) + 1;
    }
    return [
      for (final MapEntry(key: id, value: cuantas) in porPieza.entries)
        if (_buscarPieza(id) case final pieza?)
          if (esSenalDeVentaPorFuera(pieza, preguntas: cuantas))
            (pieza: pieza, preguntas: cuantas, motivo: motivoDeLaSenal(pieza)),
    ];
  }

  @override
  void dispose() {
    _suscripcion?.cancel();
    super.dispose();
  }
}
