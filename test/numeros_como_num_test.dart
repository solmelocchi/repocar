import 'package:flutter_test/flutter_test.dart';

import 'package:repocar/data/local/almacen_memoria.dart';
import 'package:repocar/data/repositories/catalogo_repository.dart';
import 'package:repocar/data/repositories/cuentas_repository.dart';
import 'package:repocar/data/repositories/pedidos_repository.dart';
import 'package:repocar/data/services/catalogo_service.dart';
import 'package:repocar/data/services/cuentas_service.dart';
import 'package:repocar/data/services/pedidos_service.dart';
import 'package:repocar/domain/models/auto.dart';

// =====================================================================
// Firestore y JSON no distinguen int de double: un 2008 puede llegar
// como 2008.0. Por eso los números se leen como num y se pasan a int.
// =====================================================================

typedef _App = ({CatalogoRepository catalogo, PedidosRepository pedidos});

Future<_App> _abrir(AlmacenEnMemoria almacen) async {
  final cuentas = CuentasRepository(
    servicio: const CuentasService(demora: Duration.zero),
    almacen: almacen,
  );
  await cuentas.cargar();
  final catalogo = CatalogoRepository(
    servicio: CatalogoService(almacen: almacen, demora: Duration.zero),
    cuentas: cuentas,
  );
  final pedidos = PedidosRepository(
    servicio: PedidosService(almacen: almacen, demora: Duration.zero),
    catalogo: catalogo,
    cuentas: cuentas,
  );
  await pedidos.obtenerPedidos();
  return (catalogo: catalogo, pedidos: pedidos);
}

void main() {
  test('un modelo con los años como double se lee igual', () {
    final modelo = ModeloVehiculo.desdeJson({
      'marca': 'Fiat',
      'modelo': 'Palio',
      'desde': 2008.0,
      'hasta': 2015.0,
    });

    expect(modelo.desde, 2008);
    expect(modelo.hasta, 2015);
  });

  test(
    'un pedido con cantidad, envío y estrellas como double se lee igual',
    () async {
      final almacen = AlmacenEnMemoria();
      final app = await _abrir(almacen);
      final pieza = app.catalogo.buscarPorId('p1')!;
      await almacen.guardarPedido({
        'numero': '#1999',
        'fecha': DateTime(2026, 11, 17).toIso8601String(),
        'cliente': 'Sol Melocchi',
        'taller_cuit': pieza.taller.cuit,
        'items': [
          {'pieza_id': 'p1', 'cantidad': 2.0},
        ],
        'entrega': 'envio',
        'direccion': 'San Martín 100',
        'costo_envio': 500.0,
        'comision_pct': 0.10,
        'estado': 'entregado',
        'calificacion': {'estrellas': 4.0, 'comentario': 'Bien'},
      });

      final despues = await _abrir(almacen);
      final pedido = despues.pedidos
          .desde(null)
          .firstWhere((p) => p.numero == '#1999');

      expect(pedido.items.single.cantidad, 2);
      expect(pedido.costoEnvio, 500);
      expect(pedido.calificacion!.estrellas, 4);
    },
  );
}
