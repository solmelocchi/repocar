import 'auto.dart';
import 'taller.dart';

// =====================================================================
// DOMINIO: la publicación de un repuesto.
// =====================================================================

enum EstadoPieza { usado, reacondicionado }

extension EstadoPiezaTexto on EstadoPieza {
  String get texto => this == EstadoPieza.usado ? 'Usado' : 'Reacondicionado';

  /// Como se guarda y viaja: 'usado' o 'reacondicionado'.
  String get clave => name;
}

/// Una publicación del catálogo.
class Pieza {
  final String id;
  final String titulo;
  final String descripcion;
  final int precio;
  final EstadoPieza estado;
  final Taller taller;

  /// El nombre del ícono, no el ícono. El dominio no conoce material:
  /// la UI traduce esta clave a un IconData. Se usa cuando no hay foto.
  final String icono;

  /// Dónde está la foto que sacó el taller: la ruta de un archivo en el
  /// teléfono (o, cuando esté el servidor, su dirección). En la base va
  /// solo esta referencia, no la imagen. Si es null, se dibuja el ícono.
  final String? foto;

  final List<Compatibilidad> compatibles;

  /// Es un repuesto usado: hay UNO solo. Cuando se compra, deja de
  /// estar a la venta.
  bool vendida;

  /// El taller la sacó de la venta por un tiempo (por ejemplo, la está
  /// mostrando en el local). Se puede volver a publicar.
  bool pausada;

  /// El taller la borró. No se borra de verdad: los pedidos viejos la
  /// siguen nombrando. Solo deja de verse.
  bool borrada;

  /// Lo único que ve el comprador en el catálogo.
  bool get aLaVenta => !vendida && !pausada && !borrada;

  Pieza({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.precio,
    required this.estado,
    required this.taller,
    required this.icono,
    required this.compatibles,
    this.foto,
    this.vendida = false,
    this.pausada = false,
    this.borrada = false,
  });

  bool sirvePara(Auto auto) => compatibles.any((c) => c.sirvePara(auto));

  /// Traduce el dato crudo del servicio a una Pieza, con el taller ya
  /// resuelto por el repositorio.
  factory Pieza.desdeJson(Map<String, dynamic> json, Taller taller) => Pieza(
    id: json['id'] as String,
    titulo: json['titulo'] as String,
    descripcion: json['descripcion'] as String,
    precio: json['precio'] as int,
    estado: json['estado'] == 'reacondicionado'
        ? EstadoPieza.reacondicionado
        : EstadoPieza.usado,
    taller: taller,
    icono: json['icono'] as String,
    compatibles: (json['compatibles'] as List)
        .map((c) => Compatibilidad.desdeJson(c as Map<String, dynamic>))
        .toList(),
    foto: json['foto'] as String?,
    vendida: json['vendida'] == true,
    pausada: json['pausada'] == true,
    borrada: json['borrada'] == true,
  );
}
