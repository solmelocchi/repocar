import '../local/almacen_local.dart';
import 'cuentas_service.dart';

// =====================================================================
// SERVICIO: las publicaciones de los talleres.
// Devuelve el dato crudo: el taller viene como CUIT y el ícono como
// texto, igual que llegaría en un JSON. Quien arma los objetos de
// verdad es el repositorio.
// =====================================================================
class CatalogoService {
  CatalogoService({
    required AlmacenLocal almacen,
    Duration demora = const Duration(milliseconds: 500),
  }) : _almacen = almacen,
       _demora = demora;

  final AlmacenLocal _almacen;
  final Duration _demora;

  /// Las de ejemplo vienen con la app; lo que se publicó o se vendió
  /// sale de la BASE LOCAL. Si una pieza de ejemplo
  /// tiene una versión guardada (porque se vendió, por ejemplo), gana
  /// la guardada.
  Future<List<Map<String, dynamic>>> obtenerPiezas() async {
    await Future.delayed(_demora);
    await _almacen.abrir();

    final porId = {
      for (final pieza in _deEjemplo) pieza['id'] as String: pieza,
    };
    for (final guardada in await _almacen.leerPiezas()) {
      porId[guardada['id'] as String] = guardada;
    }
    return porId.values.toList();
  }

  /// Sirve para publicar una pieza y para marcarla vendida.
  Future<void> guardar(Map<String, dynamic> pieza) async {
    await _almacen.guardarPieza(pieza);
  }

  /// Las piezas que cambian en el servidor (las publica otro taller, se
  /// venden en otro teléfono...), a medida que pasa.
  Stream<List<Map<String, dynamic>>> cambiosDelServidor() =>
      _almacen.piezasDelServidor();

  static const _usado = 'usado';
  static const _reacondicionado = 'reacondicionado';

  /// Arma una publicación. La compatibilidad se escribe corta
  /// (marca, modelo, desde, hasta) y acá se expande al formato del JSON.
  static Map<String, dynamic> _pieza(
    String id,
    String titulo,
    int precio,
    String estado,
    String cuit,
    String icono,
    String descripcion,
    List<List<Object>> compatibles,
  ) => {
    'id': id,
    'titulo': titulo,
    'descripcion': descripcion,
    'precio': precio,
    'estado': estado,
    'taller_cuit': cuit,
    'icono': icono,
    'compatibles': [
      for (final c in compatibles)
        {'marca': c[0], 'modelo': c[1], 'desde': c[2], 'hasta': c[3]},
    ],
  };

  static final List<Map<String, dynamic>> _deEjemplo = [
    _pieza(
      'p1',
      'Alternador Bosch 90A',
      185000,
      _reacondicionado,
      cuitRamallo,
      'electric_bolt',
      'Alternador reacondicionado, con rulemanes y carbones nuevos. '
          'Probado en banco. Garantía de 90 días por escrito.',
      [
        ['Volkswagen', 'Gol Trend', 2008, 2016],
        ['Chevrolet', 'Corsa Classic', 2004, 2013],
      ],
    ),
    _pieza(
      'p2',
      'Juego de pastillas de freno delanteras',
      42000,
      _usado,
      cuitElTorno,
      'album',
      'Pastillas usadas con 70% de material. Se sacaron de una unidad '
          'con 40.000 km. Incluye las cuatro.',
      [
        ['Volkswagen', 'Gol Trend', 2008, 2016],
        ['Ford', 'Fiesta Kinetic', 2011, 2019],
      ],
    ),
    _pieza(
      'p3',
      'Amortiguador trasero derecho',
      76500,
      _usado,
      cuitRamallo,
      'compress',
      'Amortiguador usado, sin pérdidas de aceite. Se entrega limpio y '
          'probado. Retira en el taller o coordinamos cadete.',
      [
        ['Volkswagen', 'Gol Trend', 2010, 2016],
      ],
    ),
    _pieza(
      'p4',
      'Caja de dirección reacondicionada',
      320000,
      _reacondicionado,
      cuitNahuel,
      'settings',
      'Caja de dirección con kit de reparación nuevo. Sin juego. '
          'Garantía de 6 meses.',
      [
        ['Toyota', 'Hilux', 2012, 2020],
        ['Ford', 'Ranger', 2012, 2020],
      ],
    ),
    _pieza(
      'p5',
      'Farol delantero izquierdo',
      98000,
      _usado,
      cuitElTorno,
      'lightbulb',
      'Óptica usada en buen estado, sin rajaduras. El plástico está un '
          'poco opaco, se puede pulir.',
      [
        ['Chevrolet', 'Corsa Classic', 2000, 2013],
        ['Renault', 'Clio Mío', 2004, 2016],
      ],
    ),
    _pieza(
      'p6',
      'Bomba de agua',
      64000,
      _reacondicionado,
      cuitNahuel,
      'water_drop',
      'Bomba de agua reacondicionada con sello nuevo. Probada sin '
          'pérdidas.',
      [
        ['Peugeot', '208', 2013, 2022],
        ['Fiat', 'Cronos', 2018, 2024],
        ['Renault', 'Clio Mío', 2008, 2016],
      ],
    ),
    _pieza(
      'p7',
      'Radiador con electroventilador',
      145000,
      _usado,
      cuitRamallo,
      'ac_unit',
      'Radiador usado, sin pinchaduras, probado a presión. Incluye el '
          'electroventilador funcionando.',
      [
        ['Volkswagen', 'Gol Trend', 2008, 2016],
        ['Toyota', 'Etios', 2013, 2023],
      ],
    ),
    _pieza(
      'p8',
      'Espejo retrovisor exterior derecho',
      55000,
      _usado,
      cuitElTorno,
      'flip',
      'Espejo eléctrico usado, con el vidrio en perfecto estado.',
      [
        ['Chevrolet', 'Onix', 2016, 2024],
        ['Fiat', 'Cronos', 2018, 2024],
      ],
    ),
    _pieza(
      'p9',
      'Turbo Garrett reacondicionado',
      680000,
      _reacondicionado,
      cuitTurbo,
      'settings',
      'Turbo con eje y cojinetes nuevos, balanceado en banco. '
          'Garantía de 6 meses contra defectos.',
      [
        ['Toyota', 'Hilux', 2012, 2020],
        ['Ford', 'Ranger', 2012, 2022],
        ['Chevrolet', 'S10', 2012, 2023],
      ],
    ),
    _pieza(
      'p10',
      'Inyector diesel',
      95000,
      _reacondicionado,
      cuitTurbo,
      'water_drop',
      'Inyector probado en banco, con caudal dentro de tolerancia. '
          'Se entrega con el informe de prueba.',
      [
        ['Toyota', 'Hilux', 2012, 2020],
        ['Chevrolet', 'S10', 2012, 2023],
      ],
    ),
    _pieza(
      'p11',
      'Bomba de combustible eléctrica',
      72000,
      _usado,
      cuitSanRafael,
      'water_drop',
      'Bomba usada, probada con presión correcta. Incluye el filtro '
          'de malla nuevo.',
      [
        ['Volkswagen', 'Gol Trend', 2008, 2016],
        ['Volkswagen', 'Suran', 2006, 2019],
      ],
    ),
    _pieza(
      'p12',
      'Caja de cambios completa',
      950000,
      _reacondicionado,
      cuitNahuel,
      'settings',
      'Caja de cinco marchas abierta, con sincros y rulemanes nuevos. '
          'Probada en banco. Garantía de 6 meses.',
      [
        ['Chevrolet', 'Corsa Classic', 2000, 2013],
      ],
    ),
    _pieza(
      'p13',
      'Kit de embrague completo',
      185000,
      _reacondicionado,
      cuitSanRafael,
      'album',
      'Plato, disco y rulemán. El volante se entrega rectificado.',
      [
        ['Ford', 'Fiesta Kinetic', 2011, 2019],
        ['Ford', 'Ka', 2016, 2021],
      ],
    ),
    _pieza(
      'p14',
      'Rueda de auxilio con cubierta',
      38000,
      _usado,
      cuitLaEsquina,
      'album',
      'Llanta de chapa con cubierta al 60%. Para emergencia anda '
          'perfecto.',
      [
        ['Fiat', 'Palio', 2004, 2017],
      ],
    ),
    _pieza(
      'p15',
      'Paragolpes delantero',
      125000,
      _usado,
      cuitElGringo,
      'flip',
      'Sin roturas, con las grampas completas. Tiene un raspón que se '
          'tapa con pintura.',
      [
        ['Chevrolet', 'Onix', 2016, 2024],
      ],
    ),
    _pieza(
      'p16',
      'Capot',
      210000,
      _usado,
      cuitElGringo,
      'flip',
      'Capot derecho de chapa, sin óxido, con la insonorización '
          'puesta.',
      [
        ['Chevrolet', 'Corsa Classic', 2000, 2013],
      ],
    ),
    _pieza(
      'p17',
      'Puerta delantera izquierda',
      265000,
      _usado,
      cuitElGringo,
      'flip',
      'Puerta completa con vidrio, manija y alzacristal eléctrico '
          'funcionando.',
      [
        ['Volkswagen', 'Gol Trend', 2008, 2016],
      ],
    ),
    _pieza(
      'p18',
      'Bobina de encendido',
      48000,
      _reacondicionado,
      cuitSanRafael,
      'electric_bolt',
      'Bobina probada con osciloscopio, sin fugas. Garantía de 90 '
          'días.',
      [
        ['Fiat', 'Cronos', 2018, 2024],
        ['Fiat', 'Palio', 2004, 2017],
      ],
    ),
    _pieza(
      'p19',
      'Motor de arranque',
      155000,
      _reacondicionado,
      cuitRamallo,
      'electric_bolt',
      'Arranque con bendix y carbones nuevos, probado en banco.',
      [
        ['Renault', 'Clio Mío', 2000, 2016],
        ['Renault', 'Kangoo', 2008, 2018],
      ],
    ),
    _pieza(
      'p20',
      'Batería 12V 65Ah',
      135000,
      _usado,
      cuitLaEsquina,
      'electric_bolt',
      'Batería con ocho meses de uso, probada con 12,6V en reposo.',
      [
        ['Renault', 'Sandero', 2008, 2022],
        ['Renault', 'Duster', 2012, 2022],
      ],
    ),
    _pieza(
      'p21',
      'Discos de freno delanteros (par)',
      88000,
      _reacondicionado,
      cuitElTorno,
      'album',
      'Discos rectificados, dentro de la medida mínima de fábrica.',
      [
        ['Toyota', 'Corolla', 2014, 2023],
        ['Toyota', 'Etios', 2013, 2023],
      ],
    ),
    _pieza(
      'p22',
      'Amortiguadores delanteros (par)',
      198000,
      _reacondicionado,
      cuitNahuel,
      'compress',
      'Par de amortiguadores con vástagos nuevos, probados en banco.',
      [
        ['Ford', 'Ranger', 2012, 2022],
      ],
    ),
    _pieza(
      'p23',
      'Espiral de suspensión trasero',
      52000,
      _usado,
      cuitLaEsquina,
      'compress',
      'Espiral sin vencer, medido contra uno nuevo. Se vende por '
          'unidad.',
      [
        ['Peugeot', '208', 2013, 2022],
      ],
    ),
    _pieza(
      'p24',
      'Parrilla de suspensión derecha',
      67000,
      _usado,
      cuitSanRafael,
      'compress',
      'Parrilla con bujes y rótula en buen estado, sin juego.',
      [
        ['Volkswagen', 'Suran', 2006, 2019],
        ['Volkswagen', 'Gol Trend', 2008, 2016],
      ],
    ),
    _pieza(
      'p25',
      'Radiador de calefacción',
      59000,
      _usado,
      cuitRamallo,
      'ac_unit',
      'Probado a presión, sin pérdidas. Se entrega lavado por dentro.',
      [
        ['Renault', 'Kangoo', 2008, 2018],
      ],
    ),
    _pieza(
      'p26',
      'Compresor de aire acondicionado',
      240000,
      _reacondicionado,
      cuitTurbo,
      'ac_unit',
      'Compresor con reten nuevo, cargado con aceite. Probado en '
          'banco con presión.',
      [
        ['Toyota', 'Hilux', 2012, 2020],
        ['Toyota', 'Corolla', 2014, 2023],
      ],
    ),
    _pieza(
      'p27',
      'Electroventilador',
      82000,
      _usado,
      cuitElTorno,
      'ac_unit',
      'Motor del ventilador andando, con la tulipa sin fisuras.',
      [
        ['Ford', 'Fiesta Kinetic', 2011, 2019],
        ['Ford', 'EcoSport', 2013, 2021],
      ],
    ),
    _pieza(
      'p28',
      'Óptica trasera derecha',
      76000,
      _usado,
      cuitElGringo,
      'lightbulb',
      'Sin rajaduras, con los portalámparas completos.',
      [
        ['Volkswagen', 'Polo', 2017, 2024],
      ],
    ),
    _pieza(
      'p29',
      'Faro antiniebla',
      34000,
      _usado,
      cuitLaEsquina,
      'lightbulb',
      'Par de faros con el vidrio sano y la ficha original.',
      [
        ['Renault', 'Duster', 2012, 2022],
      ],
    ),
    _pieza(
      'p30',
      'Tablero de instrumentos',
      190000,
      _usado,
      cuitSanRafael,
      'settings',
      'Tablero completo, con todas las luces testigo funcionando. '
          'Se entrega con el kilometraje original.',
      [
        ['Chevrolet', 'Prisma', 2013, 2019],
        ['Chevrolet', 'Onix', 2016, 2024],
      ],
    ),
    _pieza(
      'p31',
      'Caja de dirección hidráulica',
      285000,
      _reacondicionado,
      cuitTurbo,
      'settings',
      'Reparada con kit nuevo y probada con bomba. Sin pérdidas.',
      [
        ['Chevrolet', 'S10', 2012, 2023],
      ],
    ),
    _pieza(
      'p32',
      'Cardán trasero',
      320000,
      _usado,
      cuitNahuel,
      'build',
      'Cardán con crucetas nuevas, balanceado. Sin vibración.',
      [
        ['Fiat', 'Toro', 2016, 2024],
        ['Ford', 'Ranger', 2012, 2022],
      ],
    ),
  ];
}
