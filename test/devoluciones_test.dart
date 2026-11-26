import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:repocar/data/local/almacen_memoria.dart';
import 'package:repocar/data/repositories/pedidos_repository.dart';
import 'package:repocar/dependencias.dart';
import 'package:repocar/domain/models/envio.dart';
import 'package:repocar/domain/models/pedido.dart';
import 'package:repocar/domain/models/pieza.dart';
import 'package:repocar/ui/pedidos/widgets/mis_pedidos_screen.dart';

import 'fakes.dart';

// =====================================================================
// Las devoluciones (botón de arrepentimiento): no cuentan como venta ni
// como comisión en el resumen de TalleresYa, y el comprador las ve
// aparte. Y en las calificaciones y sus respuestas no se pueden poner
// teléfonos ni mails, igual que en las preguntas.
// =====================================================================

Dependencias _armar() {
  SharedPreferences.setMockInitialValues({});
  return Dependencias.crear(
    almacen: AlmacenEnMemoria(),
    notificacionesService: NotificacionesFalsas(),
    conectividad: ConectividadFalsa(),
    segundoPlano: SegundoPlanoFalso(),
  );
}

/// Compra dos piezas (dos pedidos) y se arrepiente de la primera.
Future<(Pedido, Pedido)> _comprarYDevolverUna(Dependencias deps) async {
  await deps.sesion.ingresarCliente('sol@gmail.com', '123456');
  await deps.catalogo.cargar();
  await deps.pedidos.cargar();
  final [a, b, ...] = deps.catalogo.disponibles;
  Future<Pedido> comprar(Pieza pieza) async =>
      (await deps.pedidos.confirmarCompra(
        [
          CompraTaller(
            taller: pieza.taller,
            items: [ItemCarrito(pieza)],
            entrega: MetodoEntrega.retiro,
          ),
        ],
        'Sol Melocchi',
        usuario: 'sol@gmail.com',
      )).single;
  final devuelto = await comprar(a);
  final comprado = await comprar(b);
  await deps.pedidos.arrepentirse(devuelto);
  return (devuelto, comprado);
}

void main() {
  test(
    'el resumen no cuenta los devueltos en lo vendido ni en la comisión',
    () async {
      final deps = _armar();
      final vm = deps.pedidos;
      await deps.sesion.ingresarCliente('sol@gmail.com', '123456');
      await vm.cargar();
      final antes = (
        pedidos: vm.pedidosDelPeriodo,
        vendido: vm.vendidoDelPeriodo,
        comision: vm.comisionDelPeriodo,
      );

      final (devuelto, comprado) = await _comprarYDevolverUna(deps);

      expect(vm.pedidosDelPeriodo, antes.pedidos + 1);
      expect(vm.vendidoDelPeriodo, antes.vendido + comprado.subtotal);
      expect(vm.comisionDelPeriodo, antes.comision + comprado.comision);
      expect(vm.devueltosDelPeriodo, 1);
      expect(vm.devueltoDelPeriodo, devuelto.subtotal);
    },
  );

  test('no se pueden poner teléfonos ni mails en la calificación ni en la '
      'respuesta del taller', () async {
    final deps = _armar();
    final (_, comprado) = await _comprarYDevolverUna(deps);
    await deps.pedidos.cambiarEstado(comprado, EstadoPedido.entregado);

    expect(
      await deps.pedidos.calificar(comprado, 5, 'Escribime al 261 555 1234'),
      contains('teléfonos'),
    );
    expect(comprado.calificacion, isNull); // no se guardó

    expect(await deps.pedidos.calificar(comprado, 5, 'Impecable'), isNull);
    expect(
      await deps.pedidos.responder(comprado, 'Gracias, mail: taller@x.com'),
      contains('teléfonos'),
    );
    expect(comprado.calificacion!.respuesta, isNull);
    expect(() => const ComentarioConContacto().mensaje, returnsNormally);
  });

  testWidgets('el comprador ve "Pedidos" y "Devoluciones" por separado', (
    tester,
  ) async {
    final deps = _armar();
    final (devuelto, comprado) = (await tester.runAsync(
      () => _comprarYDevolverUna(deps),
    ))!;

    await tester.pumpWidget(MaterialApp(home: MisPedidosScreen(deps: deps)));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Pedido ${comprado.numero}'), findsOneWidget);
    expect(find.text('Pedido ${devuelto.numero}'), findsNothing);

    await tester.tap(find.text('Devoluciones (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Pedido ${devuelto.numero}'), findsOneWidget);
    expect(find.text('Pedido ${comprado.numero}'), findsNothing);
  });
}
