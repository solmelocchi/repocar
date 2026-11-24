import 'package:flutter_test/flutter_test.dart';

import 'package:repocar/data/repositories/preguntas_repository.dart';
import 'package:repocar/data/services/preguntas_service.dart';
import 'package:repocar/domain/control_de_ventas.dart';
import 'package:repocar/domain/models/auto.dart';
import 'package:repocar/domain/models/pieza.dart';
import 'package:repocar/domain/models/taller.dart';
import 'package:repocar/ui/admin/view_models/control_de_preguntas_view_model.dart';

final _taller = Taller(
  nombre: 'El Torno',
  telefono: '',
  zona: 'San Rafael',
  cuit: '20-12345678-6',
);

Pieza pieza(String id) => Pieza(
  id: id,
  titulo: 'Pieza $id',
  descripcion: '',
  precio: 10000,
  estado: EstadoPieza.usado,
  taller: _taller,
  icono: 'build',
  compatibles: const [Compatibilidad('Fiat', 'Cronos', 2018, 2024)],
);

void main() {
  group('La señal de una venta por fuera', () {
    test('tuvo preguntas y la pausaron o borraron sin venderla', () {
      expect(
        esSenalDeVentaPorFuera(pieza('a')..pausada = true, preguntas: 2),
        isTrue,
      );
      expect(
        esSenalDeVentaPorFuera(pieza('b')..borrada = true, preguntas: 1),
        isTrue,
      );
    });

    test('no es señal si se vendió por la app, si sigue a la venta o si '
        'nadie preguntó', () {
      expect(
        esSenalDeVentaPorFuera(
          pieza('a')
            ..vendida = true
            ..pausada = true,
          preguntas: 3,
        ),
        isFalse,
      );
      expect(esSenalDeVentaPorFuera(pieza('b'), preguntas: 3), isFalse);
      expect(
        esSenalDeVentaPorFuera(pieza('c')..pausada = true, preguntas: 0),
        isFalse,
      );
    });
  });

  test('el control de TalleresYa ve todas las preguntas, las que faltan '
      'responder y las publicaciones para revisar', () async {
    final conPreguntasYPausada = pieza('p1');
    final conPreguntasYVendida = pieza('p2');
    final catalogo = {'p1': conPreguntasYPausada, 'p2': conPreguntasYVendida};
    final repositorio = PreguntasRepository(servicio: PreguntasEnMemoria());

    await repositorio.preguntar(
      pieza: conPreguntasYPausada,
      autor: 'Sol',
      texto: '¿Está probada?',
    );
    await repositorio.preguntar(
      pieza: conPreguntasYVendida,
      autor: 'Bruno',
      texto: '¿Hacen envíos?',
    );

    final control = ControlDePreguntasViewModel(
      repositorio: repositorio,
      buscarPieza: (id) => catalogo[id],
    )..iniciar();
    await pumpEventQueue();

    expect(control.todas, hasLength(2));
    expect(control.sinResponder, 2);
    expect(control.paraRevisar, isEmpty); // las dos siguen a la venta

    // El taller pausa una sin venderla, y la otra se vende por la app.
    conPreguntasYPausada.pausada = true;
    conPreguntasYVendida.vendida = true;

    expect(control.paraRevisar.single.pieza.id, 'p1');
    expect(control.paraRevisar.single.motivo, 'la pausaron sin venderla');
    control.dispose();
  });
}
