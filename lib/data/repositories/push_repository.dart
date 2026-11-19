import 'dart:async';

import '../remoto/tokens_push.dart';
import '../services/push_service.dart';

// =====================================================================
// REPOSITORIO de las push. Las reglas:
//   · Cuando alguien entra, el token del teléfono se guarda en el
//     servidor asociado a esa cuenta (paso 2 del apunte: "la app le
//     manda el token a su servidor").
//   · Si el token cambia, se vuelve a guardar.
//   · Cuando sale, se borra: ese teléfono deja de recibir sus avisos.
// Si el servidor no contesta, no pasa nada: la app sigue andando.
// =====================================================================
class PushRepository {
  PushRepository({required PushService servicio, required TokensPush tokens})
    : _servicio = servicio,
      _tokens = tokens;

  final PushService _servicio;
  final TokensPush _tokens;

  String? _token;
  String? _usuario;
  StreamSubscription<String>? _refrescos;

  /// El token de este teléfono, para copiarlo y probar desde la consola
  /// de Firebase. Null si no hay push en esta plataforma.
  String? get token => _token;

  Stream<MensajePush> get enPrimerPlano => _servicio.enPrimerPlano;

  Stream<MensajePush> get tocadas => _servicio.tocadas;

  Future<MensajePush?> conLaQueSeAbrio() => _servicio.conLaQueSeAbrio();

  Future<void> iniciar() async {
    await _servicio.iniciar();
    try {
      _token = await _servicio.token();
    } catch (_) {
      _token = null; // sin red o sin Google Play: sin push, nada más
    }
    _refrescos = _servicio.tokensNuevos.listen((nuevo) {
      _token = nuevo;
      _subir();
    });
  }

  /// Quién tiene la sesión ahora (null si nadie). Lo llama
  /// dependencias.dart cada vez que cambia la sesión.
  Future<void> usuarioActual(String? usuario) async {
    if (usuario == _usuario) return;
    final habia = _usuario;
    _usuario = usuario;
    try {
      if (usuario != null) {
        await _subir();
      } else if (habia != null) {
        await _tokens.borrar();
      }
    } catch (_) {}
  }

  Future<void> _subir() async {
    final usuario = _usuario;
    final token = _token;
    if (usuario == null || token == null) return;
    try {
      await _tokens.guardar(usuario: usuario, token: token);
    } catch (_) {}
  }

  void dispose() => _refrescos?.cancel();
}
