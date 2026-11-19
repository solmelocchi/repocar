// =====================================================================
// SERVICIO (capa de datos, la más baja)
// · Habla con el "exterior". Esta es la lista que viene con la app y se
//   usa la primera vez, si todavía no hay nada en la base local y no se
//   pudo bajar de ninguna API.
// · Devuelve los datos CRUDOS, como vendrían en un JSON.
// · No guarda nada entre llamadas.
// =====================================================================
class VehiculosService {
  const VehiculosService({Duration demora = const Duration(milliseconds: 400)})
    : _demora = demora;

  /// Simula lo que tarda la red.
  final Duration _demora;

  Future<List<Map<String, dynamic>>> obtenerVehiculos() async {
    await Future.delayed(_demora);
    return _modelos;
  }

  /// Las tarifas de la empresa de envíos, por zona.
  Future<List<Map<String, dynamic>>> obtenerZonas() async {
    await Future.delayed(_demora);
    return const [
      {'nombre': 'San Rafael centro', 'km': 5, 'tarifa': 3800},
      {'nombre': 'Cuadro Nacional', 'km': 12, 'tarifa': 5400},
      {'nombre': 'Rama Caída', 'km': 18, 'tarifa': 6900},
      {'nombre': 'Las Paredes', 'km': 25, 'tarifa': 8200},
      {'nombre': 'Villa Atuel', 'km': 42, 'tarifa': 11500},
    ];
  }

  /// Un modelo con los años en que se fabricó.
  static Map<String, dynamic> _auto(
    String marca,
    String modelo,
    int desde,
    int hasta,
  ) => {'marca': marca, 'modelo': modelo, 'desde': desde, 'hasta': hasta};

  static final List<Map<String, dynamic>> _modelos = [
    _auto('Volkswagen', 'Gol Trend', 2008, 2016),
    _auto('Volkswagen', 'Amarok', 2010, 2022),
    _auto('Volkswagen', 'Suran', 2006, 2019),
    _auto('Volkswagen', 'Polo', 2017, 2024),
    _auto('Chevrolet', 'Corsa Classic', 2000, 2013),
    _auto('Chevrolet', 'Onix', 2016, 2024),
    _auto('Chevrolet', 'Prisma', 2013, 2019),
    _auto('Chevrolet', 'S10', 2012, 2023),
    _auto('Ford', 'Fiesta Kinetic', 2011, 2019),
    _auto('Ford', 'Ranger', 2012, 2022),
    _auto('Ford', 'Ka', 2016, 2021),
    _auto('Ford', 'EcoSport', 2013, 2021),
    _auto('Renault', 'Clio Mío', 2000, 2016),
    _auto('Renault', 'Kangoo', 2008, 2018),
    _auto('Renault', 'Sandero', 2008, 2022),
    _auto('Renault', 'Duster', 2012, 2022),
    _auto('Toyota', 'Hilux', 2012, 2020),
    _auto('Toyota', 'Etios', 2013, 2023),
    _auto('Toyota', 'Corolla', 2014, 2023),
    _auto('Peugeot', '208', 2013, 2022),
    _auto('Peugeot', 'Partner', 2008, 2020),
    _auto('Fiat', 'Cronos', 2018, 2024),
    _auto('Fiat', 'Palio', 2004, 2017),
    _auto('Fiat', 'Toro', 2016, 2024),
  ];
}
