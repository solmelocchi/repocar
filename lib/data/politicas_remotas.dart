import 'dart:async'; // para TimeoutException

import 'services/configuracion_service.dart';

// =====================================================================
// POLÍTICAS que se deciden desde el servidor, con timeout.
//
// La idea es la del apunte: si el servidor no contesta a tiempo, no se
// cuelga la app ni se muestra un error. Se aplica la POLÍTICA POR
// DEFECTO, que siempre es la opción más segura.
// =====================================================================
class PoliticasRemotas {
  PoliticasRemotas(this._servicio, {this.limite = const Duration(seconds: 3)});

  final ConfiguracionService _servicio;

  /// Cuánto esperamos al servidor antes de rendirnos.
  final Duration limite;

  /// Lo que arranca cobrando TalleresYa a un taller nuevo.
  ///
  /// Si el servidor no contesta, se usa el 10% de siempre: cobrar de
  /// menos es preferible a cobrarle mal a un taller.
  Future<double> comisionPorDefecto() async {
    try {
      // El await dentro del try es necesario: sin él, la
      // TimeoutException saldría sin pasar por el catch.
      final config = await _servicio.obtenerConfiguracion().timeout(limite);
      return (config['comision_default'] as num).toDouble();
    } on TimeoutException {
      return 0.10; // política por defecto
    }
  }

  /// Si el cobro dentro de la app está habilitado.
  ///
  /// Si no sabemos, es que NO: antes que cobrar mal, el comprador
  /// coordina con el taller como en la primera etapa.
  Future<bool> pagoHabilitado() async {
    try {
      final config = await _servicio.obtenerConfiguracion().timeout(limite);
      return config['pagos_habilitados'] == true;
    } on TimeoutException {
      return false; // política por defecto: la opción segura
    }
  }
}
