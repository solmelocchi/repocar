import 'package:flutter_test/flutter_test.dart';

import 'package:repocar/data/local/carrito_guardado.dart';
import 'package:repocar/data/politicas_remotas.dart';
import 'package:repocar/data/services/configuracion_service.dart';
import 'package:repocar/ui/carrito/view_models/carrito_view_model.dart';

import 'fakes.dart';

void main() {
  test('si las zonas no se pueden traer, la pantalla se entera igual '
      '(el aviso va en el finally)', () async {
    final carrito = CarritoViewModel(
      vehiculos: VehiculosQueFalla(),
      politicas: PoliticasRemotas(
        const ConfiguracionService(demora: Duration.zero),
      ),
      guardado: CarritoEnMemoria(),
    );
    var avisos = 0;
    carrito.addListener(() => avisos++);

    await carrito.cargarZonas(); // no explota

    expect(carrito.zonas, isEmpty);
    expect(avisos, 1);
  });
}
