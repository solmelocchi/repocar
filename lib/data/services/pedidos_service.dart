import '../local/almacen_local.dart';
import 'cuentas_service.dart';

// =====================================================================
// SERVICIO: los pedidos.
// Igual que los otros: devuelve crudo. Los items vienen como id de
// pieza y el taller como CUIT, porque así llegaría de un servidor.
//
// Junta dos fuentes, como el catálogo: los pedidos de ejemplo, que
// vienen con la app, y los que se hicieron o cambiaron en este
// teléfono, que salen de la BASE LOCAL. Si un pedido de ejemplo tiene
// una versión guardada (porque el taller lo marcó entregado, por
// ejemplo), gana la guardada.
// =====================================================================
class PedidosService {
  PedidosService({
    required AlmacenLocal almacen,
    Duration demora = const Duration(milliseconds: 400),
  }) : _almacen = almacen,
       _demora = demora;

  final AlmacenLocal _almacen;
  final Duration _demora;

  Future<List<Map<String, dynamic>>> obtenerPedidos() async {
    await Future.delayed(_demora);
    await _almacen.abrir();

    final porNumero = {
      for (final pedido in _deEjemplo) pedido['numero'] as String: pedido,
    };
    for (final guardado in await _almacen.leerPedidos()) {
      porNumero[guardado['numero'] as String] = guardado;
    }
    return porNumero.values.toList();
  }

  /// Guarda un pedido nuevo o la versión nueva de uno que cambió.
  Future<void> guardar(Map<String, dynamic> pedido) =>
      _almacen.guardarPedido(pedido);

  /// Los pedidos que cambian en el servidor, a medida que pasa: el que
  /// hizo un comprador desde su celular, el que marcó entregado el taller.
  Stream<List<Map<String, dynamic>>> cambiosDelServidor() =>
      _almacen.pedidosDelServidor();

  /// El número del próximo pedido según el servidor (null sin servidor).
  Future<int?> numeroDelServidor(int minimo) =>
      _almacen.numeroDePedidoDelServidor(minimo);

  static Map<String, dynamic> _pedido(
    String numero,
    int diasAtras,
    String cliente,
    String cuit,
    List<String> piezas,
    String entrega,
    int costoEnvio,
    double comision,
    String estado, {
    String direccion = '',
    int estrellas = 0,
    String comentario = '',
    String? respuesta,
  }) => {
    'numero': numero,
    'dias_atras': diasAtras,
    'cliente': cliente,
    'taller_cuit': cuit,
    'items': [
      for (final pieza in piezas) {'pieza_id': pieza, 'cantidad': 1},
    ],
    'entrega': entrega,
    'direccion': direccion,
    'costo_envio': costoEnvio,
    'comision_pct': comision,
    'estado': estado,
    'calificacion': estrellas == 0
        ? null
        : {
            'estrellas': estrellas,
            'comentario': comentario,
            'respuesta': respuesta,
          },
  };

  static final List<Map<String, dynamic>> _deEjemplo = [
    _pedido(
      '#1041',
      21,
      'Rubén Ledesma',
      cuitNahuel,
      ['p4'],
      'retiro',
      0,
      0.08,
      'entregado',
      estrellas: 2,
      comentario: 'La caja me vino con juego, tuve que volver al taller.',
      respuesta:
          'Rubén, la caja salió probada. La revisamos sin cargo y '
          'quedó andando. Cualquier cosa escribinos.',
    ),
    _pedido(
      '#1042',
      12,
      'Martín Suárez',
      cuitRamallo,
      ['p1'],
      'cadete',
      3500,
      0.10,
      'entregado',
      direccion: 'Av. Mitre 1240',
      estrellas: 5,
      comentario: 'Impecable, me lo mandaron el mismo día.',
    ),
    _pedido(
      '#1043',
      5,
      'Carla Peña',
      cuitRamallo,
      ['p7'],
      'envio',
      5400,
      0.10,
      'enviado',
      direccion: 'Los Álamos 318',
    ),
    _pedido(
      '#1044',
      2,
      'Diego Funes',
      cuitElTorno,
      ['p2', 'p5'],
      'envio',
      3800,
      0.10,
      'pagado',
      direccion: 'San Martín 77',
    ),
    _pedido(
      '#1045',
      26,
      'Jorge Robledo',
      cuitTurbo,
      ['p9'],
      'retiro',
      0,
      0.12,
      'entregado',
      estrellas: 5,
      comentario: 'El turbo anda perfecto, me explicaron todo el trabajo.',
    ),
    _pedido(
      '#1046',
      18,
      'Andrea Bustos',
      cuitSanRafael,
      ['p13'],
      'cadete',
      3200,
      0.10,
      'entregado',
      direccion: 'Belgrano 455',
      estrellas: 4,
      comentario: 'Todo bien, tardó un día más de lo que me dijeron.',
    ),
    _pedido(
      '#1047',
      15,
      'Nicolás Vega',
      cuitElGringo,
      ['p17'],
      'envio',
      6900,
      0.10,
      'entregado',
      direccion: 'Chile 2210',
      estrellas: 3,
      comentario: 'La puerta vino con un golpe que no se veía en la foto.',
      respuesta:
          'Nicolás, era el raspón que figuraba en la descripción. '
          'Igual te hacemos un descuento en la próxima.',
    ),
    _pedido(
      '#1048',
      8,
      'Laura Giménez',
      cuitLaEsquina,
      ['p20'],
      'envio',
      11500,
      0.08,
      'enviado',
      direccion: 'Ruta 143 km 4',
    ),
    _pedido(
      '#1049',
      3,
      'Pablo Ferreyra',
      cuitTurbo,
      ['p26'],
      'retiro',
      0,
      0.12,
      'pagado',
    ),
    _pedido(
      '#1050',
      10,
      'Marcela Díaz',
      cuitNahuel,
      ['p22'],
      'cadete',
      4000,
      0.08,
      'entregado',
      direccion: 'Pellegrini 980',
      estrellas: 5,
      comentario: 'Los amortiguadores quedaron como nuevos.',
    ),
  ];
}
