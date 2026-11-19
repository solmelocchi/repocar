import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'almacen_local.dart';

AlmacenLocal crearAlmacen() => AlmacenPreferencias();

// =====================================================================
// La base para el NAVEGADOR.
//
// sqflite no corre en web, pero igual hay que guardar: si el taller
// publica y recarga la página, su repuesto tiene que seguir estando.
// Acá los datos van al almacenamiento del navegador, guardados como
// texto JSON. Cumple el mismo contrato que la de SQLite.
// =====================================================================
class AlmacenPreferencias implements AlmacenLocal {
  static const _claveVehiculos = 'repocar.vehiculos';
  static const _clavePiezas = 'repocar.piezas';
  static const _clavePedidos = 'repocar.pedidos';
  static const _claveAvisos = 'repocar.avisos';

  SharedPreferences? _preferencias;

  @override
  String get nombre => 'almacenamiento del navegador';

  @override
  Future<void> abrir() async {
    _preferencias ??= await SharedPreferences.getInstance();
  }

  List<Map<String, dynamic>> _leer(String clave) {
    final texto = _preferencias?.getString(clave);
    if (texto == null || texto.isEmpty) return [];

    final lista = jsonDecode(texto) as List;
    return [for (final item in lista) Map<String, dynamic>.from(item as Map)];
  }

  Future<void> _escribir(String clave, List<Map<String, dynamic>> datos) async {
    await abrir();
    await _preferencias!.setString(clave, jsonEncode(datos));
  }

  @override
  Future<List<Map<String, dynamic>>> leerVehiculos() async {
    await abrir();
    return _leer(_claveVehiculos);
  }

  @override
  Future<void> guardarVehiculos(List<Map<String, dynamic>> vehiculos) =>
      _escribir(_claveVehiculos, vehiculos);

  @override
  Future<List<Map<String, dynamic>>> leerPiezas() async {
    await abrir();
    return _leer(_clavePiezas);
  }

  @override
  Future<List<Map<String, dynamic>>> leerCuentas(String tipo) async {
    await abrir();
    return _leer('repocar.cuentas.$tipo');
  }

  @override
  Future<void> guardarCuenta(
    String tipo,
    String id,
    Map<String, dynamic> dato,
  ) async {
    await abrir();
    final clave = 'repocar.cuentas.$tipo';
    final cuentas = _leer(clave)
      ..removeWhere((guardada) => guardada['id'] == id)
      ..add({...dato, 'id': id});
    await _escribir(clave, cuentas);
  }

  @override
  Future<void> guardarPieza(Map<String, dynamic> pieza) =>
      _reemplazar(_clavePiezas, 'id', pieza);

  @override
  Future<List<Map<String, dynamic>>> leerPedidos() async {
    await abrir();
    return _leer(_clavePedidos);
  }

  @override
  Future<void> guardarPedido(Map<String, dynamic> pedido) =>
      _reemplazar(_clavePedidos, 'numero', pedido);

  @override
  Future<List<Map<String, dynamic>>> leerAvisos() async {
    await abrir();
    return _leer(_claveAvisos);
  }

  @override
  Future<void> guardarAviso(Map<String, dynamic> aviso) =>
      _reemplazar(_claveAvisos, 'id', aviso);

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

  /// Guarda un dato y, si ya había uno con la misma clave, lo pisa.
  Future<void> _reemplazar(
    String clave,
    String campo,
    Map<String, dynamic> dato,
  ) async {
    await abrir();
    final lista = _leer(clave)
      ..removeWhere((guardado) => guardado[campo] == dato[campo])
      ..add(dato);
    await _escribir(clave, lista);
  }
}
