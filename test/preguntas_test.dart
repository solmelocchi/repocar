import 'package:flutter_test/flutter_test.dart';

import 'package:repocar/data/local/almacen_memoria.dart';
import 'package:repocar/data/repositories/notificaciones_repository.dart';
import 'package:repocar/data/repositories/preguntas_repository.dart';
import 'package:repocar/data/services/preguntas_service.dart';
import 'package:repocar/domain/models/auto.dart';
import 'package:repocar/domain/models/pieza.dart';
import 'package:repocar/domain/models/pregunta.dart';
import 'package:repocar/domain/models/taller.dart';
import 'package:repocar/plataforma/capacidades.dart';
import 'package:repocar/ui/notificaciones/view_models/notificaciones_view_model.dart';
import 'package:repocar/ui/preguntas/view_models/mis_preguntas_view_model.dart';
import 'package:repocar/ui/preguntas/view_models/preguntas_view_model.dart';

import 'fakes.dart';

const _cuit = '30-71234567-1';

final _pieza = Pieza(
  id: 'p1',
  titulo: 'Amortiguador delantero',
  descripcion: '',
  precio: 45000,
  estado: EstadoPieza.usado,
  taller: Taller(
    nombre: 'TalleresYa Ramallo',
    telefono: '',
    zona: 'San Rafael',
    cuit: _cuit,
  ),
  icono: 'build',
  compatibles: const [Compatibilidad('Volkswagen', 'Gol', 2008, 2016)],
);

void main() {
  group('La regla: en las preguntas no se pasan contactos', () {
    test('se rechazan teléfonos, mails y WhatsApp', () {
      expect(tieneDatosDeContacto('llamame al 2612501757'), isTrue);
      expect(tieneDatosDeContacto('mi cel 261 250-1757'), isTrue);
      expect(tieneDatosDeContacto('escribime a sol@mail.com'), isTrue);
      expect(tieneDatosDeContacto('pasame tu WhatsApp'), isTrue);
    });

    test('un auto y sus años no son un teléfono', () {
      expect(tieneDatosDeContacto('¿Le sirve a un Gol 2012?'), isFalse);
      expect(tieneDatosDeContacto('Sirve de 2008 a 2016'), isFalse);
    });
  });

  group('El repositorio valida', () {
    test('ni vacía, ni muy larga, ni con contactos', () {
      expect(
        () => PreguntasRepository.validar('   '),
        throwsA(isA<PreguntaInvalida>()),
      );
      expect(
        () => PreguntasRepository.validar('a' * 301),
        throwsA(isA<PreguntaInvalida>()),
      );
      expect(
        () => PreguntasRepository.validar('mi cel 2612501757'),
        throwsA(isA<PreguntaInvalida>()),
      );
      expect(
        PreguntasRepository.validar('  ¿Está probada?  '),
        '¿Está probada?',
      );
    });
  });

  group('La ficha (PreguntasViewModel)', () {
    late PreguntasRepository repositorio;
    late PreguntasViewModel ficha;

    setUp(() {
      repositorio = PreguntasRepository(servicio: PreguntasEnMemoria());
      ficha = PreguntasViewModel(
        repositorio: repositorio,
        pieza: _pieza,
        autor: () => 'Sol Melocchi',
      )..iniciar();
    });
    tearDown(() => ficha.dispose());

    test('la pregunta aparece sola en la lista (Stream)', () async {
      expect(await ficha.preguntar('¿Le sirve a un Gol 2012?'), isTrue);
      await pumpEventQueue();

      expect(ficha.preguntas.single.texto, '¿Le sirve a un Gol 2012?');
      expect(ficha.preguntas.single.autor, 'Sol Melocchi');
      expect(ficha.preguntas.single.respondida, isFalse);
    });

    test('con un teléfono no se envía y explica por qué', () async {
      expect(await ficha.preguntar('llamame al 2612501757'), isFalse);
      await pumpEventQueue();

      expect(ficha.preguntas, isEmpty);
      expect(ficha.error, contains('teléfonos'));
    });

    test('sin sesión de comprador no se puede preguntar', () {
      final sinSesion = PreguntasViewModel(
        repositorio: repositorio,
        pieza: _pieza,
        autor: () => null,
      );
      expect(sinSesion.puedePreguntar, isFalse);
      sinSesion.dispose();
    });
  });

  group('Los avisos (MisPreguntasViewModel)', () {
    late NotificacionesFalsas sistema;
    late NotificacionesViewModel avisos;
    late PreguntasEnMemoria servidor;
    late PreguntasRepository repositorio;

    setUp(() {
      sistema = NotificacionesFalsas();
      avisos = NotificacionesViewModel(
        repositorio: NotificacionesRepository(
          servicio: sistema,
          capacidades: const Capacidades(),
          almacen: AlmacenEnMemoria(),
        ),
      );
      servidor = PreguntasEnMemoria(quienSoy: 'uid-de-sol');
      repositorio = PreguntasRepository(servicio: servidor);
    });

    test('al taller le avisa la pregunta nueva y la muestra sin responder; '
        'al responderla, deja de estar pendiente', () async {
      final delTaller = MisPreguntasViewModel(
        repositorio: repositorio,
        avisos: avisos,
      )..seguirTaller(_cuit);
      await pumpEventQueue();
      expect(sistema.mostradas, isEmpty); // lo que ya había no se avisa

      await repositorio.preguntar(
        pieza: _pieza,
        autor: 'Sol Melocchi',
        texto: '¿Está probada?',
      );
      await pumpEventQueue();

      expect(sistema.mostradas, ['Pregunta nueva']);
      expect(delTaller.sinResponder, hasLength(1));

      final error = await delTaller.responder(
        delTaller.sinResponder.single,
        'Sí, la probamos en el banco.',
      );
      await pumpEventQueue();

      expect(error, isNull);
      expect(delTaller.sinResponder, isEmpty);
      delTaller.dispose();
    });

    test('al comprador le avisa cuando el taller le responde', () async {
      await repositorio.preguntar(
        pieza: _pieza,
        autor: 'Sol Melocchi',
        texto: '¿Está probada?',
      );
      final delComprador = MisPreguntasViewModel(
        repositorio: repositorio,
        avisos: avisos,
      )..seguirComprador('Sol Melocchi');
      await pumpEventQueue();
      expect(sistema.mostradas, isEmpty);

      final pregunta = (await repositorio.dePieza('p1').first).single;
      await repositorio.responder(pregunta, 'Sí, la probamos en el banco.');
      await pumpEventQueue();

      expect(sistema.mostradas, ['Te respondieron']);
      delComprador.dispose();
    });
  });
}
