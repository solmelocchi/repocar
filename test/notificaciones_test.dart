import 'package:flutter_test/flutter_test.dart';

import 'package:repocar/data/local/almacen_local.dart';
import 'package:repocar/data/local/almacen_memoria.dart';
import 'package:repocar/data/repositories/notificaciones_repository.dart';
import 'package:repocar/plataforma/capacidades.dart';

import 'fakes.dart';

NotificacionesRepository repositorioCon(
  Capacidades capacidades, {
  AlmacenLocal? almacen,
  NotificacionesFalsas? sistema,
}) => NotificacionesRepository(
  servicio: sistema ?? NotificacionesFalsas(),
  capacidades: capacidades,
  almacen: almacen ?? AlmacenEnMemoria(),
);

void main() {
  test('si el dispositivo puede, el aviso llega y queda sin leer', () async {
    final repositorio = repositorioCon(const Capacidades());

    final mandado = await repositorio.avisar(
      para: '30-71234567-1',
      titulo: 'Pedido nuevo #1045',
      texto: 'Sol compró un alternador.',
    );

    expect(mandado, isTrue);
    expect(repositorio.sinLeerDe('30-71234567-1'), 1);
    expect(
      repositorio.para('30-71234567-1').first.titulo,
      'Pedido nuevo #1045',
    );
  });

  test('entrar a la bandeja los marca como leídos', () async {
    final repositorio = repositorioCon(const Capacidades());
    await repositorio.avisar(para: 'Sol', titulo: 'Llegó', texto: 'Calificá');

    await repositorio.marcarLeidas('Sol');

    expect(repositorio.sinLeerDe('Sol'), 0);
    expect(repositorio.para('Sol').length, 1);
  });

  test('si el dispositivo no puede notificar, no se manda nada', () async {
    final sistema = NotificacionesFalsas();
    final repositorio = repositorioCon(SinNotificaciones(), sistema: sistema);

    final mandado = await repositorio.avisar(
      para: 'Sol',
      titulo: 'Llegó',
      texto: 'Calificá',
    );

    expect(mandado, isFalse);
    expect(repositorio.para('Sol'), isEmpty);
    expect(sistema.mostradas, isEmpty);
  });

  test('cada uno ve solo sus avisos', () async {
    final repositorio = repositorioCon(const Capacidades());

    await repositorio.avisar(para: 'Sol', titulo: 'Uno', texto: '');
    await repositorio.avisar(para: '30-71234567-1', titulo: 'Dos', texto: '');

    expect(repositorio.para('Sol').length, 1);
    expect(repositorio.para('30-71234567-1').length, 1);
  });

  test('los avisos siguen ahí después de reiniciar, con lo leído', () async {
    final almacen = AlmacenEnMemoria();
    const capacidades = Capacidades();

    final antes = repositorioCon(capacidades, almacen: almacen);
    await antes.avisar(para: 'Sol', titulo: 'Uno', texto: '');
    await antes.avisar(para: 'Sol', titulo: 'Dos', texto: '');
    await antes.marcarLeidas('Sol');
    await antes.avisar(para: 'Sol', titulo: 'Tres', texto: '');

    // Otra instancia sobre la misma base: es abrir la app de nuevo.
    final despues = repositorioCon(capacidades, almacen: almacen);
    await despues.cargar();

    expect(despues.para('Sol').length, 3);
    expect(despues.para('Sol').first.titulo, 'Tres'); // el más nuevo arriba
    expect(despues.sinLeerDe('Sol'), 1);
  });

  group('permiso del usuario', () {
    test('con permiso, además sale la notificación del sistema', () async {
      final sistema = NotificacionesFalsas(permiso: true);
      final repositorio = repositorioCon(const Capacidades(), sistema: sistema);

      await repositorio.avisar(para: 'Sol', titulo: 'Llegó', texto: '');

      expect(sistema.mostradas, ['Llegó']);
    });

    test('sin permiso, el aviso queda en la bandeja pero el sistema no '
        'muestra nada: la app sigue siendo útil', () async {
      final sistema = NotificacionesFalsas(permiso: false);
      final repositorio = repositorioCon(const Capacidades(), sistema: sistema);

      final mandado = await repositorio.avisar(
        para: 'Sol',
        titulo: 'Llegó',
        texto: '',
      );

      expect(mandado, isTrue);
      expect(repositorio.sinLeerDe('Sol'), 1);
      expect(sistema.mostradas, isEmpty);
    });

    test('sin permiso no se programa ningún recordatorio', () async {
      final sistema = NotificacionesFalsas(permiso: false);
      final repositorio = repositorioCon(const Capacidades(), sistema: sistema);

      await repositorio.programar(
        id: 7,
        titulo: 'Calificá',
        texto: '',
        cuando: DateTime.now().add(const Duration(days: 1)),
      );

      expect(sistema.programadas, isEmpty);
    });

    test('pedir el permiso lo deja activado', () async {
      final sistema = NotificacionesFalsas(permiso: false);
      final repositorio = repositorioCon(const Capacidades(), sistema: sistema);

      expect(await repositorio.tienePermiso(), isFalse);
      expect(await repositorio.pedirPermiso(), isTrue);
      expect(await repositorio.tienePermiso(), isTrue);
    });
  });
}
