import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:repocar/data/local/almacen_memoria.dart';
import 'package:repocar/dependencias.dart';
import 'package:repocar/domain/administracion.dart';
import 'package:repocar/ui/admin/widgets/control_de_preguntas.dart';

import 'fakes.dart';

// =====================================================================
// En el panel de TalleresYa, cada pregunta dice de qué taller es la
// publicación: si no, Ramallo no sabe a quién le preguntaron.
// =====================================================================

void main() {
  testWidgets('en "Todas las preguntas", cada una dice su taller', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final deps = Dependencias.crear(
      almacen: AlmacenEnMemoria(),
      notificacionesService: NotificacionesFalsas(),
      conectividad: ConectividadFalsa(),
      segundoPlano: SegundoPlanoFalso(),
    );
    final pieza = await tester.runAsync(() async {
      await deps.sesion.ingresarCliente('sol@gmail.com', '123456');
      await deps.catalogo.cargar();
      final pieza = deps.catalogo.disponibles.first;
      await deps.nuevasPreguntas(pieza).preguntar('¿Le sirve a un Gol 2012?');
      await deps.sesion.ingresarCliente(correoAdministrador, '123456');
      deps.controlDePreguntas.iniciar();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      return pieza;
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: ControlDePreguntas(deps: deps)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('1 preguntas'));
    await tester.pumpAndSettle();

    expect(
      find.text('${pieza!.titulo} · ${pieza.taller.nombre}'),
      findsOneWidget,
    );
  });
}
