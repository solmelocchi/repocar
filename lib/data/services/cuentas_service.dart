import '../../domain/administracion.dart';

// =====================================================================
// SERVICIO: las cuentas, talleres y compradores.
// Las contraseñas vienen acá solo porque es un prototipo: en la app
// real nunca viajan al teléfono, se validan en el servidor.
// =====================================================================

/// Las zonas donde hay talleres. Lista fija del sistema, igual que la
/// de vehículos: nadie escribe su zona a mano.
const zonasDeTaller = [
  'San Rafael',
  'Cuadro Nacional',
  'Rama Caída',
  'Las Paredes',
  'Villa Atuel',
];

/// Los CUIT de los talleres de la red. Están acá arriba porque los
/// repuestos y los pedidos los referencian: así no hay números sueltos
/// repartidos por todos lados.
const cuitRamallo = '30-71234567-1';
const cuitElTorno = '20-12345678-6';
const cuitNahuel = '27-23456789-1';
const cuitSanRafael = '30-70987654-2';
const cuitElGringo = '27-30111222-5';
const cuitLaEsquina = '23-25888999-1';
const cuitTurbo = '33-69876543-2';

class CuentasService {
  const CuentasService({Duration demora = const Duration(milliseconds: 300)})
    : _demora = demora;

  final Duration _demora;

  Future<List<Map<String, dynamic>>> obtenerTalleres() async {
    await Future.delayed(_demora);
    return _talleres;
  }

  Future<List<Map<String, dynamic>>> obtenerClientes() async {
    await Future.delayed(_demora);
    return const [
      {
        'nombre': 'Sol Melocchi',
        'usuario': 'sol@gmail.com',
        'telefono': '+54 9 260 400-1122',
      },
      {
        'nombre': 'Martín Suárez',
        'usuario': 'martin.suarez@gmail.com',
        'telefono': '+54 9 260 433-9080',
      },
      {
        'nombre': 'Carla Peña',
        'usuario': 'carlapenia@gmail.com',
        'telefono': '+54 9 260 415-7744',
      },
      // La cuenta de TalleresYa: entra al panel de administración.
      {
        'nombre': 'TalleresYa',
        'usuario': correoAdministrador,
        'telefono': '+54 9 261 250-1757',
      },
    ];
  }

  /// La clave de cada cuenta, por usuario o por CUIT sin guiones.
  Future<Map<String, String>> obtenerClaves() async {
    await Future.delayed(_demora);
    return {
      'sol@gmail.com': '123456',
      'martin.suarez@gmail.com': '123456',
      'carlapenia@gmail.com': '123456',
      correoAdministrador: '123456',
      for (final taller in _talleres)
        (taller['cuit'] as String).replaceAll(RegExp(r'[^0-9]'), ''): '123456',
    };
  }

  static Map<String, dynamic> _taller(
    String nombre,
    String cuit,
    String telefono,
    String zona, {
    bool cadete = false,
    int costoCadete = 0,
    double comision = 0.10,
  }) => {
    'nombre': nombre,
    'cuit': cuit,
    'telefono': telefono,
    'zona': zona,
    'tiene_cadete': cadete,
    'costo_cadete': costoCadete,
    'comision': comision,
  };

  static final List<Map<String, dynamic>> _talleres = [
    _taller(
      'TalleresYa Ramallo',
      cuitRamallo,
      '+54 9 261 250-1757',
      'San Rafael',
      cadete: true,
      costoCadete: 3500,
    ),
    _taller(
      'Repuestos El Torno',
      cuitElTorno,
      '+54 9 261 250-1757',
      'Cuadro Nacional',
    ),
    _taller(
      'Auto Partes Nahuel',
      cuitNahuel,
      '+54 9 261 250-1757',
      'Rama Caída',
      cadete: true,
      costoCadete: 4000,
      comision: 0.08,
    ),
    _taller(
      'San Rafael Motors',
      cuitSanRafael,
      '+54 9 261 250-1757',
      'San Rafael',
      cadete: true,
      costoCadete: 3200,
    ),
    _taller(
      'Taller El Gringo',
      cuitElGringo,
      '+54 9 261 250-1757',
      'Las Paredes',
    ),
    _taller(
      'Repuestos La Esquina',
      cuitLaEsquina,
      '+54 9 261 250-1757',
      'Villa Atuel',
      comision: 0.08,
    ),
    _taller(
      'Turbo Diesel Sur',
      cuitTurbo,
      '+54 9 261 250-1757',
      'Cuadro Nacional',
      cadete: true,
      costoCadete: 4500,
      comision: 0.12,
    ),
  ];
}
