import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:repocar/data/local/almacen_memoria.dart';
import 'package:repocar/data/local/fotos_locales.dart';
import 'package:repocar/data/repositories/catalogo_repository.dart';
import 'package:repocar/data/repositories/cuentas_repository.dart';
import 'package:repocar/data/services/catalogo_service.dart';
import 'package:repocar/data/services/cuentas_service.dart';
import 'package:repocar/data/services/fuente_de_fotos.dart';
import 'package:repocar/ui/taller/view_models/foto_view_model.dart';

import 'fakes.dart';

/// Las fotos guardadas, en memoria: anota cuáles se guardaron y cuáles
/// se borraron, sin tocar el disco.
class FotosEnMemoria implements FotosLocales {
  int _cuantas = 0;
  final borradas = <String>[];

  @override
  Future<String> guardar(String id, Uint8List bytes) async =>
      'foto-${++_cuantas}';

  @override
  Future<void> borrar(String referencia) async => borradas.add(referencia);

  @override
  Future<String?> comoTexto(String? referencia) async => referencia;
}

Foto fotoDePrueba() => Foto(img.encodeJpg(img.Image(width: 1200, height: 900)));

void main() {
  late FotosEnMemoria fotos;

  FotoViewModel crear(FuenteFalsa fuente, {String? inicial}) {
    fotos = FotosEnMemoria();
    final almacen = AlmacenEnMemoria();
    return FotoViewModel(
      fuente: fuente,
      repositorio: CatalogoRepository(
        servicio: CatalogoService(almacen: almacen, demora: Duration.zero),
        cuentas: CuentasRepository(
          servicio: const CuentasService(demora: Duration.zero),
          almacen: almacen,
        ),
        fotos: fotos,
      ),
      capacidades: SinNotificaciones(),
      idPieza: 'p1',
      inicial: inicial,
    );
  }

  group('La foto de una publicación (cámara)', () {
    test('una foto: se achica, se guarda y se usa', () async {
      final vm = crear(FuenteFalsa([fotoDePrueba()]));

      await vm.elegir(OrigenDeFoto.camara);

      expect(vm.referencia, 'foto-1');
      expect(vm.error, isNull);
      expect(vm.cargando, isFalse);
    });

    test('cancelar no es un error y conserva la foto anterior', () async {
      final vm = crear(FuenteFalsa([fotoDePrueba(), null]));
      await vm.elegir(OrigenDeFoto.galeria);

      await vm.elegir(OrigenDeFoto.camara); // se arrepintió

      expect(vm.referencia, 'foto-1');
      expect(vm.error, isNull);
    });

    test(
      'si falla de verdad, muestra el mensaje y la foto anterior queda',
      () async {
        final vm = crear(
          FuenteFalsa([
            fotoDePrueba(),
            const ErrorDeFoto('No diste permiso para usar la cámara.'),
          ]),
        );
        await vm.elegir(OrigenDeFoto.camara);

        await vm.elegir(OrigenDeFoto.camara);

        expect(vm.referencia, 'foto-1');
        expect(vm.error, 'No diste permiso para usar la cámara.');
      },
    );

    test(
      'al reemplazar una foto, la vieja se borra (no quedan huérfanas)',
      () async {
        final vm = crear(FuenteFalsa([fotoDePrueba(), fotoDePrueba()]));
        await vm.elegir(OrigenDeFoto.camara);

        await vm.elegir(OrigenDeFoto.camara);

        expect(vm.referencia, 'foto-2');
        expect(fotos.borradas, ['foto-1']);
      },
    );

    test('editando, la foto publicada no se borra hasta guardar', () async {
      final vm = crear(FuenteFalsa([fotoDePrueba()]), inicial: 'publicada');
      await vm.elegir(OrigenDeFoto.camara);

      expect(fotos.borradas, isEmpty); // si se va sin guardar, sigue

      await vm.confirmarGuardado();
      expect(fotos.borradas, ['publicada']);
    });

    test('un doble toque no abre la cámara dos veces', () async {
      final fuente = FuenteFalsa([fotoDePrueba(), fotoDePrueba()]);
      final vm = crear(fuente);

      await Future.wait([
        vm.elegir(OrigenDeFoto.camara),
        vm.elegir(OrigenDeFoto.camara),
      ]);

      expect(fuente.veces, 1);
    });
  });
}
