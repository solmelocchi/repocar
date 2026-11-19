import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../plataforma/conectividad.dart';

// =====================================================================
// VIEWMODEL de la conexión: ¿hay red o no?
//
// ESCUCHA el Stream de conectividad mientras la app está abierta y
// cancela la suscripción en dispose. Si no se cancelara, cada vez que
// se crea quedaría una suscripción viva más: avisos repetidos,
// "setState() called after dispose" y pérdida de memoria.
// =====================================================================
class ConexionViewModel extends ChangeNotifier {
  ConexionViewModel({
    required Conectividad conectividad,
    VoidCallback? alVolver,
  }) : _conectividad = conectividad,
       _alVolver = alVolver;

  final Conectividad _conectividad;

  /// Qué reintentar cuando vuelve la red. Lo decide dependencias.dart.
  final VoidCallback? _alVolver;

  StreamSubscription<bool>? _suscripcion;

  bool _hayRed = true;
  bool get hayRed => _hayRed;

  Future<void> iniciar() async {
    if (_suscripcion != null) return;

    // Primero, cómo está ahora (el Stream solo avisa cambios).
    _hayRed = await _conectividad.hayRed();
    notifyListeners();

    // Después, cada cambio.
    _suscripcion = _conectividad.cambios.listen((hay) {
      final volvio = hay && !_hayRed;
      _hayRed = hay;
      notifyListeners();
      if (volvio) _alVolver?.call();
    });
  }

  @override
  void dispose() {
    _suscripcion?.cancel();
    super.dispose();
  }
}
