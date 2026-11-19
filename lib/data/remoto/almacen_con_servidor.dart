import 'dart:async';

import '../local/almacen_local.dart';
import '../local/fotos_locales.dart';
import 'base_remota.dart';

// =====================================================================
// LA BASE CON SERVIDOR.
//
// Cumple el MISMO contrato que la base local (AlmacenLocal), así que
// los servicios, los repositorios y las pantallas no cambian ni una
// línea: en dependencias se le pasa esta en vez de la local, y listo.
//
// Por dentro hace dos cosas con cada dato:
//   · GUARDAR: primero en el teléfono, después en el servidor. La subida
//     no se espera: si no hay señal, Firestore la deja en cola y la manda
//     sola cuando vuelve. Por eso la app no se traba sin internet.
//   · LEER: junta lo del teléfono con lo del servidor. Si el mismo dato
//     está en los dos, gana el del servidor, que es el que comparten
//     todos los teléfonos.
//
// Qué va al servidor y qué no:
//   · piezas, pedidos y cuentas: SÍ, son de todos.
//   · avisos de la campanita: NO, son de cada teléfono.
//   · lista de autos: NO, es la misma para todos y viene con la app.
// =====================================================================
class AlmacenConServidor implements AlmacenLocal {
  AlmacenConServidor({
    required AlmacenLocal local,
    required BaseRemota remota,
    FotosLocales fotos = const FotosLocales(),
    Duration limite = const Duration(seconds: 6),
  }) : _local = local,
       _remota = remota,
       _fotos = fotos,
       _limite = limite;

  final AlmacenLocal _local;
  final BaseRemota _remota;
  final FotosLocales _fotos;

  /// Cuánto esperar al servidor antes de seguir con lo del teléfono.
  final Duration _limite;

  @override
  String get nombre => '${_local.nombre} + servidor (Firebase)';

  @override
  Future<void> abrir() => _local.abrir();

  // --- Autos: solo en el teléfono ---

  @override
  Future<List<Map<String, dynamic>>> leerVehiculos() => _local.leerVehiculos();

  @override
  Future<void> guardarVehiculos(List<Map<String, dynamic>> vehiculos) =>
      _local.guardarVehiculos(vehiculos);

  // --- Piezas ---

  @override
  Future<List<Map<String, dynamic>>> leerPiezas() async =>
      _juntar(await _local.leerPiezas(), await _delServidor('piezas'), 'id');

  @override
  Future<void> guardarPieza(Map<String, dynamic> pieza) async {
    await _local.guardarPieza(pieza);
    // La foto viaja como texto adentro de la pieza: en el teléfono queda
    // la ruta del archivo, pero los otros teléfonos no tienen ese archivo.
    final paraSubir = {
      ...pieza,
      'foto': await _fotos.comoTexto(pieza['foto'] as String?),
    };
    _subir('piezas', pieza['id'] as String, paraSubir);
  }

  @override
  Stream<List<Map<String, dynamic>>> piezasDelServidor() => _escuchar('piezas');

  // --- Cuentas: un documento por cuenta, con su tipo adentro ---

  @override
  Future<List<Map<String, dynamic>>> leerCuentas(String tipo) async => _juntar(
    await _local.leerCuentas(tipo),
    await _delServidor('cuentas', campo: 'tipo', igualA: tipo),
    'id',
  );

  @override
  Future<void> guardarCuenta(
    String tipo,
    String id,
    Map<String, dynamic> dato,
  ) async {
    await _local.guardarCuenta(tipo, id, dato);
    // Las huellas de las claves NO suben: las contraseñas las valida
    // Firebase Authentication, y las reglas no dejan escribirlas.
    if (tipo == 'claves') return;
    _subir('cuentas', '$tipo-$id', {...dato, 'id': id, 'tipo': tipo});
  }

  // --- Pedidos ---

  @override
  Future<List<Map<String, dynamic>>> leerPedidos() async => _juntar(
    await _local.leerPedidos(),
    await _delServidor('pedidos'),
    'numero',
  );

  @override
  Future<void> guardarPedido(Map<String, dynamic> pedido) async {
    await _local.guardarPedido(pedido);
    final numero = (pedido['numero'] as String).replaceAll('#', '');
    _subir('pedidos', numero, pedido);
  }

  @override
  Stream<List<Map<String, dynamic>>> pedidosDelServidor() =>
      _escuchar('pedidos');

  /// El número lo da el servidor (una transacción sobre un contador).
  /// Sin señal, null: lo saca el teléfono.
  @override
  Future<int?> numeroDePedidoDelServidor(int minimo) async {
    try {
      return await _remota
          .siguienteNumero('pedidos', minimo: minimo)
          .timeout(_limite);
    } catch (_) {
      return null;
    }
  }

  // --- Avisos: solo en el teléfono ---

  @override
  Future<List<Map<String, dynamic>>> leerAvisos() => _local.leerAvisos();

  @override
  Future<void> guardarAviso(Map<String, dynamic> aviso) =>
      _local.guardarAviso(aviso);

  // --- Cómo habla con el servidor ---

  /// Lee del servidor, con tiempo límite. Si no contesta (sin señal, sin
  /// configurar), devuelve vacío y la app sigue con lo del teléfono.
  Future<List<Map<String, dynamic>>> _delServidor(
    String coleccion, {
    String? campo,
    Object? igualA,
  }) async {
    try {
      return await _remota
          .leer(coleccion, campo: campo, igualA: igualA)
          .timeout(_limite);
    } catch (_) {
      return const [];
    }
  }

  /// Sube sin esperar. Un error de red no le llega al usuario: el dato
  /// ya quedó guardado en el teléfono.
  void _subir(String coleccion, String id, Map<String, dynamic> dato) {
    unawaited(_remota.guardar(coleccion, id, dato).catchError((_) {}));
  }

  /// Escucha una colección. Si el servidor tira un error, se ignora: el
  /// Stream sigue vivo y la app sigue con lo que tiene.
  Stream<List<Map<String, dynamic>>> _escuchar(String coleccion) =>
      _remota.escuchar(coleccion).handleError((_) {});

  /// Junta dos listas por una clave. Gana la segunda (la del servidor).
  static List<Map<String, dynamic>> _juntar(
    List<Map<String, dynamic>> delTelefono,
    List<Map<String, dynamic>> delServidor,
    String clave,
  ) {
    final porClave = <String, Map<String, dynamic>>{
      for (final dato in delTelefono) dato[clave] as String: dato,
    };
    for (final dato in delServidor) {
      porClave[dato[clave] as String] = dato;
    }
    return porClave.values.toList();
  }
}
