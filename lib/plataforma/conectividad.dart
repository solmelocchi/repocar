import 'package:connectivity_plus/connectivity_plus.dart';

// =====================================================================
// EVENTO DEL SISTEMA: la conexión a la red.
//
// connectivity_plus trae dos cosas que se usan JUNTAS:
//   · checkConnectivity(): el estado de AHORA (un Future).
//   · onConnectivityChanged: un STREAM que solo avisa los CAMBIOS. Si
//     nadie preguntó antes, no dice cómo está ahora: por eso hace falta
//     también la primera.
//
// Ojo: tener red no es tener internet (un wifi puede no salir a
// ningún lado). Esto sirve para avisar y para disparar el reintento,
// nunca para dar algo por enviado: eso solo lo confirma el servidor.
// =====================================================================
class Conectividad {
  Conectividad({Connectivity? plugin}) : _plugin = plugin ?? Connectivity();

  final Connectivity _plugin;

  /// Devuelve una LISTA porque puede haber varias redes a la vez
  /// (wifi + vpn). Hay red si alguna no es "ninguna".
  static bool _hayAlguna(List<ConnectivityResult> redes) =>
      redes.any((red) => red != ConnectivityResult.none);

  /// Cómo está la conexión ahora.
  Future<bool> hayRed() async {
    try {
      return _hayAlguna(await _plugin.checkConnectivity());
    } catch (_) {
      // Si el plugin no responde, mejor no asustar con "sin conexión".
      return true;
    }
  }

  /// Cada vez que cambia: true si volvió, false si se fue.
  /// distinct() saca los repetidos (pasar de wifi a datos sigue siendo
  /// "hay red" y no hace falta avisar).
  Stream<bool> get cambios =>
      _plugin.onConnectivityChanged.map(_hayAlguna).distinct();
}
