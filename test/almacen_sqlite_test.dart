import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as ruta;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:repocar/data/local/almacen_sqlite.dart';

// =====================================================================
// El SQL de verdad, sin teléfono.
//
// sqflite_common_ffi corre SQLite en la computadora, así que acá se
// ejecutan las MISMAS sentencias que en el celular: el CREATE TABLE,
// los insert, las consultas y la migración de versión.
// =====================================================================
void main() {
  late Directory carpeta;
  final abiertas = <AlmacenSqlite>[];

  setUpAll(sqfliteFfiInit);

  setUp(() => carpeta = Directory.systemTemp.createTempSync('repocar_'));

  tearDown(() async {
    for (final base in abiertas) {
      await base.cerrar();
    }
    abiertas.clear();
    if (carpeta.existsSync()) carpeta.deleteSync(recursive: true);
  });

  AlmacenSqlite abrirEn(String nombre) {
    final base = AlmacenSqlite(
      fabrica: databaseFactoryFfi,
      archivo: ruta.join(carpeta.path, nombre),
    );
    abiertas.add(base);
    return base;
  }

  test('guarda la lista de autos y la lee igual', () async {
    final base = abrirEn('autos.db');

    await base.guardarVehiculos([
      {'marca': 'Fiat', 'modelo': 'Cronos', 'desde': 2018, 'hasta': 2024},
      {'marca': 'Ford', 'modelo': 'Ranger', 'desde': 2012, 'hasta': 2022},
    ]);

    final leidos = await base.leerVehiculos();
    expect(leidos.length, 2);
    expect(leidos.first['modelo'], 'Cronos');
    expect(leidos.first['desde'], 2018); // vuelve como número, no texto
  });

  test('reemplazar la lista de autos no la duplica', () async {
    final base = abrirEn('autos.db');
    final lista = [
      {'marca': 'Fiat', 'modelo': 'Cronos', 'desde': 2018, 'hasta': 2024},
    ];

    await base.guardarVehiculos(lista);
    await base.guardarVehiculos(lista);

    expect((await base.leerVehiculos()).length, 1);
  });

  test('una pieza vuelve con su compatibilidad como lista', () async {
    final base = abrirEn('piezas.db');

    await base.guardarPieza({
      'id': 'p99',
      'titulo': 'Bobina de encendido',
      'descripcion': 'Probada.',
      'precio': 48000,
      'estado': 'reacondicionado',
      'taller_cuit': '30-71234567-1',
      'icono': 'electric_bolt',
      'compatibles': [
        {'marca': 'Fiat', 'modelo': 'Cronos', 'desde': 2018, 'hasta': 2024},
      ],
    });

    final pieza = (await base.leerPiezas()).single;
    expect(pieza['titulo'], 'Bobina de encendido');
    expect(pieza['precio'], 48000);
    // En la tabla es texto JSON, pero al leerla vuelve a ser una lista.
    final compatibles = pieza['compatibles'] as List;
    expect((compatibles.single as Map)['modelo'], 'Cronos');
  });

  test('lo guardado sigue ahí al cerrar y volver a abrir', () async {
    final antes = abrirEn('reinicio.db');
    await antes.guardarPieza({
      'id': 'p50',
      'titulo': 'Capot',
      'descripcion': '-',
      'precio': 210000,
      'estado': 'usado',
      'taller_cuit': '23-25888999-1',
      'icono': 'flip',
      'compatibles': const [],
    });

    // Otra instancia sobre el mismo archivo: es reiniciar la app.
    final despues = abrirEn('reinicio.db');
    expect((await despues.leerPiezas()).single['titulo'], 'Capot');
  });

  test('las cuentas se guardan por tipo', () async {
    final base = abrirEn('cuentas.db');

    await base.guardarCuenta('talleres', '20-31222333-4', {'nombre': 'Nuevo'});
    await base.guardarCuenta('claves', '20312223334', {'hash': 'abc123'});

    expect((await base.leerCuentas('talleres')).single['nombre'], 'Nuevo');
    expect((await base.leerCuentas('claves')).single['hash'], 'abc123');
    expect(await base.leerCuentas('clientes'), isEmpty);
  });

  test('una base vieja (versión 1) se actualiza sola', () async {
    final archivo = ruta.join(carpeta.path, 'vieja.db');

    // Así quedaba la base en un teléfono con la versión anterior:
    // sin la tabla de cuentas.
    final vieja = await databaseFactoryFfi.openDatabase(
      archivo,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (base, version) async {
          await base.execute(
            'CREATE TABLE vehiculos (marca TEXT, modelo TEXT, '
            'desde INTEGER, hasta INTEGER)',
          );
          await base.execute(
            'CREATE TABLE piezas (id TEXT PRIMARY KEY, titulo TEXT, '
            'descripcion TEXT, precio INTEGER, estado TEXT, '
            'taller_cuit TEXT, icono TEXT, compatibles TEXT)',
          );
        },
      ),
    );
    await vieja.close();

    // La app nueva abre ese mismo archivo y tiene que poder usar cuentas.
    final base = AlmacenSqlite(fabrica: databaseFactoryFfi, archivo: archivo);
    abiertas.add(base);
    await base.guardarCuenta('clientes', 'nuevo@gmail.com', {'nombre': 'Ana'});

    expect((await base.leerCuentas('clientes')).single['nombre'], 'Ana');
  });

  test('los pedidos se guardan y se reemplazan por número', () async {
    final base = abrirEn('pedidos.db');

    await base.guardarPedido({'numero': '#1051', 'estado': 'pagado'});
    await base.guardarPedido({'numero': '#1051', 'estado': 'entregado'});
    await base.guardarPedido({'numero': '#1052', 'estado': 'pagado'});

    final pedidos = await base.leerPedidos();
    expect(pedidos.length, 2);
    expect(
      pedidos.firstWhere((p) => p['numero'] == '#1051')['estado'],
      'entregado',
    );
  });

  test('los avisos se guardan con su estado de leído', () async {
    final base = abrirEn('avisos.db');

    await base.guardarAviso({
      'id': 'a1',
      'titulo': 'Pedido nuevo',
      'leida': false,
    });
    await base.guardarAviso({
      'id': 'a1',
      'titulo': 'Pedido nuevo',
      'leida': true,
    });

    final avisos = await base.leerAvisos();
    expect(avisos.single['leida'], isTrue);
  });

  test('una pieza vendida vuelve marcada como vendida', () async {
    final base = abrirEn('vendida.db');
    await base.guardarPieza({
      'id': 'p1',
      'titulo': 'Alternador',
      'descripcion': '-',
      'precio': 185000,
      'estado': 'reacondicionado',
      'taller_cuit': '30-71234567-1',
      'icono': 'electric_bolt',
      'compatibles': const [],
      'vendida': true,
    });

    expect((await base.leerPiezas()).single['vendida'], isTrue);
  });

  test(
    'una base de la versión 2 se actualiza a la 3 sin perder nada',
    () async {
      final archivo = ruta.join(carpeta.path, 'v2.db');

      // Así quedaba la base con la versión 2: con cuentas, sin pedidos.
      final vieja = await databaseFactoryFfi.openDatabase(
        archivo,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (base, version) async {
            await base.execute(
              'CREATE TABLE vehiculos (marca TEXT, modelo TEXT, '
              'desde INTEGER, hasta INTEGER)',
            );
            await base.execute(
              'CREATE TABLE piezas (id TEXT PRIMARY KEY, titulo TEXT, '
              'descripcion TEXT, precio INTEGER, estado TEXT, '
              'taller_cuit TEXT, icono TEXT, compatibles TEXT)',
            );
            await base.execute(
              'CREATE TABLE cuentas (tipo TEXT, id TEXT, datos TEXT, '
              'PRIMARY KEY (tipo, id))',
            );
            await base.insert('cuentas', {
              'tipo': 'clientes',
              'id': 'ana@gmail.com',
              'datos': '{"nombre":"Ana","id":"ana@gmail.com"}',
            });
          },
        ),
      );
      await vieja.close();

      final base = AlmacenSqlite(fabrica: databaseFactoryFfi, archivo: archivo);
      abiertas.add(base);

      // Lo de antes sigue estando...
      expect((await base.leerCuentas('clientes')).single['nombre'], 'Ana');
      // ...y lo nuevo funciona.
      await base.guardarPedido({'numero': '#1051', 'estado': 'pagado'});
      expect((await base.leerPedidos()).single['numero'], '#1051');
    },
  );
  test('una base de la versión 3 se actualiza a la 4: las piezas viejas '
      'quedan sin foto y las nuevas guardan la ruta', () async {
    final archivo = ruta.join(carpeta.path, 'v3.db');

    // Así quedaba la tabla de piezas en la versión 3: sin foto.
    final vieja = await databaseFactoryFfi.openDatabase(
      archivo,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (base, version) async {
          await base.execute(
            'CREATE TABLE piezas (id TEXT PRIMARY KEY, titulo TEXT, '
            'descripcion TEXT, precio INTEGER, estado TEXT, '
            'taller_cuit TEXT, icono TEXT, compatibles TEXT, '
            'vendida INTEGER NOT NULL DEFAULT 0)',
          );
          await base.insert('piezas', {
            'id': 'p1',
            'titulo': 'Alternador',
            'descripcion': '-',
            'precio': 185000,
            'estado': 'usado',
            'taller_cuit': '30-71234567-1',
            'icono': 'electric_bolt',
            'compatibles': '[]',
            'vendida': 0,
          });
        },
      ),
    );
    await vieja.close();

    final base = AlmacenSqlite(fabrica: databaseFactoryFfi, archivo: archivo);
    abiertas.add(base);

    // La pieza de antes sigue, sin foto.
    expect((await base.leerPiezas()).single['foto'], isNull);

    // Una nueva guarda la RUTA del archivo, no la imagen.
    await base.guardarPieza({
      'id': 'p2',
      'titulo': 'Bobina',
      'descripcion': '-',
      'precio': 48000,
      'estado': 'reacondicionado',
      'taller_cuit': '30-71234567-1',
      'icono': 'electric_bolt',
      'compatibles': const [],
      'foto': '/data/user/0/com.example.repocar/app_flutter/fotos/p2.jpg',
    });
    final nueva = (await base.leerPiezas()).firstWhere((p) => p['id'] == 'p2');
    expect(nueva['foto'], endsWith('fotos/p2.jpg'));
  });
}
