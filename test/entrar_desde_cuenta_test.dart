import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:repocar/data/local/almacen_memoria.dart';
import 'package:repocar/dependencias.dart';
import 'package:repocar/ui/inicio/widgets/inicio_comprador.dart';
import 'package:repocar/ui/taller/widgets/taller_screen.dart';

import 'fakes.dart';

// =====================================================================
// Un comprador que entra como taller desde su Cuenta ("Vendé tus
// repuestos"): al iniciar sesión, las pantallas del comprador se borran
// de atrás. Si quedaran, la flecha atrás lo devolvería a ellas con la
// sesión del taller.
// =====================================================================

void main() {
  testWidgets('al entrar como taller desde la Cuenta del comprador, no '
      'quedan pantallas del comprador atrás', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final deps = Dependencias.crear(
      almacen: AlmacenEnMemoria(),
      notificacionesService: NotificacionesFalsas(),
      conectividad: ConectividadFalsa(),
      segundoPlano: SegundoPlanoFalso(),
    );
    await tester.runAsync(
      () => deps.sesion.ingresarCliente('sol@gmail.com', '123456'),
    );

    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: InicioComprador(deps: deps)));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Cuenta → "Vendé tus repuestos en RepoCar".
    await tester.tap(find.text('Cuenta'));
    await tester.pumpAndSettle();
    final vender = find.text('Vendé tus repuestos en RepoCar');
    // La lista se arma de a poco: se baja hasta que aparece.
    await tester.dragUntilVisible(
      vender,
      find.byType(ListView).first,
      const Offset(0, -250),
    );
    await tester.pumpAndSettle();
    await tester.tap(vender);
    await tester.pumpAndSettle();

    // Entra con el CUIT y la clave de un taller de ejemplo.
    await tester.enterText(
      find.widgetWithText(TextField, 'CUIT'),
      '30-71234567-1',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Contraseña'),
      '123456',
    );
    await tester.runAsync(() async {
      await tester.tap(find.text('Ingresar'));
      await Future<void>.delayed(const Duration(seconds: 2));
    });
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Está en el panel del taller, y no hay nada atrás.
    final panel = find.byType(TallerScreen);
    expect(panel, findsOneWidget);
    expect(Navigator.of(tester.element(panel)).canPop(), isFalse);
  });
}
