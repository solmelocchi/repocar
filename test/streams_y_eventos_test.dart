import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:repocar/data/local/almacen_memoria.dart';
import 'package:repocar/data/procesamiento/achicar_foto.dart';
import 'package:repocar/data/repositories/catalogo_repository.dart';
import 'package:repocar/data/repositories/cuentas_repository.dart';
import 'package:repocar/data/repositories/notificaciones_repository.dart';
import 'package:repocar/data/repositories/pedidos_repository.dart';
import 'package:repocar/data/services/catalogo_service.dart';
import 'package:repocar/data/services/cuentas_service.dart';
import 'package:repocar/data/services/pedidos_service.dart';
import 'package:repocar/domain/models/envio.dart';
import 'package:repocar/domain/models/pedido.dart';
import 'package:repocar/domain/politica_de_avisos.dart';
import 'package:repocar/plataforma/capacidades.dart';
import 'package:repocar/plataforma/segundo_plano.dart';
import 'package:repocar/ui/notificaciones/view_models/notificaciones_view_model.dart';
import 'package:repocar/ui/pedidos/view_models/pedidos_view_model.dart';
import 'package:repocar/ui/sistema/view_models/conexion_view_model.dart';

import 'fakes.dart';

const _rapido = Duration(milliseconds: 1);

/// La app armada como en dependencias.dart, con el sistema de
/// notificaciones falso para ver qué se mostró y qué se programó.
Future<
  ({
    PedidosRepository repo,
    PedidosViewModel vm,
    CatalogoRepository catalogo,
    NotificacionesFalsas sistema,
  })
>
armar() async {
  final almacen = AlmacenEnMemoria();
  final cuentas = CuentasRepository(
    servicio: const CuentasService(demora: _rapido),
    almacen: almacen,
  );
  final catalogo = CatalogoRepository(
    servicio: CatalogoService(almacen: almacen, demora: _rapido),
    cuentas: cuentas,
  );
  final repo = PedidosRepository(
    servicio: PedidosService(almacen: almacen, demora: _rapido),
    catalogo: catalogo,
    cuentas: cuentas,
  );
  final sistema = NotificacionesFalsas();
  final avisos = NotificacionesViewModel(
    repositorio: NotificacionesRepository(
      servicio: sistema,
      capacidades: const Capacidades(),
      almacen: almacen,
    ),
  );
  final vm = PedidosViewModel(repositorio: repo, notificaciones: avisos);
  await vm.cargar();
  return (repo: repo, vm: vm, catalogo: catalogo, sistema: sistema);
}

Future<Pedido> comprarAlternador(
  PedidosViewModel vm,
  CatalogoRepository catalogo,
) async {
  final alternador = catalogo.buscarPorId('p1')!;
  final nuevos = await vm.confirmarCompra([
    CompraTaller(
      taller: alternador.taller,
      items: [ItemCarrito(alternador)],
      entrega: MetodoEntrega.retiro,
    ),
  ], 'Sol Melocchi');
  return nuevos.single;
}

void main() {
  group('Stream de cambios de pedidos', () {
    test('cada cambio sale por el Stream, en orden', () async {
      final app = await armar();
      final tipos = <TipoDeCambio>[];
      final suscripcion = app.repo.cambios.listen((c) => tipos.add(c.tipo));

      final pedido = await comprarAlternador(app.vm, app.catalogo);
      await app.vm.cambiarEstado(pedido, EstadoPedido.entregado);
      await app.vm.calificar(pedido, 5, 'Impecable');
      await pumpEventQueue();

      expect(tipos, [
        TipoDeCambio.nuevo,
        TipoDeCambio.estado,
        TipoDeCambio.calificacion,
      ]);
      await suscripcion.cancel();
    });

    test('el view model escucha: un pedido nuevo le avisa al taller', () async {
      final app = await armar();

      final pedido = await comprarAlternador(app.vm, app.catalogo);
      await pumpEventQueue();

      expect(app.sistema.mostradas, ['Pedido nuevo ${pedido.numero}']);
    });

    test('al entregarse se programa el recordatorio de calificar, y al '
        'calificar se cancela', () async {
      final app = await armar();
      final pedido = await comprarAlternador(app.vm, app.catalogo);
      final id = PoliticaDeAvisos.idRecordatorio(pedido.numero);

      await app.vm.cambiarEstado(pedido, EstadoPedido.entregado);
      await pumpEventQueue();
      expect(app.sistema.programadas.containsKey(id), isTrue);
      // Para dentro de un día, no para ya.
      expect(
        app.sistema.programadas[id]!.isAfter(
          DateTime.now().add(const Duration(hours: 23)),
        ),
        isTrue,
      );

      await app.vm.calificar(pedido, 5, 'Impecable');
      await pumpEventQueue();
      expect(app.sistema.programadas.containsKey(id), isFalse);
    });

    test('al cerrar el view model se cancela la suscripción', () async {
      final app = await armar();
      app.vm.dispose();

      // Con la suscripción cancelada, un pedido nuevo ya no avisa.
      await app.repo.confirmarCompra([
        CompraTaller(
          taller: app.catalogo.buscarPorId('p1')!.taller,
          items: [ItemCarrito(app.catalogo.buscarPorId('p1')!)],
          entrega: MetodoEntrega.retiro,
        ),
      ], 'Sol Melocchi');
      await pumpEventQueue();

      expect(app.sistema.mostradas, isEmpty);
    });
  });

  group('Conexión (evento del sistema)', () {
    test(
      'arranca con el estado de ahora, no espera al primer cambio',
      () async {
        final vm = ConexionViewModel(
          conectividad: ConectividadFalsa(ahora: false),
        );
        await vm.iniciar();

        expect(vm.hayRed, isFalse);
        vm.dispose();
      },
    );

    test('se va y vuelve la red: avisa, y al volver reintenta', () async {
      final red = ConectividadFalsa();
      var reintentos = 0;
      final vm = ConexionViewModel(
        conectividad: red,
        alVolver: () => reintentos++,
      );
      await vm.iniciar();

      red.cambiar(false);
      await pumpEventQueue();
      expect(vm.hayRed, isFalse);
      expect(reintentos, 0);

      red.cambiar(true);
      await pumpEventQueue();
      expect(vm.hayRed, isTrue);
      expect(reintentos, 1);

      vm.dispose();
    });

    test('dispose cancela la suscripción al Stream', () async {
      final red = ConectividadFalsa();
      final vm = ConexionViewModel(conectividad: red);
      await vm.iniciar();
      expect(red.alguienEscucha, isTrue);

      vm.dispose();
      expect(red.alguienEscucha, isFalse);
    });
  });

  group('Isolate: achicar la foto', () {
    Uint8List fotoDe(int ancho, int alto) =>
        img.encodeJpg(img.Image(width: ancho, height: alto));

    test('una foto grande queda de 1000 px de ancho, sin deformarse', () {
      final chica = img.decodeImage(achicarFoto(fotoDe(4000, 3000)))!;

      expect(chica.width, anchoMaximo);
      expect(chica.height, 750);
    });

    test('una foto chica no se agranda', () {
      final igual = img.decodeImage(achicarFoto(fotoDe(800, 600)))!;

      expect(igual.width, 800);
    });

    test('corre en otro isolate con compute y devuelve los bytes', () async {
      final chica = await achicarFotoAparte(fotoDe(3000, 2000));

      expect(img.decodeImage(chica)!.width, anchoMaximo);
    });
  });

  group('Segundo plano', () {
    Map<String, dynamic> pedido(String numero, String cuit, DateTime f) => {
      'numero': numero,
      'fecha': f.toIso8601String(),
      'cliente': 'Sol Melocchi',
      'taller_cuit': cuit,
      'items': const [],
      'entrega': 'retiro',
      'direccion': '',
      'costo_envio': 0,
      'comision_pct': 0.1,
      'estado': 'pagado',
    };

    test('avisa solo los pedidos del taller que llegaron después de lo '
        'último que vio, del más viejo al más nuevo', () async {
      final almacen = AlmacenEnMemoria();
      final servicio = PedidosService(almacen: almacen, demora: _rapido);
      final visto = DateTime(2026, 11, 17, 12);
      const ramallo = '30-71234567-1';

      await almacen.guardarPedido(
        pedido('#2001', ramallo, visto.subtract(const Duration(minutes: 5))),
      );
      await almacen.guardarPedido(
        pedido('#2003', ramallo, visto.add(const Duration(minutes: 9))),
      );
      await almacen.guardarPedido(
        pedido('#2002', ramallo, visto.add(const Duration(minutes: 2))),
      );
      await almacen.guardarPedido(
        pedido('#2004', '27-23456789-1', visto.add(const Duration(minutes: 3))),
      );

      final nuevos = await pedidosNuevos(servicio, ramallo, desde: visto);

      expect(nuevos.map((p) => p['numero']), ['#2002', '#2003']);
    });

    test(
      'con uno: "Pedido nuevo #2003" y "Sol Melocchi te hizo un pedido"',
      () {
        final uno = [pedido('#2003', '30-71234567-1', DateTime(2026))];

        expect(tituloDeNuevos(uno), 'Pedido nuevo #2003');
        expect(textoDeNuevos(uno), 'Sol Melocchi te hizo un pedido');
      },
    );

    test('con varios: cuántos en el título y un renglón por pedido', () {
      final varios = [
        pedido('#2003', '30-71234567-1', DateTime(2026)),
        {
          ...pedido('#2004', '30-71234567-1', DateTime(2026)),
          'cliente': 'Bruno',
        },
      ];

      expect(tituloDeNuevos(varios), '2 pedidos nuevos');
      expect(
        textoDeNuevos(varios),
        '#2003 – Sol Melocchi te hizo un pedido\n'
        '#2004 – Bruno te hizo un pedido',
      );
    });

    test(
      'los pedidos de ejemplo (sin fecha) nunca cuentan como nuevos',
      () async {
        final servicio = PedidosService(
          almacen: AlmacenEnMemoria(),
          demora: _rapido,
        );

        final nuevos = await pedidosNuevos(
          servicio,
          '30-71234567-1',
          desde: DateTime(2000),
        );

        expect(nuevos, isEmpty);
      },
    );
  });
}
