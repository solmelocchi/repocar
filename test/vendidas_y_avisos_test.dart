import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:repocar/data/local/almacen_memoria.dart';
import 'package:repocar/dependencias.dart';
import 'package:repocar/domain/models/auto.dart';
import 'package:repocar/domain/models/envio.dart';
import 'package:repocar/domain/models/pedido.dart';
import 'package:repocar/domain/models/pieza.dart';
import 'package:repocar/domain/models/taller.dart';
import 'package:repocar/domain/ventas.dart';
import 'package:repocar/ui/notificaciones/widgets/activar_avisos.dart';
import 'package:repocar/ui/taller/widgets/taller_screen.dart';

import 'fakes.dart';

// =====================================================================
// El taller ve lo publicado y lo vendido por separado, con la fecha de
// cada venta. Y si el teléfono bloqueó las notificaciones, el botón
// "Activar" explica cómo activarlas en vez de no hacer nada.
// =====================================================================

final _taller = Taller(nombre: 'El Torno', telefono: '', zona: 'San Rafael');

Pieza _pieza(String id) => Pieza(
  id: id,
  titulo: id,
  descripcion: '',
  precio: 1000,
  estado: EstadoPieza.usado,
  taller: _taller,
  icono: 'build',
  compatibles: const [Compatibilidad('Fiat', 'Cronos', 2018, 2024)],
);

Pedido _pedido(String numero, DateTime fecha, List<Pieza> piezas) => Pedido(
  numero: numero,
  fecha: fecha,
  cliente: 'Sol',
  taller: _taller,
  items: [for (final p in piezas) ItemCarrito(p)],
  entrega: MetodoEntrega.retiro,
  comisionPct: 0.10,
);

Dependencias _armar({NotificacionesFalsas? avisos}) {
  SharedPreferences.setMockInitialValues({});
  return Dependencias.crear(
    almacen: AlmacenEnMemoria(),
    notificacionesService: avisos ?? NotificacionesFalsas(),
    conectividad: ConectividadFalsa(),
    segundoPlano: SegundoPlanoFalso(),
  );
}

void main() {
  test('de cada pieza vendida, el pedido que la compró (el más nuevo)', () {
    final a = _pieza('a');
    final b = _pieza('b');
    final viejo = _pedido('#1', DateTime(2026, 11, 1), [a]);
    final nuevo = _pedido('#2', DateTime(2026, 11, 20), [a, b]);

    final ventas = pedidoDeCadaPieza([viejo, nuevo]);

    expect(ventas['a'], nuevo);
    expect(ventas['b'], nuevo);
    expect(ventas['c'], isNull);
  });

  testWidgets('el taller ve "Publicadas" y "Vendidas" por separado, y en '
      'las vendidas la fecha y el pedido', (tester) async {
    final deps = _armar();
    await tester.runAsync(() async {
      await deps.sesion.ingresarTaller('30-71234567-1', '123456');
      await deps.catalogo.cargar();
      await deps.pedidos.cargar();
      // Le compran una pieza al taller.
      final taller = deps.sesion.taller!;
      final pieza = deps.catalogo.disponibles.firstWhere(
        (p) => p.taller.cuit == taller.cuit,
      );
      await deps.pedidos.confirmarCompra(
        [
          CompraTaller(
            taller: taller,
            items: [ItemCarrito(pieza)],
            entrega: MetodoEntrega.retiro,
          ),
        ],
        'Sol Melocchi',
        usuario: 'sol@gmail.com',
      );
    });
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: TallerScreen(deps: deps)));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Arranca en lo publicado: nada vendido a la vista.
    expect(find.textContaining('Publicadas ('), findsOneWidget);
    expect(find.textContaining('· Vendida'), findsNothing);

    // En "Vendidas": la fecha de la venta y el número del pedido.
    await tester.tap(find.textContaining('Vendidas ('));
    await tester.pumpAndSettle();
    expect(find.textContaining('Vendidas (1)'), findsOneWidget);
    expect(find.textContaining('Vendida el '), findsOneWidget);
    expect(find.textContaining('pedido #'), findsOneWidget);
    expect(find.byIcon(Icons.edit), findsNothing); // lo vendido no se edita
  });

  testWidgets('si el teléfono bloqueó los avisos, "Activar" explica cómo '
      'activarlos', (tester) async {
    final avisos = NotificacionesFalsas(permiso: false)..bloqueado = true;
    final deps = _armar(avisos: avisos);
    await tester.runAsync(deps.notificaciones.consultarCapacidad);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActivarAvisos(deps: deps, beneficio: 'Enterate de tus pedidos'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Activar'));
    await tester.pumpAndSettle();
    expect(find.text('Las notificaciones están bloqueadas'), findsOneWidget);
    expect(find.textContaining('Ajustes'), findsOneWidget);

    // Si no estaba bloqueado, se activa y el cartel se va solo.
    await tester.tap(find.text('Entendido'));
    await tester.pumpAndSettle();
    avisos.bloqueado = false;
    await tester.tap(find.text('Activar'));
    await tester.pumpAndSettle();
    expect(find.text('Activar'), findsNothing);
  });
}
