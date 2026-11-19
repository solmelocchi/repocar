import 'package:flutter_test/flutter_test.dart';

import 'package:repocar/data/local/almacen_memoria.dart';
import 'package:repocar/data/local/sesion_guardada.dart';
import 'package:repocar/data/politicas_remotas.dart';
import 'package:repocar/data/repositories/catalogo_repository.dart';
import 'package:repocar/data/repositories/cuentas_repository.dart';
import 'package:repocar/data/services/autenticacion_service.dart';
import 'package:repocar/data/services/catalogo_service.dart';
import 'package:repocar/data/services/configuracion_service.dart';
import 'package:repocar/data/services/cuentas_service.dart';
import 'package:repocar/domain/administracion.dart';
import 'package:repocar/ui/catalogo/view_models/catalogo_view_model.dart';
import 'package:repocar/ui/ingreso/view_models/sesion_view_model.dart';

import 'fakes.dart';

const _rapido = Duration(milliseconds: 1);

/// Una sesión armada como en dependencias.dart, con Firebase de mentira.
SesionViewModel sesionCon({
  required AlmacenEnMemoria almacen,
  AutenticacionService autenticacion = const SinAutenticacion(),
  SesionGuardada? guardada,
}) => SesionViewModel(
  repositorio: CuentasRepository(
    servicio: const CuentasService(demora: _rapido),
    almacen: almacen,
    autenticacion: autenticacion,
  ),
  politicas: PoliticasRemotas(const ConfiguracionService()),
  guardada: guardada,
);

void main() {
  group('Inicio de sesión con el servidor', () {
    test('una cuenta de ejemplo se da de alta en Firebase la primera vez, '
        'y después entra directo', () async {
      final firebase = AutenticacionFalsa();
      final sesion = sesionCon(
        almacen: AlmacenEnMemoria(),
        autenticacion: firebase,
      );

      expect(await sesion.ingresarCliente('sol@gmail.com', '123456'), isNull);
      expect(firebase.altas, 1);

      await sesion.salir();
      expect(firebase.haySesion, isFalse);

      expect(await sesion.ingresarCliente('sol@gmail.com', '123456'), isNull);
      expect(firebase.altas, 1); // no se volvió a dar de alta
    });

    test('con la clave equivocada no entra', () async {
      final sesion = sesionCon(
        almacen: AlmacenEnMemoria(),
        autenticacion: AutenticacionFalsa(),
      );

      final error = await sesion.ingresarCliente('sol@gmail.com', 'otra123');

      expect(error, 'La contraseña no coincide.');
      expect(sesion.hayCliente, isFalse);
    });

    test('el taller entra a Firebase con el mail armado con su CUIT', () async {
      final firebase = AutenticacionFalsa();
      final sesion = sesionCon(
        almacen: AlmacenEnMemoria(),
        autenticacion: firebase,
      );

      expect(await sesion.ingresarTaller(cuitRamallo, '123456'), isNull);
      expect(firebase.conectado, '30712345671@taller.repocar.app');
      expect(sesion.taller!.cuit, cuitRamallo);
    });

    test('registrarse con una clave de menos de 6 caracteres da el error '
        'del servidor', () async {
      final sesion = sesionCon(
        almacen: AlmacenEnMemoria(),
        autenticacion: AutenticacionFalsa(),
      );

      final error = await sesion.registrarCliente(
        nombre: 'Ana',
        usuario: 'ana@gmail.com',
        telefono: '2604001122',
        clave: '123',
      );

      expect(error, contains('6 caracteres'));
      expect(sesion.hayCliente, isFalse);
    });

    test(
      'sin servidor, se valida con la huella guardada en el teléfono',
      () async {
        final sesion = sesionCon(almacen: AlmacenEnMemoria());

        expect(await sesion.ingresarCliente('sol@gmail.com', '123456'), isNull);
      },
    );
  });

  group('La sesión queda recordada (almacenamiento seguro)', () {
    test('al abrir la app de nuevo, entra solo', () async {
      final almacen = AlmacenEnMemoria();
      final guardada = SesionEnMemoria();
      final firebase = AutenticacionFalsa();

      final antes = sesionCon(
        almacen: almacen,
        autenticacion: firebase,
        guardada: guardada,
      );
      await antes.ingresarTaller(cuitRamallo, '123456');

      // Otra instancia: es cerrar y volver a abrir la app.
      final despues = sesionCon(
        almacen: almacen,
        autenticacion: firebase,
        guardada: guardada,
      );
      await despues.restaurar();

      expect(despues.taller?.cuit, cuitRamallo);
    });

    test('si salió, al abrir de nuevo pide entrar', () async {
      final guardada = SesionEnMemoria();
      final sesion = sesionCon(almacen: AlmacenEnMemoria(), guardada: guardada);
      await sesion.ingresarCliente('sol@gmail.com', '123456');
      await sesion.salir();

      final despues = sesionCon(
        almacen: AlmacenEnMemoria(),
        guardada: guardada,
      );
      await despues.restaurar();

      expect(despues.hayCliente, isFalse);
      expect(await guardada.leer(), isNull);
    });

    test('si el servidor ya no tiene la sesión, se olvida', () async {
      final guardada = SesionEnMemoria();
      final firebase = AutenticacionFalsa();
      await guardada.guardar('cliente', 'sol@gmail.com');

      final sesion = sesionCon(
        almacen: AlmacenEnMemoria(),
        autenticacion: firebase, // sin nadie conectado
        guardada: guardada,
      );
      await sesion.restaurar();

      expect(sesion.hayCliente, isFalse);
      expect(await guardada.leer(), isNull);
    });
  });

  test('la cuenta de TalleresYa es la de administración', () async {
    final sesion = sesionCon(almacen: AlmacenEnMemoria());

    await sesion.ingresarCliente(correoAdministrador, '123456');

    expect(sesion.esAdmin, isTrue);
  });

  test('editar el perfil del taller cambia el MISMO objeto que usan las '
      'publicaciones', () async {
    final almacen = AlmacenEnMemoria();
    final sesion = sesionCon(almacen: almacen);
    await sesion.ingresarTaller(cuitRamallo, '123456');
    final taller = sesion.taller!;

    await sesion.actualizarTaller(
      telefono: '+54 9 261 111-2222',
      zona: 'Villa Atuel',
      tieneCadete: false,
      costoCadete: 500,
    );

    expect(identical(sesion.taller, taller), isTrue);
    expect(taller.telefono, '+54 9 261 111-2222');
    expect(taller.costoCadete, 0); // sin cadete, no cobra cadete
    final guardado = await almacen.leerCuentas('talleres');
    expect(guardado.single['zona'], 'Villa Atuel');
  });

  group('Pausar y borrar publicaciones', () {
    Future<CatalogoViewModel> catalogo(AlmacenEnMemoria almacen) async {
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

    test('pausada no se ve en el catálogo, y al reanudar vuelve', () async {
      final vm = await catalogo(AlmacenEnMemoria());
      final pieza = vm.buscarPorId('p1')!;

      await vm.pausar(pieza, pausada: true);
      expect(vm.disponibles.contains(pieza), isFalse);
      expect(vm.deTaller(pieza.taller).contains(pieza), isTrue);

      await vm.pausar(pieza, pausada: false);
      expect(vm.disponibles.contains(pieza), isTrue);
    });

    test('borrada no se ve en ningún lado, pero sigue guardada para los '
        'pedidos viejos, también al reabrir', () async {
      final almacen = AlmacenEnMemoria();
      final vm = await catalogo(almacen);
      final pieza = vm.buscarPorId('p1')!;

      await vm.borrar(pieza);
      expect(vm.disponibles.contains(pieza), isFalse);
      expect(vm.deTaller(pieza.taller).contains(pieza), isFalse);

      final despues = await catalogo(almacen);
      expect(despues.buscarPorId('p1')!.borrada, isTrue);
    });
  });
}
