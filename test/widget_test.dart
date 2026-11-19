import 'package:flutter_test/flutter_test.dart';

import 'package:repocar/dependencias.dart';
import 'package:repocar/main.dart';

import 'fakes.dart';

void main() {
  testWidgets('La app arranca preguntando si sos cliente o taller', (
    WidgetTester tester,
  ) async {
    // Lo que toca el sistema operativo va con falsos: en una prueba no
    // hay teléfono, ni red, ni WorkManager.
    final deps = Dependencias.crear(
      notificacionesService: NotificacionesFalsas(),
      conectividad: ConectividadFalsa(),
      segundoPlano: SegundoPlanoFalso(),
    );
    await tester.pumpWidget(RepoCarApp(deps: deps));

    expect(find.text('RepoCar'), findsOneWidget);
    expect(find.text('Soy cliente'), findsOneWidget);
    expect(find.text('Soy un taller'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });

  testWidgets('Sin red aparece la franja, y se va cuando vuelve', (
    WidgetTester tester,
  ) async {
    final red = ConectividadFalsa(ahora: false);
    final deps = Dependencias.crear(
      notificacionesService: NotificacionesFalsas(),
      conectividad: red,
      segundoPlano: SegundoPlanoFalso(),
    );
    await tester.pumpWidget(RepoCarApp(deps: deps));
    await tester.pumpAndSettle();

    expect(find.textContaining('Sin conexión'), findsOneWidget);

    red.cambiar(true);
    await tester.pumpAndSettle();

    expect(find.textContaining('Sin conexión'), findsNothing);
  });
}
