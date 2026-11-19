// =====================================================================
// DOMINIO: el vehículo del comprador.
// Fijate que acá no se importa material.dart: el dominio no sabe que
// existen los widgets. Solo son datos y reglas.
// =====================================================================

/// El auto que eligió el comprador.
class Auto {
  final String marca;
  final String modelo;
  final int anio;

  const Auto({required this.marca, required this.modelo, required this.anio});

  @override
  String toString() => '$marca $modelo $anio';
}

/// Un modelo de auto con los años en que se fabricó.
/// Esta lista la carga el sistema: el taller NUNCA escribe el auto a mano.
class ModeloVehiculo {
  final String marca;
  final String modelo;
  final int desde;
  final int hasta;

  const ModeloVehiculo(this.marca, this.modelo, this.desde, this.hasta);

  /// Traduce un dato crudo (como vendría de la API) a un modelo del dominio.
  factory ModeloVehiculo.desdeJson(Map<String, dynamic> json) => ModeloVehiculo(
    json['marca'] as String,
    json['modelo'] as String,
    json['desde'] as int,
    json['hasta'] as int,
  );
}

/// Para qué autos sirve una pieza. Es el corazón del sistema.
class Compatibilidad {
  final String marca;
  final String modelo;
  final int desde;
  final int hasta;

  const Compatibilidad(this.marca, this.modelo, this.desde, this.hasta);

  /// ¿Esta pieza le sirve a este auto?
  bool sirvePara(Auto auto) =>
      marca == auto.marca &&
      modelo == auto.modelo &&
      auto.anio >= desde &&
      auto.anio <= hasta;

  factory Compatibilidad.desdeJson(Map<String, dynamic> json) => Compatibilidad(
    json['marca'] as String,
    json['modelo'] as String,
    json['desde'] as int,
    json['hasta'] as int,
  );

  String get texto => '$marca $modelo $desde-$hasta';
}
