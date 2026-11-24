import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as ruta;
import 'package:sqflite/sqflite.dart';

import 'almacen_local.dart';
import 'almacen_preferencias.dart';

/// SQLite en el celular. En una computadora (Windows, Linux, Mac) el
/// plugin de sqflite no existe, así que ahí se usa el mismo almacén
/// que en el navegador: la app anda igual y no explota.
///
/// Se pregunta con defaultTargetPlatform, como en el resto de la app, y
/// no con Platform (de dart:io), que no existe en la web.
AlmacenLocal crearAlmacen() =>
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS)
    ? AlmacenSqlite()
    : AlmacenPreferencias();

// =====================================================================
// LA BASE LOCAL de verdad: SQLite adentro del teléfono.
//
// Tablas: vehiculos, piezas, cuentas, pedidos y avisos. Lo que es una
// lista adentro de otra cosa (la compatibilidad de una pieza, los items
// de un pedido) se guarda como texto JSON en una columna.
//
// Versiones:
//   1 · vehiculos y piezas
//   2 · se agrega cuentas
//   3 · se agregan pedidos, avisos, y en piezas la columna vendida
//   4 · en piezas, la columna foto (la RUTA del archivo, no la imagen)
//   5 · en piezas, pausada y borrada (borrar no borra: los pedidos viejos
//       la siguen nombrando)
// =====================================================================
class AlmacenSqlite implements AlmacenLocal {
  /// La fábrica de bases y el archivo se pueden cambiar desde afuera.
  /// Eso es lo que permite correr el MISMO SQL en los tests, sin
  /// necesitar un teléfono.
  AlmacenSqlite({DatabaseFactory? fabrica, String? archivo})
    : _fabrica = fabrica,
      _archivo = archivo;

  final DatabaseFactory? _fabrica;
  final String? _archivo;

  Database? _base;

  @override
  String get nombre => 'base SQLite del teléfono';

  @override
  Future<void> abrir() async {
    if (_base != null) return;

    final fabrica = _fabrica ?? databaseFactory;
    final archivo =
        _archivo ?? ruta.join(await fabrica.getDatabasesPath(), 'repocar.db');

    _base = await fabrica.openDatabase(
      archivo,
      options: OpenDatabaseOptions(
        version: 5,
        // Para los teléfonos que ya tenían una versión anterior: se
        // agrega solo lo que les falta, sin borrar lo que ya guardaron.
        onUpgrade: (base, desde, hasta) async {
          if (desde < 2) await _crearCuentas(base);
          if (desde < 3) await _pasarAVersion3(base);
          if (desde < 4) {
            await base.execute('ALTER TABLE piezas ADD COLUMN foto TEXT');
          }
          if (desde < 5) {
            await base.execute(
              'ALTER TABLE piezas ADD COLUMN pausada INTEGER NOT NULL DEFAULT 0',
            );
            await base.execute(
              'ALTER TABLE piezas ADD COLUMN borrada INTEGER NOT NULL DEFAULT 0',
            );
          }
        },
        onCreate: (base, version) async {
          await base.execute('''
            CREATE TABLE vehiculos (
              marca TEXT NOT NULL,
              modelo TEXT NOT NULL,
              desde INTEGER NOT NULL,
              hasta INTEGER NOT NULL
            )
          ''');
          await base.execute('''
            CREATE TABLE piezas (
              id TEXT PRIMARY KEY,
              titulo TEXT NOT NULL,
              descripcion TEXT NOT NULL,
              precio INTEGER NOT NULL,
              estado TEXT NOT NULL,
              taller_cuit TEXT NOT NULL,
              icono TEXT NOT NULL,
              compatibles TEXT NOT NULL,
              vendida INTEGER NOT NULL DEFAULT 0,
              foto TEXT,
              pausada INTEGER NOT NULL DEFAULT 0,
              borrada INTEGER NOT NULL DEFAULT 0
            )
          ''');
          await _crearCuentas(base);
          await _crearPedidosYAvisos(base);
        },
      ),
    );
  }

  /// Cierra el archivo. En el teléfono no hace falta, pero en los tests sí:
  /// Windows no deja borrar un archivo que sigue abierto.
  Future<void> cerrar() async {
    await _base?.close();
    _base = null;
  }

  static Future<void> _crearCuentas(Database base) async {
    await base.execute('''
      CREATE TABLE cuentas (
        tipo TEXT NOT NULL,
        id TEXT NOT NULL,
        datos TEXT NOT NULL,
        PRIMARY KEY (tipo, id)
      )
    ''');
  }

  static Future<void> _crearPedidosYAvisos(Database base) async {
    await base.execute(
      'CREATE TABLE pedidos (numero TEXT PRIMARY KEY, datos TEXT NOT NULL)',
    );
    await base.execute(
      'CREATE TABLE avisos (id TEXT PRIMARY KEY, datos TEXT NOT NULL)',
    );
  }

  static Future<void> _pasarAVersion3(Database base) async {
    await base.execute(
      'ALTER TABLE piezas ADD COLUMN vendida INTEGER NOT NULL DEFAULT 0',
    );
    await _crearPedidosYAvisos(base);
  }

  // --- Vehículos ---

  @override
  Future<List<Map<String, dynamic>>> leerVehiculos() async {
    await abrir();
    final filas = await _base!.query('vehiculos');
    return filas.map((fila) => Map<String, dynamic>.from(fila)).toList();
  }

  @override
  Future<void> guardarVehiculos(List<Map<String, dynamic>> vehiculos) async {
    await abrir();
    // Se reemplaza la lista entera: es una foto de lo que bajamos.
    final lote = _base!.batch();
    lote.delete('vehiculos');
    for (final vehiculo in vehiculos) {
      lote.insert('vehiculos', vehiculo);
    }
    await lote.commit(noResult: true);
  }

  // --- Piezas ---

  @override
  Future<List<Map<String, dynamic>>> leerPiezas() async {
    await abrir();
    final filas = await _base!.query('piezas');
    return filas.map((fila) {
      final pieza = Map<String, dynamic>.from(fila);
      // En la tabla son texto y números; en la app, una lista y un booleano.
      pieza['compatibles'] = jsonDecode(pieza['compatibles'] as String);
      pieza['vendida'] = pieza['vendida'] == 1;
      pieza['pausada'] = pieza['pausada'] == 1;
      pieza['borrada'] = pieza['borrada'] == 1;
      return pieza;
    }).toList();
  }

  @override
  Future<void> guardarPieza(Map<String, dynamic> pieza) async {
    await abrir();
    await _base!.insert('piezas', {
      'id': pieza['id'],
      'titulo': pieza['titulo'],
      'descripcion': pieza['descripcion'],
      'precio': pieza['precio'],
      'estado': pieza['estado'],
      'taller_cuit': pieza['taller_cuit'],
      'icono': pieza['icono'],
      'compatibles': jsonEncode(pieza['compatibles']),
      'vendida': pieza['vendida'] == true ? 1 : 0,
      'foto': pieza['foto'],
      'pausada': pieza['pausada'] == true ? 1 : 0,
      'borrada': pieza['borrada'] == true ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // --- Cuentas, pedidos y avisos: un dato JSON por fila ---

  @override
  Future<List<Map<String, dynamic>>> leerCuentas(String tipo) =>
      _leerJson('cuentas', where: 'tipo = ?', whereArgs: [tipo]);

  @override
  Future<void> guardarCuenta(
    String tipo,
    String id,
    Map<String, dynamic> dato,
  ) async {
    await abrir();
    await _base!.insert('cuentas', {
      'tipo': tipo,
      'id': id,
      'datos': jsonEncode({...dato, 'id': id}),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<List<Map<String, dynamic>>> leerPedidos() => _leerJson('pedidos');

  @override
  Future<void> guardarPedido(Map<String, dynamic> pedido) async {
    await abrir();
    await _base!.insert('pedidos', {
      'numero': pedido['numero'],
      'datos': jsonEncode(pedido),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<List<Map<String, dynamic>>> leerAvisos() => _leerJson('avisos');

  @override
  Future<void> guardarAviso(Map<String, dynamic> aviso) async {
    await abrir();
    await _base!.insert('avisos', {
      'id': aviso['id'],
      'datos': jsonEncode(aviso),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
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

  Future<List<Map<String, dynamic>>> _leerJson(
    String tabla, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    await abrir();
    final filas = await _base!.query(tabla, where: where, whereArgs: whereArgs);
    return filas
        .map(
          (fila) => Map<String, dynamic>.from(
            jsonDecode(fila['datos'] as String) as Map,
          ),
        )
        .toList();
  }
}
