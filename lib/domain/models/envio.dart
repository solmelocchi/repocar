// =====================================================================
// DOMINIO: cómo llega el repuesto.
// =====================================================================

/// Una zona de reparto con su tarifa, para los talleres sin cadete propio.
/// Es una lista fija que carga TalleresYa, igual que la de vehículos.
class ZonaEnvio {
  final String nombre;
  final int km;
  final int tarifa;

  const ZonaEnvio(this.nombre, this.km, this.tarifa);

  factory ZonaEnvio.desdeJson(Map<String, dynamic> json) => ZonaEnvio(
    json['nombre'] as String,
    json['km'] as int,
    json['tarifa'] as int,
  );
}

/// Las tres formas de recibir el pedido.
enum MetodoEntrega { retiro, cadete, envio }

extension MetodoEntregaTexto on MetodoEntrega {
  String get texto => switch (this) {
    MetodoEntrega.retiro => 'Retiro en el taller',
    MetodoEntrega.cadete => 'Cadete del taller',
    MetodoEntrega.envio => 'Envío a domicilio',
  };

  String get clave => name;
}
