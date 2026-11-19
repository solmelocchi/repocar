import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../data/remoto/conectar_servidor.dart';
import '../data/repositories/notificaciones_repository.dart';
import '../data/services/notificaciones_service.dart';
import '../data/services/pedidos_service.dart';
import '../domain/cuit.dart';
import '../domain/politica_de_avisos.dart';
import 'capacidades.dart';

// =====================================================================
// SEGUNDO PLANO: revisar los pedidos del taller CON LA APP CERRADA.
//
// Con la app cerrada no corre nada nuestro: manda el sistema operativo.
// Con WorkManager le PEDIMOS (no le ordenamos) que cada tanto corra una
// función. Android puede demorarla (modo Doze, batería baja), y nunca la
// corre más seguido que cada 15 minutos.
//
// Un isolate (compute) NO sirve para esto: muere con la app.
// =====================================================================

const _nombreTarea = 'revisar-pedidos-sin-despachar';

/// En preferencias queda qué taller usa este teléfono. La tarea corre
/// en OTRO isolate, sin la app: no ve ninguna variable nuestra, así que
/// tiene que leer todo de lo que quedó guardado.
const _claveTaller = 'taller_en_este_telefono';

/// Hasta qué momento el taller ya está al tanto de sus pedidos: o los vio
/// en la app (se anota cuando la app deja de verse) o ya se le avisó
/// desde acá. Así cada pedido nuevo se avisa UNA sola vez, y no cada
/// 15 minutos.
const _claveAlTantoHasta = 'pedidos_al_tanto_hasta';

/// La puerta de entrada que busca el sistema. Tiene que ser una función
/// de nivel superior, y el @pragma evita que el compilador la borre en
/// la versión de release (nadie la llama desde nuestro código: la llama
/// el sistema por su nombre).
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((tarea, datos) async {
    try {
      final preferencias = SharedPreferencesAsync();
      final cuit = await preferencias.getString(_claveTaller);
      if (cuit == null) return true; // nadie con sesión de taller

      final textoDesde = await preferencias.getString(_claveAlTantoHasta);
      final desde = textoDesde == null
          ? DateTime.now()
          : DateTime.parse(textoDesde);

      // Con el servidor: así ve también los pedidos que hicieron desde
      // otros teléfonos mientras la app estaba cerrada.
      final almacen = (await conectarServidor()).almacen;
      final servicio = PedidosService(almacen: almacen, demora: Duration.zero);
      final nuevos = await pedidosNuevos(servicio, cuit, desde: desde);
      if (nuevos.isEmpty) return true;

      // Se avisa por el mismo repositorio que usa la app: queda en la
      // campanita y, si hay permiso, sale la notificación del sistema.
      final avisos = NotificacionesRepository(
        servicio: NotificacionesDelSistema(),
        capacidades: const Capacidades(),
        almacen: almacen,
      );
      await avisos.iniciar();
      await avisos.avisar(
        para: formatearCuit(cuit),
        titulo: tituloDeNuevos(nuevos),
        texto: textoDeNuevos(nuevos),
        payload: 'pedidos-nuevos',
      );

      // Ya se le avisó de estos: la próxima vez, solo los que lleguen
      // después del más nuevo.
      await preferencias.setString(
        _claveAlTantoHasta,
        nuevos.last['fecha'] as String,
      );
      return true;
    } catch (_) {
      // false = falló por algo pasajero: el sistema reintenta más tarde.
      return false;
    }
  });
}

/// "Pedido nuevo #2003" si es uno; "3 pedidos nuevos" si son varios.
String tituloDeNuevos(List<Map<String, dynamic>> nuevos) => nuevos.length == 1
    ? 'Pedido nuevo ${nuevos.single['numero']}'
    : '${nuevos.length} pedidos nuevos';

/// Uno: "Sol Melocchi te hizo un pedido". Varios: un renglón por pedido,
/// "#2003 – Sol Melocchi te hizo un pedido".
String textoDeNuevos(List<Map<String, dynamic>> nuevos) => nuevos.length == 1
    ? '${nuevos.single['cliente']} te hizo un pedido'
    : [
        for (final pedido in nuevos)
          '${pedido['numero']} – ${pedido['cliente']} te hizo un pedido',
      ].join('\n');

/// Los pedidos del taller que llegaron después de [desde], del más viejo
/// al más nuevo. Es una función aparte para poder probarla sin WorkManager.
/// Los de ejemplo no tienen fecha (son de "hace N días"): nunca son nuevos.
Future<List<Map<String, dynamic>>> pedidosNuevos(
  PedidosService servicio,
  String cuit, {
  required DateTime desde,
}) async {
  final pedidos = await servicio.obtenerPedidos();
  final nuevos = pedidos.where((p) {
    if (soloNumeros(p['taller_cuit'] as String) != soloNumeros(cuit)) {
      return false;
    }
    final fecha = DateTime.tryParse(p['fecha'] as String? ?? '');
    return fecha != null && fecha.isAfter(desde);
  }).toList();
  nuevos.sort((a, b) => (a['fecha'] as String).compareTo(b['fecha'] as String));
  return nuevos;
}

/// Lo que usa la app (desde dependencias.dart) para prender y apagar la
/// tarea según quién inicia sesión.
class SegundoPlano {
  SegundoPlano({
    required Capacidades capacidades,
    SharedPreferencesAsync? preferencias,
  }) : _capacidades = capacidades,
       _preferencias = preferencias;

  final Capacidades _capacidades;
  SharedPreferencesAsync? _preferencias;

  SharedPreferencesAsync get _prefs =>
      _preferencias ??= SharedPreferencesAsync();

  /// Se llama una vez en main(), antes de runApp.
  Future<void> iniciar() async {
    if (!_capacidades.correTareasDeFondo) return;
    await Workmanager().initialize(callbackDispatcher);
  }

  /// Entró un taller: desde ahora se revisan SUS pedidos. Si el sistema
  /// no acepta el pedido, la app sigue igual: el segundo plano es un
  /// extra, no algo de lo que dependa.
  Future<void> seguirPedidosDe(String cuit) async {
    if (!_capacidades.correTareasDeFondo) return;
    try {
      await _registrar(cuit);
    } catch (_) {}
  }

  /// El taller está al tanto de todo lo que llegó hasta ahora. Se llama
  /// cuando la app deja de verse (onHide) con un taller adentro: lo que
  /// llegó mientras miraba la app ya lo vio (le avisó la app misma).
  Future<void> marcarAlTanto() async {
    if (!_capacidades.correTareasDeFondo) return;
    try {
      await _prefs.setString(
        _claveAlTantoHasta,
        DateTime.now().toIso8601String(),
      );
    } catch (_) {}
  }

  Future<void> _registrar(String cuit) async {
    await _prefs.setString(_claveTaller, cuit);
    // Lo de antes de entrar no es "nuevo": se avisa desde ahora.
    await _prefs.setString(
      _claveAlTantoHasta,
      DateTime.now().toIso8601String(),
    );
    await Workmanager().registerPeriodicTask(
      _nombreTarea,
      _nombreTarea,
      frequency: PoliticaDeAvisos.revisarPedidosCada,
      // Las RESTRICCIONES: correr solo si hay red y la batería no está
      // baja. Así se resuelve "hacelo cuando vuelva la señal" sin tener
      // que escuchar la conectividad. (Hoy revisa la base local; cuando
      // esté el servidor, va a necesitar la red para bajar los pedidos.)
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    );
  }

  /// Salió: la tarea se cancela y se olvida el taller.
  Future<void> dejarDeSeguir() async {
    if (!_capacidades.correTareasDeFondo) return;
    try {
      await _prefs.remove(_claveTaller);
      await _prefs.remove(_claveAlTantoHasta);
      await Workmanager().cancelByUniqueName(_nombreTarea);
    } catch (_) {}
  }
}
