import 'package:flutter_test/flutter_test.dart';

import 'package:repocar/data/local/carrito_guardado.dart';
import 'package:repocar/data/politicas_remotas.dart';
import 'package:repocar/data/services/configuracion_service.dart';
import 'package:repocar/domain/models/auto.dart';
import 'package:repocar/domain/models/pieza.dart';
import 'package:repocar/domain/models/taller.dart';
import 'package:repocar/ui/carrito/view_models/carrito_view_model.dart';

import 'fakes.dart';

final _taller = Taller(nombre: 'Taller', telefono: '', zona: 'San Rafael');

Pieza pieza(String id) => Pieza(
  id: id,
  titulo: 'Pieza $id',
  descripcion: '',
  precio: 1000,
  estado: EstadoPieza.usado,
  taller: _taller,
  icono: 'build',
  compatibles: const [Compatibilidad('Fiat', 'Cronos', 2018, 2024)],
);

/// Un carrito nuevo sobre lo guardado: es como abrir la app otra vez.
CarritoViewModel abrirCarrito(CarritoGuardado guardado) => CarritoViewModel(
  vehiculos: VehiculosFake(),
  politicas: PoliticasRemotas(const ConfiguracionService()),
  guardado: guardado,
);

void main() {
  final catalogo = {
    for (final id in ['p1', 'p2', 'p3']) id: pieza(id),
  };
  Pieza? buscar(String id) => catalogo[id];

  test('el carrito sobrevive a cerrar la app (se guarda al cambiar)', () async {
    final guardado = CarritoEnMemoria();
    final antes = abrirCarrito(guardado)
      ..agregar(catalogo['p1']!)
      ..agregar(catalogo['p2']!);
    await pumpEventQueue();
    expect(antes.cantidad, 2);

    // Se cerró la app (por ejemplo, durante una llamada larga).
    final despues = abrirCarrito(guardado);
    await despues.restaurar(buscar);

    expect(despues.items.map((i) => i.pieza.id), ['p1', 'p2']);
  });

  test('lo que se vendió mientras tanto no vuelve al carrito', () async {
    final guardado = CarritoEnMemoria()..ids = ['p1', 'p3'];
    catalogo['p3']!.vendida = true;
    addTearDown(() => catalogo['p3']!.vendida = false);

    final carrito = abrirCarrito(guardado);
    await carrito.restaurar(buscar);

    expect(carrito.items.map((i) => i.pieza.id), ['p1']);
  });

  test('vaciar (al pagar o cerrar sesión) borra también lo guardado', () async {
    final guardado = CarritoEnMemoria();
    abrirCarrito(guardado)
      ..agregar(catalogo['p1']!)
      ..vaciar();
    await pumpEventQueue();

    expect(await guardado.leer(), isEmpty);
  });
}
