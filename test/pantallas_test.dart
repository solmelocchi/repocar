import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repocar/data/local/almacen_memoria.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:repocar/dependencias.dart';
import 'package:repocar/domain/administracion.dart';
import 'package:repocar/ui/admin/widgets/inicio_admin.dart';
import 'package:repocar/ui/inicio/widgets/inicio_comprador.dart';
import 'package:repocar/ui/taller/widgets/taller_screen.dart';

import 'fakes.dart';

// =====================================================================
// Las pantallas nuevas, dibujadas en el tamaño de un celular. Si algo
// se desborda (el clásico cartel amarillo y negro), la prueba falla.
// =====================================================================

Future<Dependencias> armar() async {
  SharedPreferences.setMockInitialValues({});
  return Dependencias.crear(
    // Base en memoria: la prueba no depende de en qué compu corre.
    almacen: AlmacenEnMemoria(),
    notificacionesService: NotificacionesFalsas(),
    conectividad: ConectividadFalsa(),
    segundoPlano: SegundoPlanoFalso(),
  );
}

Future<void> dibujar(WidgetTester tester, Widget pantalla) async {
  tester.view.physicalSize = const Size(1170, 2532); // un celular común
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: pantalla));
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

void main() {
  testWidgets('comprador: inicio con buscador, grilla y barra de abajo', (
    tester,
  ) async {
    final deps = await armar();
    await tester.runAsync(
      () => deps.sesion.ingresarCliente('sol@gmail.com', '123456'),
    );

    await dibujar(tester, InicioComprador(deps: deps));

    expect(find.text('¿Qué auto tenés?'), findsOneWidget);
    expect(find.text('Último en el catálogo'), findsOneWidget);
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Cuenta'), findsOneWidget);

    // Escribir en el buscador filtra en el momento.
    await tester.enterText(find.byType(TextField), 'alternador');
    await tester.pumpAndSettle();
    expect(find.textContaining('resultado'), findsOneWidget);

    // La pestaña Cuenta.
    await tester.tap(find.text('Cuenta'));
    await tester.pumpAndSettle();
    expect(find.text('Mi cuenta'), findsOneWidget);
    expect(find.text('MIS DATOS'), findsOneWidget);
  });

  testWidgets('taller: publicaciones, pedidos y cuenta abajo', (tester) async {
    final deps = await armar();
    await tester.runAsync(
      () => deps.sesion.ingresarTaller('30-71234567-1', '123456'),
    );

    await dibujar(tester, TallerScreen(deps: deps));

    expect(find.text('Mis publicaciones'), findsOneWidget);
    expect(find.text('Publicar'), findsOneWidget); // el botón flotante

    // Tocar una publicación abre su ficha, con el botón de editar.
    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();
    expect(find.text('Tu publicación'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pedidos'));
    await tester.pumpAndSettle();
    expect(find.text('Pedidos recibidos'), findsOneWidget);

    // Tocar un pedido abre su detalle.
    await tester.tap(find.textContaining('#').first);
    await tester.pumpAndSettle();
    expect(find.text('Cuánto te queda'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cuenta'));
    await tester.pumpAndSettle();
    expect(find.text('CUIT'), findsOneWidget);
  });

  testWidgets('TalleresYa: el panel con los números y todos los pedidos', (
    tester,
  ) async {
    final deps = await armar();
    await tester.runAsync(
      () => deps.sesion.ingresarCliente(correoAdministrador, '123456'),
    );

    await dibujar(tester, InicioAdmin(deps: deps));

    expect(find.text('Comisión a cobrar'), findsOneWidget);
    expect(find.text('Por taller'), findsOneWidget);

    // Tocar un taller muestra sus pedidos y su comisión, legible: el
    // texto tiene ancho de verdad (con el botón al costado quedaba de una
    // letra por renglón).
    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();
    expect(find.text('Cambiar la comisión'), findsOneWidget);
    final comision = find.textContaining(RegExp(r'^Comisión \d+%$'));
    expect(tester.getSize(comision).width, greaterThan(60));
    await tester.pageBack();
    await tester.pumpAndSettle();

    // "Pedidos" también es el título de un número: se toca el de la barra.
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Pedidos'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Todos los pedidos'), findsOneWidget);

    // Y el detalle de un pedido, con el reparto de la plata.
    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();
    expect(find.text('Reparto de la plata'), findsOneWidget);

    // El cuadro del comprador ocupa todo el ancho (centrado quedaba angosto).
    await tester.scrollUntilVisible(
      find.text('Comprador'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final comprador = find
        .ancestor(of: find.text('Comprador'), matching: find.byType(Card))
        .first;
    expect(tester.getSize(comprador).width, greaterThan(300));
  });
}
