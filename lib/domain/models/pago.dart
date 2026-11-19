// =====================================================================
// DOMINIO: el pago.
//
// Cómo paga el comprador y qué contestó quien cobra. No sabe nada de
// Mercado Pago ni de pantallas: son datos y reglas.
// =====================================================================

/// Con qué paga. La última es una tarjeta de PRUEBA que siempre se
/// rechaza, como las que da Mercado Pago para probar los errores.
enum MedioDePago { dineroEnCuenta, debito, credito, tarjetaRechazada }

extension MedioDePagoTexto on MedioDePago {
  String get titulo => switch (this) {
    MedioDePago.dineroEnCuenta => 'Dinero en cuenta',
    MedioDePago.debito => 'Tarjeta de débito',
    MedioDePago.credito => 'Tarjeta de crédito',
    MedioDePago.tarjetaRechazada => 'Tarjeta de prueba sin fondos',
  };

  String get detalle => switch (this) {
    MedioDePago.dineroEnCuenta => 'Saldo disponible en Mercado Pago',
    MedioDePago.debito => 'Visa débito terminada en 1234',
    MedioDePago.credito => 'Mastercard terminada en 3704',
    MedioDePago.tarjetaRechazada => 'Para probar qué pasa si el pago falla',
  };

  bool get admiteCuotas => this == MedioDePago.credito;
}

/// Lo que contesta quien cobra.
class ResultadoPago {
  const ResultadoPago.aprobado(this.codigo) : aprobado = true, motivo = null;

  const ResultadoPago.rechazado(this.motivo) : aprobado = false, codigo = null;

  final bool aprobado;

  /// El número de operación, si se aprobó.
  final String? codigo;

  /// Por qué se rechazó, para mostrárselo al comprador.
  final String? motivo;
}

/// Cuánto paga por mes en cuotas sin interés (redondeado hacia arriba,
/// para que la suma de las cuotas nunca quede corta).
int valorDeCuota(int total, int cuotas) => (total + cuotas - 1) ~/ cuotas;
