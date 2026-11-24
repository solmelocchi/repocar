import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:repocar/data/local/almacen_memoria.dart';
import 'package:repocar/data/services/preguntas_service.dart';
import 'package:repocar/dependencias.dart';
import 'package:repocar/ui/catalogo/widgets/detalle_screen.dart';

import 'fakes.dart';

// =====================================================================
// La ficha con las preguntas y respuestas, dibujada en el tamaño de un
// celular: si algo se desborda, la prueba falla.
// =====================================================================

const _cuitDelTaller = '30-71234567-1';

Future<Dependencias> armar(PreguntasService preguntas) async {
  SharedPreferences.setMockInitialValues({});
  return Dependencias.crear(
    almacen: AlmacenEnMemoria(),
    notificacionesService: NotificacionesFalsas(),
    conectividad: ConectividadFalsa(),
    segundoPlano: SegundoPlanoFalso(),
    preguntas: preguntas,
  );
}

Future<void> dibujar(WidgetTester tester, Widget pantalla) async {
  tester.view.physicalSize = const Size(1170, 2532); // un celular común
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: pantalla));
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

/// Baja por la ficha, como el usuario, hasta que aparece ese texto.
Future<void> bajarHasta(WidgetTester tester, String texto) =>
    tester.scrollUntilVisible(
      find.text(texto),
      300,
      scrollable: find.byType(Scrollable).first,
    );

void main() {
  testWidgets('el comprador pregunta en la ficha y el taller la ve para '
      'responder; antes de comprar no hay WhatsApp', (tester) async {
    final servidor = PreguntasEnMemoria();

    // --- El comprador ---
    final comprador = await armar(servidor);
    await tester.runAsync(() async {
      await comprador.sesion.ingresarCliente('sol@gmail.com', '123456');
      await comprador.catalogo.cargar();
    });
    final pieza = comprador.catalogo.disponibles.firstWhere(
      (p) => p.taller.cuit == _cuitDelTaller,
    );

    await dibujar(tester, DetalleScreen(pieza: pieza, deps: comprador));
    await bajarHasta(tester, 'Preguntas y respuestas');

    expect(find.text('Preguntas y respuestas'), findsOneWidget);
    expect(find.text('Consultar por WhatsApp'), findsNothing);
    expect(find.text('Todavía nadie preguntó.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '¿Le sirve a un Gol 2012?');
    await tester.ensureVisible(find.text('Preguntar'));
    await tester.tap(find.text('Preguntar'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.text('¿Le sirve a un Gol 2012?'), findsOneWidget);
    expect(find.text('Todavía sin respuesta del taller.'), findsOneWidget);

    // --- El taller dueño, en su ficha ---
    final taller = await armar(servidor);
    await tester.runAsync(() async {
      await taller.sesion.ingresarTaller(_cuitDelTaller, '123456');
      await taller.catalogo.cargar();
    });

    await dibujar(tester, DetalleScreen(pieza: pieza, deps: taller));
    await bajarHasta(tester, 'Responder');

    expect(find.text('¿Le sirve a un Gol 2012?'), findsOneWidget);
    expect(find.text('Responder'), findsOneWidget);
    expect(find.text('Preguntar'), findsNothing); // el taller no pregunta
  });
}
