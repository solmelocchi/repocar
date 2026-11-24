// =====================================================================
// DOMINIO: el taller que vende.
// =====================================================================

/// El taller que vende la pieza.
class Taller {
  final String nombre;

  // Teléfono, zona y cadete se pueden cambiar desde "Editar mis datos".
  // No son final: se cambian en el MISMO objeto, así las publicaciones
  // y los pedidos que apuntan a este taller ven el dato nuevo.
  String telefono;
  String zona;

  /// El CUIT con el que se registró. Se valida con su dígito verificador
  /// (domain/cuit.dart). En la app real, además, se consultaría el padrón
  /// de ARCA para saber que el taller existe de verdad.
  final String cuit;

  /// ¿Tiene cadete propio? (el de la moto, el sobrino que reparte)
  /// Si no tiene, el envío lo cotiza la empresa según la zona del comprador.
  bool tieneCadete;

  /// Lo que cobra ese cadete. Solo se usa si tieneCadete es true.
  int costoCadete;

  /// La comisión que le retiene TalleresYa sobre cada venta (0,10 = 10%).
  /// Va por taller y no fija en el código: Ramallo la cambia desde su
  /// panel (10% para todos, 5% para el Tano Ferrari...).
  double comision;

  /// La promoción de bienvenida: hasta esta fecha, el taller no paga
  /// comisión ("los primeros tres meses sin comisión, así se enganchan").
  /// Termina sola: no hay que acordarse de volver a cobrarle.
  DateTime? sinComisionHasta;

  /// ¿Está en la promoción sin comisión en este momento?
  bool enPromocion(DateTime ahora) {
    final hasta = sinComisionHasta;
    return hasta != null && ahora.isBefore(hasta);
  }

  /// La comisión que corresponde AHORA: 0 mientras dura la promoción.
  /// Es la que se congela en cada pedido.
  double comisionVigente(DateTime ahora) => enPromocion(ahora) ? 0 : comision;

  Taller({
    required this.nombre,
    required this.telefono,
    required this.zona,
    this.cuit = '',
    this.tieneCadete = false,
    this.costoCadete = 0,
    this.comision = 0.10,
    this.sinComisionHasta,
  });

  factory Taller.desdeJson(Map<String, dynamic> json) => Taller(
    nombre: json['nombre'] as String,
    telefono: json['telefono'] as String,
    zona: json['zona'] as String,
    cuit: json['cuit'] as String,
    tieneCadete: json['tiene_cadete'] as bool,
    costoCadete: json['costo_cadete'] as int,
    comision: (json['comision'] as num).toDouble(),
    sinComisionHasta: json['sin_comision_hasta'] == null
        ? null
        : DateTime.parse(json['sin_comision_hasta'] as String),
  );

  /// El camino de vuelta: así se guarda en la base local.
  Map<String, dynamic> aJson() => {
    'nombre': nombre,
    'telefono': telefono,
    'zona': zona,
    'cuit': cuit,
    'tiene_cadete': tieneCadete,
    'costo_cadete': costoCadete,
    'comision': comision,
    'sin_comision_hasta': sinComisionHasta?.toIso8601String(),
  };
}

/// REGLA DEL NEGOCIO: entre 0% y 30%. Más que eso es un error de tipeo
/// (por ejemplo, poner 50 queriendo poner 5).
bool comisionValida(double comision) => comision >= 0 && comision <= 0.30;

/// Cuánto dura la promoción de bienvenida.
const duracionDeLaPromocion = Duration(days: 90);

/// El comprador. No necesita CUIT ni constancia: con el mail alcanza,
/// porque comprar lo puede hacer cualquiera.
class Cliente {
  final String nombre;
  final String usuario;

  /// Se puede cambiar desde "Editar mis datos". El nombre no: los
  /// pedidos guardan el nombre del comprador.
  String telefono;

  Cliente({
    required this.nombre,
    required this.usuario,
    required this.telefono,
  });

  factory Cliente.desdeJson(Map<String, dynamic> json) => Cliente(
    nombre: json['nombre'] as String,
    usuario: json['usuario'] as String,
    telefono: json['telefono'] as String,
  );

  Map<String, dynamic> aJson() => {
    'nombre': nombre,
    'usuario': usuario,
    'telefono': telefono,
  };
}
