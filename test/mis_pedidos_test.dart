import 'package:flutter_test/flutter_test.dart';

import 'package:repocar/data/local/almacen_memoria.dart';
import 'package:repocar/data/repositories/catalogo_repository.dart';
import 'package:repocar/data/repositories/cuentas_repository.dart';
import 'package:repocar/data/repositories/pedidos_repository.dart';
import 'package:repocar/data/services/catalogo_service.dart';
import 'package:repocar/data/services/cuentas_service.dart';
import 'package:repocar/data/services/pedidos_service.dart';
import 'package:repocar/domain/models/envio.dart';
import 'package:repocar/domain/models/pedido.dart';

// =====================================================================
// "Mis pedidos" elige los pedidos por el USUARIO de la cuenta, no por el
// nombre: dos personas pueden llamarse igual, y sus pedidos no se tienen
// que mezclar.
// =====================================================================

typedef _App = ({
  CatalogoRepository catalogo,
  PedidosRepository pedidos,
  AlmacenEnMemoria almacen,
});

Future<_App> _abrir([AlmacenEnMemoria? base]) async {
  final almacen = base ?? AlmacenEnMemoria();
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
  return (catalogo: catalogo, pedidos: pedidos, almacen: almacen);
}

Future<Pedido> _comprar(_App app, String piezaId, {String? usuario}) async {
  final pieza = app.catalogo.buscarPorId(piezaId)!;
  final nuevos = await app.pedidos.confirmarCompra(
    [
      CompraTaller(
        taller: pieza.taller,
        items: [ItemCarrito(pieza)],
        entrega: MetodoEntrega.retiro,
      ),
    ],
    'Sol Melocchi',
    usuario: usuario,
  );
  return nuevos.single;
}

void main() {
  test(
    'dos cuentas con el mismo nombre no ven los pedidos de la otra',
    () async {
      final app = await _abrir();

      final deLaPrimera = await _comprar(app, 'p1', usuario: 'sol@gmail.com');
      final deLaSegunda = await _comprar(
        app,
        'p2',
        usuario: 'Sol.Nueva@gmail.com', // con mayúsculas: da igual
      );

      expect(app.pedidos.deCliente('sol@gmail.com'), [deLaPrimera]);
      expect(app.pedidos.deCliente('sol.nueva@gmail.com'), [deLaSegunda]);
    },
  );

  test('quién compró queda guardado al reiniciar la app', () async {
    final app = await _abrir();
    await _comprar(app, 'p1', usuario: 'sol.nueva@gmail.com');

    final despues = await _abrir(app.almacen);

    expect(despues.pedidos.deCliente('sol.nueva@gmail.com').length, 1);
    expect(despues.pedidos.deCliente('sol@gmail.com'), isEmpty);
  });

  test('un pedido de antes, que solo tenía el nombre, se lo queda la cuenta '
      'que ya existía (la primera con ese nombre)', () async {
    final almacen = AlmacenEnMemoria();
    final app = await _abrir(almacen);
    final pieza = app.catalogo.buscarPorId('p1')!;
    await almacen.guardarPedido({
      'numero': '#1999',
      'fecha': DateTime(2026, 11, 17).toIso8601String(),
      'cliente': 'Sol Melocchi', // sin 'cliente_usuario', como antes
      'taller_cuit': pieza.taller.cuit,
      'items': [
        {'pieza_id': 'p1', 'cantidad': 1},
      ],
      'entrega': 'retiro',
      'direccion': '',
      'costo_envio': 0,
      'comision_pct': 0.10,
      'estado': 'pagado',
    });

    final despues = await _abrir(almacen);

    expect(
      despues.pedidos.deCliente('sol@gmail.com').map((p) => p.numero),
      contains('#1999'),
    );
    expect(despues.pedidos.deCliente('sol.nueva@gmail.com'), isEmpty);
  });
}
