import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:repocar/data/local/almacen_memoria.dart';
import 'package:repocar/dependencias.dart';
import 'package:repocar/domain/administracion.dart';
import 'package:repocar/ui/admin/widgets/inicio_admin.dart';
import 'package:repocar/ui/carrito/widgets/carrito_screen.dart';
import 'package:repocar/ui/carrito/widgets/checkout_screen.dart';
import 'package:repocar/ui/core/tema.dart';
import 'package:repocar/ui/inicio/widgets/inicio_comprador.dart';
import 'package:repocar/ui/ingreso/widgets/ingreso_screen.dart';
import 'package:repocar/ui/taller/widgets/publicar_screen.dart';
import 'package:repocar/ui/taller/widgets/taller_screen.dart';

import 'fakes.dart';

// =====================================================================
// ACCESIBILIDAD: las pantallas principales, con los colores reales de
// la app, cumplen las guías de Flutter:
//   · botones de al menos 48 x 48 (lo mínimo para tocarlos sin errarle),
//   · todo lo que se toca tiene nombre (para el lector de pantalla),
//   · el texto tiene contraste suficiente (4,5 o más).
// Así, la gente grande o con la vista cansada puede usar la app, y si
// un cambio lo rompe, el CI no lo deja entrar.
// =====================================================================

enum _Quien { nadie, cliente, taller, admin }

Future<Dependencias> _armar(WidgetTester tester, _Quien quien) async {
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
    switch (quien) {
      case _Quien.cliente:
        await deps.sesion.ingresarCliente('sol@gmail.com', '123456');
      case _Quien.taller:
        await deps.sesion.ingresarTaller('30-71234567-1', '123456');
      case _Quien.admin:
        await deps.sesion.ingresarCliente(correoAdministrador, '123456');
      case _Quien.nadie:
        break;
    }
    await deps.catalogo.cargar();
    if (quien == _Quien.cliente) {
      deps.carrito.agregar(deps.catalogo.disponibles.first);
    }
  });
  return deps;
}

Future<void> _revisar(WidgetTester tester, Widget pantalla) async {
  final semantica = tester.ensureSemantics();
  tester.view.physicalSize = const Size(1080, 2340); // un celular de 360 dp
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: temaRepoCar(), home: pantalla));
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(seconds: 2));

  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
  semantica.dispose();
}

void main() {
  final casos = <(String, _Quien, Widget Function(Dependencias))>[
    ('el ingreso', _Quien.nadie, (d) => IngresoScreen(deps: d)),
    (
      'el inicio del comprador',
      _Quien.cliente,
      (d) => InicioComprador(deps: d),
    ),
    ('el carrito', _Quien.cliente, (d) => CarritoScreen(deps: d)),
    ('la entrega y el pago', _Quien.cliente, (d) => CheckoutScreen(deps: d)),
    ('el panel del taller', _Quien.taller, (d) => TallerScreen(deps: d)),
    ('publicar un repuesto', _Quien.taller, (d) => PublicarScreen(deps: d)),
    ('el panel de TalleresYa', _Quien.admin, (d) => InicioAdmin(deps: d)),
  ];

  for (final (nombre, quien, pantalla) in casos) {
    testWidgets('accesibilidad: $nombre', (tester) async {
      final deps = await _armar(tester, quien);
      await _revisar(tester, pantalla(deps));
    });
  }
}
