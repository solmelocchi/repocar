import 'package:flutter_test/flutter_test.dart';

import 'package:repocar/ui/busqueda/view_models/vehiculos_view_model.dart';
import 'package:repocar/ui/core/estado_carga.dart';

import 'fakes.dart';

// =====================================================================
// Tests del VIEWMODEL, con repositorios falsos.
// Prueban los tres estados del Future sin tocar la red ni dibujar nada.
// =====================================================================
void main() {
  test('arranca en cargando', () {
    final vm = VehiculosViewModel(repositorio: VehiculosFake());
    expect(vm.estado, EstadoCarga.cargando);
    expect(vm.vehiculos, isEmpty);
  });

  test(
    'cuando el repositorio responde, queda en éxito con los datos',
    () async {
      final vm = VehiculosViewModel(repositorio: VehiculosFake());

      await vm.cargar();

      expect(vm.estado, EstadoCarga.exito);
      expect(vm.vehiculos.length, 2);
      expect(vm.marcas, ['Ford', 'Volkswagen']); // ordenadas
    },
  );

  test(
    'los años salen del rango del modelo, del más nuevo al más viejo',
    () async {
      final vm = VehiculosViewModel(repositorio: VehiculosFake());

      await vm.cargar();
      final anios = vm.aniosDe('Volkswagen', 'Gol Trend');

      expect(anios.first, 2016);
      expect(anios.last, 2008);
      expect(anios.length, 9);
    },
  );

  test('si el repositorio falla, queda en error y no rompe la app', () async {
    final vm = VehiculosViewModel(repositorio: VehiculosQueFalla());

    await vm.cargar();

    expect(vm.estado, EstadoCarga.error);
    expect(vm.vehiculos, isEmpty);
  });

  test('avisa a la vista cada vez que cambia de estado', () async {
    final vm = VehiculosViewModel(repositorio: VehiculosFake());
    var avisos = 0;
    vm.addListener(() => avisos++);

    await vm.cargar();

    // Uno al empezar a cargar y otro al terminar.
    expect(avisos, 2);
  });
}
