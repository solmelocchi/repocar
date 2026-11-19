import '../../domain/models/auto.dart';
import '../../domain/models/envio.dart';
import '../local/almacen_local.dart';
import '../services/vehiculos_service.dart';
import '../services/vehiculos_service_http.dart';

// =====================================================================
// REPOSITORIO (capa de datos)
//
// Primero el CONTRATO: las capas de arriba piden "la lista de autos" y
// no se enteran de dónde sale.
// =====================================================================
abstract class VehiculosRepository {
  Future<List<ModeloVehiculo>> obtenerVehiculos();

  Future<List<ZonaEnvio>> obtenerZonas();
}

/// La implementación de verdad, con tres fuentes en orden:
///
///   1. la memoria, si ya se pidió en esta corrida;
///   2. la BASE LOCAL, si ya se bajó alguna vez (la app abre sin
///      internet y sin esperar);
///   3. la API, y si no se puede, la lista que viene con la app.
///
/// En los dos últimos casos lo que se consigue se guarda en la base,
/// así la próxima vez entra por el paso 2.
class VehiculosRepositoryConBase implements VehiculosRepository {
  VehiculosRepositoryConBase({
    required VehiculosService servicio,
    required VehiculosServiceHttp descarga,
    required AlmacenLocal almacen,
  }) : _servicio = servicio,
       _descarga = descarga,
       _almacen = almacen;

  final VehiculosService _servicio;
  final VehiculosServiceHttp _descarga;
  final AlmacenLocal _almacen;

  List<ModeloVehiculo>? _vehiculos;
  List<ZonaEnvio>? _zonas;

  /// De dónde salió la lista que está mostrando la app. Sirve para
  /// contarlo en pantalla y para los tests.
  String origen = 'sin cargar';

  @override
  Future<List<ModeloVehiculo>> obtenerVehiculos() async {
    final enCache = _vehiculos;
    if (enCache != null) return enCache;

    await _almacen.abrir();

    // 2. ¿Ya lo tenemos guardado de otra vez?
    final guardados = await _almacen.leerVehiculos();
    if (guardados.isNotEmpty) {
      origen = 'base local';
      return _vehiculos = guardados.map(ModeloVehiculo.desdeJson).toList();
    }

    // 3. Primera vez: se intenta bajar y, si no se puede, se usa la
    //    lista que viene con la app. En los dos casos se guarda.
    List<Map<String, dynamic>> crudos;
    try {
      crudos = await _descarga.descargar();
      origen = 'descarga';
    } catch (_) {
      crudos = await _servicio.obtenerVehiculos();
      origen = 'lista de la app';
    }

    await _almacen.guardarVehiculos(crudos);
    return _vehiculos = crudos.map(ModeloVehiculo.desdeJson).toList();
  }

  @override
  Future<List<ZonaEnvio>> obtenerZonas() async {
    final enCache = _zonas;
    if (enCache != null) return enCache;

    final crudas = await _servicio.obtenerZonas();
    return _zonas = crudas.map(ZonaEnvio.desdeJson).toList();
  }
}
