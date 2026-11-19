import 'package:flutter_test/flutter_test.dart';

import 'package:repocar/data/local/almacen_memoria.dart';
import 'package:repocar/data/repositories/catalogo_repository.dart';
import 'package:repocar/data/repositories/cuentas_repository.dart';
import 'package:repocar/data/services/catalogo_service.dart';
import 'package:repocar/data/services/cuentas_service.dart';
import 'package:repocar/domain/models/auto.dart';
import 'package:repocar/domain/models/pieza.dart';
import 'package:repocar/ui/catalogo/view_models/catalogo_view_model.dart';

const _rapido = Duration(milliseconds: 1);

/// El catálogo armado sobre una base. Llamarlo dos veces con la misma
/// base es como cerrar y volver a abrir la app.
Future<CatalogoViewModel> abrirCatalogo(AlmacenEnMemoria almacen) async {
  final vm = CatalogoViewModel(
    repositorio: CatalogoRepository(
      servicio: CatalogoService(almacen: almacen, demora: _rapido),
      cuentas: CuentasRepository(
        servicio: const CuentasService(demora: _rapido),
        almacen: almacen,
      ),
    ),
  );
  await vm.cargar();
  return vm;
}

void main() {
  group('El buscador filtra', () {
    test('sin filtros muestra todo lo que se puede comprar', () async {
      final vm = await abrirCatalogo(AlmacenEnMemoria());

      expect(vm.filtrar(), hasLength(vm.disponibles.length));
    });

    test('por texto, sin importar mayúsculas', () async {
      final vm = await abrirCatalogo(AlmacenEnMemoria());

      final encontrados = vm.filtrar(texto: 'ALTERNADOR');

      expect(encontrados, isNotEmpty);
      expect(
        encontrados.every(
          (p) => '${p.titulo} ${p.descripcion}'.toLowerCase().contains(
            'alternador',
          ),
        ),
        isTrue,
      );
    });

    test('por auto: solo lo que le sirve a esa marca, modelo y año', () async {
      final vm = await abrirCatalogo(AlmacenEnMemoria());
      const gol = Auto(marca: 'Volkswagen', modelo: 'Gol Trend', anio: 2014);

      final encontrados = vm.filtrar(auto: gol);

      expect(encontrados, isNotEmpty);
      expect(encontrados.every((p) => p.sirvePara(gol)), isTrue);
    });

    test('los filtros se suman: auto + rubro + texto', () async {
      final vm = await abrirCatalogo(AlmacenEnMemoria());
      const gol = Auto(marca: 'Volkswagen', modelo: 'Gol Trend', anio: 2014);

      final soloAuto = vm.filtrar(auto: gol);
      final autoYRubro = vm.filtrar(auto: gol, rubro: 'electric_bolt');

      expect(autoYRubro.length, lessThanOrEqualTo(soloAuto.length));
      expect(autoYRubro.every((p) => p.icono == 'electric_bolt'), isTrue);
      expect(vm.filtrar(auto: gol, texto: 'xyz no existe'), isEmpty);
    });
  });

  group('Editar una publicación', () {
    test('cambia el precio, mantiene el id y sigue así al reabrir', () async {
      final almacen = AlmacenEnMemoria();
      final vm = await abrirCatalogo(almacen);
      final original = vm.buscarPorId('p1')!;

      await vm.editar(
        Pieza(
          id: original.id,
          titulo: '${original.titulo} (con garantía)',
          descripcion: original.descripcion,
          precio: 150000,
          estado: original.estado,
          taller: original.taller,
          icono: original.icono,
          compatibles: original.compatibles,
        ),
      );

      expect(vm.buscarPorId('p1')!.precio, 150000);
      // No se duplicó: sigue habiendo una sola p1.
      expect(vm.piezas.where((p) => p.id == 'p1'), hasLength(1));

      final despues = await abrirCatalogo(almacen);
      expect(despues.buscarPorId('p1')!.precio, 150000);
      expect(despues.buscarPorId('p1')!.titulo, endsWith('(con garantía)'));
    });
  });
}
