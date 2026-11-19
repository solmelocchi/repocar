import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/notificaciones_repository.dart';
import '../../../data/repositories/push_repository.dart';
import '../../../data/services/push_service.dart';
import '../../../domain/models/notificacion.dart';

// =====================================================================
// VIEWMODEL de los avisos: la campanita, su bandeja y el permiso.
// =====================================================================
class NotificacionesViewModel extends ChangeNotifier {
  NotificacionesViewModel({
    required NotificacionesRepository repositorio,
    PushRepository? push,
    String? Function()? destinatario,
  }) : _repositorio = repositorio,
       _push = push,
       _destinatario = destinatario;

  final NotificacionesRepository _repositorio;

  /// Las push (FCM). Null en los tests que no las usan.
  final PushRepository? _push;

  /// Quién tiene la sesión: de quién es la bandeja donde se anota una
  /// push. Se lo pasa dependencias.dart (este view model no conoce la
  /// sesión).
  final String? Function()? _destinatario;

  final List<StreamSubscription<Object>> _suscripciones = [];

  /// Los toques: los de las notificaciones locales y los de las push.
  final _toques = StreamController<String>.broadcast();

  /// La push con la que se abrió la app (estado 3, cerrada). Se anota
  /// en la bandeja cuando ya se sabe quién entró.
  MensajePush? _pushInicial;

  /// Mientras no se consultó al dispositivo, la campanita no se dibuja.
  bool _puedeNotificar = false;
  bool get puedeNotificar => _puedeNotificar;

  /// Si el usuario dejó mostrar notificaciones del sistema. Si no dejó,
  /// la bandeja anda igual y se le ofrece activarlas con un botón.
  bool _tienePermiso = false;
  bool get tienePermiso => _tienePermiso;

  /// Si la app se abrió tocando una notificación: la primera campanita
  /// que se dibuje abre la bandeja.
  bool _abrirBandejaAlEntrar = false;

  /// Los avisos tocados con la app abierta (los escucha main.dart).
  Stream<String> get toques => _toques.stream;

  /// El token de push de este teléfono (para probar desde la consola de
  /// Firebase). Null si en esta plataforma no hay push.
  String? get tokenPush => _push?.token;

  /// Se llama una vez al arrancar, antes de runApp: prepara el sistema
  /// de notificaciones y se fija si la app se abrió tocando una.
  Future<void> iniciar() async {
    await _repositorio.iniciar();
    _abrirBandejaAlEntrar = await _repositorio.avisoConElQueSeAbrio() != null;
    _suscripciones.add(_repositorio.toques.listen(_toques.add));

    final push = _push;
    if (push == null) return;
    await push.iniciar();
    _suscripciones
      ..add(push.enPrimerPlano.listen(_alLlegarPush))
      ..add(push.tocadas.listen(_alTocarPush));
    _pushInicial = await push.conLaQueSeAbrio();
    if (_pushInicial != null) _abrirBandejaAlEntrar = true;
  }

  /// PUSH, estado 1 (app abierta): FCM no la muestra sola. La mostramos
  /// nosotros, con el mismo canal y la misma bandeja que las locales.
  Future<void> _alLlegarPush(MensajePush mensaje) => avisar(
    para: _destinatario?.call() ?? '',
    titulo: mensaje.titulo,
    texto: mensaje.texto,
    payload: 'push',
  );

  /// PUSH, estado 2 (minimizada): el sistema ya la mostró y la tocaron.
  /// Se anota en la campanita y se abre la bandeja.
  Future<void> _alTocarPush(MensajePush mensaje) async {
    await _anotarPush(mensaje);
    _toques.add('push');
  }

  Future<void> _anotarPush(MensajePush mensaje) async {
    final para = _destinatario?.call();
    if (para == null) return;
    await _repositorio.anotar(
      para: para,
      titulo: mensaje.titulo,
      texto: mensaje.texto,
    );
    notifyListeners();
  }

  /// Devuelve true UNA sola vez si hay que abrir la bandeja al entrar.
  /// Si la app se abrió con una push (estado 3), ahí se anota: recién
  /// ahora se sabe de quién es la bandeja.
  bool consumirAperturaPendiente() {
    final inicial = _pushInicial;
    _pushInicial = null;
    if (inicial != null) unawaited(_anotarPush(inicial));

    final abrir = _abrirBandejaAlEntrar;
    _abrirBandejaAlEntrar = false;
    return abrir;
  }

  /// Le pregunta al dispositivo si puede notificar, si hay permiso, y
  /// trae los avisos guardados de otras veces.
  Future<void> consultarCapacidad() async {
    try {
      _puedeNotificar = await _repositorio.sePuedeNotificar();
      _tienePermiso = await _repositorio.tienePermiso();
      await _repositorio.cargar();
    } finally {
      // Aunque falle la consulta, la campanita se entera y se redibuja.
      notifyListeners();
    }
  }

  /// Lo llama el botón "Activar avisos": el permiso se pide en
  /// contexto, cuando el usuario sabe para qué es.
  Future<void> pedirPermiso() async {
    _tienePermiso = await _repositorio.pedirPermiso();
    notifyListeners();
  }

  List<Notificacion> para(String destinatario) =>
      _repositorio.para(destinatario);

  int sinLeerDe(String destinatario) => _repositorio.sinLeerDe(destinatario);

  Future<void> avisar({
    required String para,
    required String titulo,
    required String texto,
    String? payload,
    int? idDelSistema,
  }) async {
    await _repositorio.avisar(
      para: para,
      titulo: titulo,
      texto: texto,
      payload: payload,
      idDelSistema: idDelSistema,
    );
    notifyListeners();
  }

  Future<void> programar({
    required int id,
    required String titulo,
    required String texto,
    required DateTime cuando,
    String? payload,
  }) => _repositorio.programar(
    id: id,
    titulo: titulo,
    texto: texto,
    cuando: cuando,
    payload: payload,
  );

  Future<void> cancelar(int id) => _repositorio.cancelar(id);

  Future<void> marcarLeidas(String destinatario) async {
    await _repositorio.marcarLeidas(destinatario);
    notifyListeners();
  }

  @override
  void dispose() {
    for (final suscripcion in _suscripciones) {
      suscripcion.cancel();
    }
    _toques.close();
    _push?.dispose();
    super.dispose();
  }
}
