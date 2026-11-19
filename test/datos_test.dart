import 'package:flutter_test/flutter_test.dart';

import 'package:repocar/data/local/almacen_memoria.dart';
import 'package:repocar/data/services/catalogo_service.dart';
import 'package:repocar/data/services/cuentas_service.dart';
import 'package:repocar/data/services/pedidos_service.dart';
import 'package:repocar/data/services/vehiculos_service.dart';
import 'package:repocar/domain/cuit.dart';

// =====================================================================
// Estos tests no prueban código: prueban LOS DATOS.
//
// El lote de ejemplo se escribe a mano, y a mano se mete el dedo:
// un CUIT mal copiado, un repuesto de un taller que no existe o una
// compatibilidad con un modelo mal escrito. Cualquiera de esas cosas
// rompe la búsqueda en la demo. Que salte acá y no en la clase.
// =====================================================================
const _rapido = Duration(milliseconds: 1);

void main() {
  late List<Map<String, dynamic>> talleres;
  late List<Map<String, dynamic>> vehiculos;
  late List<Map<String, dynamic>> piezas;
  late List<Map<String, dynamic>> pedidos;

  setUpAll(() async {
    talleres = await const CuentasService(demora: _rapido).obtenerTalleres();
    vehiculos = await const VehiculosService(demora: _rapido)
        .obtenerVehiculos();
    piezas = await CatalogoService(
      almacen: AlmacenEnMemoria(),
      demora: _rapido,
    ).obtenerPiezas();
    pedidos = await PedidosService(
      almacen: AlmacenEnMemoria(),
      demora: _rapido,
    ).obtenerPedidos();
  });

  test('el lote alcanza para mostrar la app con algo de vida', () {
    expect(talleres.length, greaterThanOrEqualTo(5));
    expect(vehiculos.length, greaterThanOrEqualTo(20));
    expect(piezas.length, greaterThanOrEqualTo(25));
    expect(pedidos.length, greaterThanOrEqualTo(8));
  });

  test('todos los talleres tienen un CUIT que ARCA aceptaría', () {
    for (final taller in talleres) {
      expect(
        cuitValido(taller['cuit'] as String),
        isTrue,
        reason: '${taller['nombre']} tiene un CUIT inválido',
      );
    }
  });

  test('no hay dos talleres con el mismo CUIT', () {
    final cuits = talleres.map((t) => t['cuit']).toList();
    expect(cuits.toSet().length, cuits.length);
  });

  test('cada taller está en una zona de la lista', () {
    for (final taller in talleres) {
      expect(zonasDeTaller, contains(taller['zona']));
    }
  });

  test('no hay dos repuestos con el mismo id', () {
    final ids = piezas.map((p) => p['id']).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('cada repuesto es de un taller que existe', () {
    final cuits = talleres.map((t) => t['cuit']).toSet();
    for (final pieza in piezas) {
      expect(
        cuits,
        contains(pieza['taller_cuit']),
        reason: '${pieza['titulo']} apunta a un taller que no está',
      );
    }
  });

  test('cada repuesto sirve para autos que existen y en años reales', () {
    for (final pieza in piezas) {
      for (final compatible in pieza['compatibles'] as List) {
        final c = compatible as Map<String, dynamic>;
        final modelo = vehiculos.firstWhere(
          (v) => v['marca'] == c['marca'] && v['modelo'] == c['modelo'],
          orElse: () => {},
        );

        expect(
          modelo,
          isNotEmpty,
          reason:
              '${pieza['titulo']}: no existe '
              '${c['marca']} ${c['modelo']}',
        );
        expect(
          c['desde'] as int,
          greaterThanOrEqualTo(modelo['desde'] as int),
          reason:
              '${pieza['titulo']}: el ${c['modelo']} no se fabricaba '
              'en ${c['desde']}',
        );
        expect(
          c['hasta'] as int,
          lessThanOrEqualTo(modelo['hasta'] as int),
          reason:
              '${pieza['titulo']}: el ${c['modelo']} no se fabricaba '
              'en ${c['hasta']}',
        );
      }
    }
  });

  test('cada pedido tiene taller y repuestos que existen', () {
    final cuits = talleres.map((t) => t['cuit']).toSet();
    final ids = piezas.map((p) => p['id']).toSet();

    for (final pedido in pedidos) {
      expect(
        cuits,
        contains(pedido['taller_cuit']),
        reason: '${pedido['numero']}',
      );
      for (final item in pedido['items'] as List) {
        final mapa = item as Map<String, dynamic>;
        expect(ids, contains(mapa['pieza_id']), reason: '${pedido['numero']}');
      }
    }
  });

  test('los pedidos no se repiten y entran en el último mes', () {
    final numeros = pedidos.map((p) => p['numero']).toList();
    expect(numeros.toSet().length, numeros.length);

    for (final pedido in pedidos) {
      expect(pedido['dias_atras'] as int, lessThan(30));
    }
  });
}
