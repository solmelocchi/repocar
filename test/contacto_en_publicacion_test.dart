import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:repocar/data/local/almacen_memoria.dart';
import 'package:repocar/dependencias.dart';
import 'package:repocar/ui/taller/widgets/publicar_screen.dart';

import 'fakes.dart';

// =====================================================================
// CONTACTO EN LA PUBLICACIÓN: el mismo filtro de las preguntas
// (tieneDatosDeContacto) frena un teléfono puesto en la descripción,
// para que la venta no se vaya a WhatsApp.
// =====================================================================

void main() {
  testWidgets('no se publica una descripción con un teléfono', (tester) async {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final deps = Dependencias.crear(
      almacen: AlmacenEnMemoria(),
      notificacionesService: NotificacionesFalsas(),
      conectividad: ConectividadFalsa(),
      segundoPlano: SegundoPlanoFalso(),
    );
    await tester.runAsync(() async {
      await deps.sesion.ingresarTaller('30-71234567-1', '123456');
      await deps.catalogo.cargar();
    });
    final antes = deps.catalogo.piezas.length;

    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: PublicarScreen(deps: deps)));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Título'),
      'Alternador Bosch 90A',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Precio'),
      '1000',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Descripción'),
      'Llamame al 261 555 1234',
    );

    // El botón está al final de la lista: hay que bajar para que exista.
    final publicar = find.text('Publicar');
    await tester.scrollUntilVisible(
      publicar,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(publicar);
    await tester.pump();

    // El error queda debajo de la descripción: se vuelve a subir.
    final error = find.text(
      'No se pueden poner teléfonos, mails ni WhatsApp: la venta se hace por RepoCar.',
    );
    await tester.scrollUntilVisible(
      error,
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(error, findsOneWidget);
    // Se frenó en el formulario: ni siquiera llegó a pedir el auto.
    expect(find.text('Elegí para qué auto sirve el repuesto'), findsNothing);
    expect(deps.catalogo.piezas.length, antes);
  });
}
