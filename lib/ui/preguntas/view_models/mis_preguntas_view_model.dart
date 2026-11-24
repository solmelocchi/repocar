import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/preguntas_repository.dart';
import '../../../domain/models/pregunta.dart';
import '../../notificaciones/view_models/notificaciones_view_model.dart';

// =====================================================================
// VIEWMODEL de las preguntas de quien tiene la sesión. Vive toda la app.
//
//   · Si entró un TALLER: escucha las preguntas que le hacen, le avisa
//     cuando llega una nueva y le muestra las que no respondió.
//   · Si entró un COMPRADOR: escucha las que él hizo y le avisa cuando el
//     taller le responde.
//
// La primera lista que llega es "lo que ya había": no se avisa. Se avisa
// solo lo que cambia DESPUÉS.
// =====================================================================
class MisPreguntasViewModel extends ChangeNotifier {
  MisPreguntasViewModel({
    required PreguntasRepository repositorio,
    required NotificacionesViewModel avisos,
  }) : _repositorio = repositorio,
       _avisos = avisos;

  final PreguntasRepository _repositorio;
  final NotificacionesViewModel _avisos;

  StreamSubscription<List<Pregunta>>? _suscripcion;
  String? _siguiendo;
  final _conocidas = <String, Pregunta>{};
  bool _primeraVez = true;
  List<Pregunta> _sinResponder = const [];

  /// Las que el taller todavía no respondió.
  List<Pregunta> get sinResponder => _sinResponder;

  void seguirTaller(String cuit) => _seguir(
    'taller:$cuit',
    _repositorio.deTaller(cuit),
    esTaller: true,
    alCambiar: (nueva, antes) {
      if (antes == null && !nueva.respondida) {
        unawaited(
          _avisos.avisar(
            para: cuit,
            titulo: 'Pregunta nueva',
            texto: '${nueva.piezaTitulo}: "${nueva.texto}"',
            payload: 'pregunta:${nueva.piezaId}',
          ),
        );
      }
    },
  );

  void seguirComprador(String nombre) => _seguir(
    'comprador:$nombre',
    _repositorio.mias(),
    esTaller: false,
    alCambiar: (nueva, antes) {
      if (nueva.respondida && antes != null && !antes.respondida) {
        unawaited(
          _avisos.avisar(
            para: nombre,
            titulo: 'Te respondieron',
            texto: '${nueva.piezaTitulo}: ${nueva.respuesta}',
            payload: 'pregunta:${nueva.piezaId}',
          ),
        );
      }
    },
  );

  void _seguir(
    String clave,
    Stream<List<Pregunta>> preguntas, {
    required bool esTaller,
    required void Function(Pregunta nueva, Pregunta? antes) alCambiar,
  }) {
    if (clave == _siguiendo) return; // ya la estaba escuchando
    dejar();
    _siguiendo = clave;
    _suscripcion = preguntas.listen((lista) {
      if (!_primeraVez) {
        for (final pregunta in lista) {
          alCambiar(pregunta, _conocidas[pregunta.id]);
        }
      }
      _primeraVez = false;
      _conocidas
        ..clear()
        ..addAll({for (final pregunta in lista) pregunta.id: pregunta});
      _sinResponder = esTaller
          ? lista.where((pregunta) => !pregunta.respondida).toList()
          : const [];
      notifyListeners();
    });
  }

  /// Salió de la sesión: deja de escuchar.
  void dejar() {
    if (_siguiendo == null) return;
    _suscripcion?.cancel();
    _suscripcion = null;
    _siguiendo = null;
    _conocidas.clear();
    _primeraVez = true;
    _sinResponder = const [];
    notifyListeners();
  }

  /// El taller responde desde su lista. Devuelve el motivo si no se
  /// pudo, o null.
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
    _suscripcion?.cancel();
    super.dispose();
  }
}
