import 'almacen_local.dart';

AlmacenLocal crearAlmacen() => AlmacenEnMemoria();

// =====================================================================
// La misma base, pero en memoria.
//
// Se usa en los tests, que así no dejan archivos dando vueltas. Cumple
// el mismo contrato, así que los repositorios no cambian una línea.
// Igual que las otras, guardar dos veces algo con la misma clave lo
// reemplaza en vez de duplicarlo.
// =====================================================================
class AlmacenEnMemoria implements AlmacenLocal {
  @override
  String get nombre => 'memoria (no guarda nada al cerrar)';

  final List<Map<String, dynamic>> _vehiculos = [];
  final Map<String, Map<String, dynamic>> _piezas = {};
  final Map<String, Map<String, Map<String, dynamic>>> _cuentas = {};
  final Map<String, Map<String, dynamic>> _pedidos = {};
  final Map<String, Map<String, dynamic>> _avisos = {};

  @override
  Future<void> abrir() async {}

  @override
  Future<List<Map<String, dynamic>>> leerVehiculos() async =>
      List<Map<String, dynamic>>.from(_vehiculos);

  @override
  Future<void> guardarVehiculos(List<Map<String, dynamic>> vehiculos) async {
    _vehiculos
      ..clear()
      ..addAll(vehiculos);
  }

  @override
  Future<List<Map<String, dynamic>>> leerPiezas() async =>
      _piezas.values.toList();

  @override
  Future<void> guardarPieza(Map<String, dynamic> pieza) async {
    _piezas[pieza['id'] as String] = pieza;
  }

  @override
  Future<List<Map<String, dynamic>>> leerCuentas(String tipo) async =>
      (_cuentas[tipo] ?? {}).values.toList();

  @override
  Future<void> guardarCuenta(
    String tipo,
    String id,
    Map<String, dynamic> dato,
  ) async {
    (_cuentas[tipo] ??= {})[id] = dato;
  }

  @override
  Future<List<Map<String, dynamic>>> leerPedidos() async =>
      _pedidos.values.toList();

  @override
  Future<void> guardarPedido(Map<String, dynamic> pedido) async {
    _pedidos[pedido['numero'] as String] = pedido;
  }

  @override
  Future<List<Map<String, dynamic>>> leerAvisos() async =>
      _avisos.values.toList();

  @override
  Future<void> guardarAviso(Map<String, dynamic> aviso) async {
    _avisos[aviso['id'] as String] = aviso;
  }

  // No hay servidor: nunca llega nada de otro teléfono.
  @override
  Stream<List<Map<String, dynamic>>> piezasDelServidor() =>
      const Stream.empty();

  @override
  Stream<List<Map<String, dynamic>>> pedidosDelServidor() =>
      const Stream.empty();

  // No hay servidor: el número lo saca el teléfono.
  @override
  Future<int?> numeroDePedidoDelServidor(int minimo) async => null;
}
