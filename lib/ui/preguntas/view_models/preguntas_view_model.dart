import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/preguntas_repository.dart';
import '../../../domain/models/pieza.dart';
import '../../../domain/models/pregunta.dart';
import '../../core/estado_carga.dart';

// =====================================================================
// VIEWMODEL de las preguntas de UNA publicación (la ficha). Hay uno por
// ficha abierta: lo arma dependencias.dart.
//
// Escucha el Stream de las preguntas: lo que pregunta otro teléfono, o la
// respuesta del taller, aparece solo. No hace falta "refrescar".
// =====================================================================
class PreguntasViewModel extends ChangeNotifier {
  PreguntasViewModel({
    required PreguntasRepository repositorio,
    required this.pieza,
    required String? Function() autor,
  }) : _repositorio = repositorio,
       _autor = autor;

  final PreguntasRepository _repositorio;
  final Pieza pieza;

  /// Quién pregunta (el comprador con sesión), o null si no puede.
  final String? Function() _autor;

  StreamSubscription<List<Pregunta>>? _suscripcion;
  EstadoCarga _estado = EstadoCarga.cargando;
  List<Pregunta> _preguntas = const [];
  bool _enviando = false;
  String? _error;

  EstadoCarga get estado => _estado;
  List<Pregunta> get preguntas => _preguntas;
  bool get enviando => _enviando;

  /// Por qué no se pudo enviar (para mostrarlo debajo del campo).
  String? get error => _error;

  bool get puedePreguntar => _autor() != null;

  void iniciar() {
    _suscripcion ??= _repositorio
        .dePieza(pieza.id)
        .listen(
          (lista) {
            _preguntas = lista;
            _estado = EstadoCarga.exito;
            notifyListeners();
          },
          onError: (Object _) {
            _estado = EstadoCarga.error;
            notifyListeners();
          },
        );
  }

  /// Devuelve true si se envió. Si no, el motivo queda en [error].
  Future<bool> preguntar(String texto) async {
    final autor = _autor();
    if (_enviando || autor == null) return false; // evita el doble toque
    _enviando = true;
    _error = null;
    notifyListeners();
    try {
      await _repositorio.preguntar(pieza: pieza, autor: autor, texto: texto);
      return true;
    } on PreguntaInvalida catch (motivo) {
      _error = motivo.mensaje;
      return false;
    } catch (_) {
      _error = 'No se pudo enviar. Probá de nuevo.';
      return false;
    } finally {
      _enviando = false;
      notifyListeners();
    }
  }

  /// El taller responde. Devuelve el motivo si no se pudo, o null.
  Future<String?> responder(Pregunta pregunta, String texto) async {
    try {
      await _repositorio.responder(pregunta, texto);
      return null;
    } on PreguntaInvalida catch (motivo) {
      return motivo.mensaje;
    } catch (_) {
      return 'No se pudo enviar la respuesta.';
    }
  }

  @override
  void dispose() {
    _suscripcion?.cancel(); // lo que se abre, se cierra
    super.dispose();
  }
}
