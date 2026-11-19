import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:repocar/data/local/almacen_memoria.dart';
import 'package:repocar/data/remoto/almacen_con_servidor.dart';
import 'package:repocar/data/remoto/base_remota.dart';
import 'package:repocar/data/repositories/catalogo_repository.dart';
import 'package:repocar/data/repositories/cuentas_repository.dart';
import 'package:repocar/data/repositories/notificaciones_repository.dart';
import 'package:repocar/data/repositories/pedidos_repository.dart';
import 'package:repocar/data/services/catalogo_service.dart';
import 'package:repocar/data/services/cuentas_service.dart';
import 'package:repocar/data/services/pedidos_service.dart';
import 'package:repocar/domain/models/auto.dart';
import 'package:repocar/domain/models/envio.dart';
import 'package:repocar/domain/models/pedido.dart';
import 'package:repocar/domain/models/pieza.dart';
import 'package:repocar/plataforma/capacidades.dart';
import 'package:repocar/ui/notificaciones/view_models/notificaciones_view_model.dart';
import 'package:repocar/ui/pedidos/view_models/pedidos_view_model.dart';

import 'fakes.dart';

// =====================================================================
// EL SERVIDOR, sin internet: dos "teléfonos" (cada uno con su base
// local) que comparten un servidor falso en memoria. Es lo mismo que
// hace Firestore, pero se puede probar acá.
// =====================================================================

/// Un Firestore de mentira: colecciones de documentos, y cada vez que
/// alguien guarda, los que escuchan esa colección reciben la lista nueva.
class ServidorFalso implements BaseRemota {
  final _colecciones = <String, Map<String, Map<String, dynamic>>>{};
  final _guardados = StreamController<String>.broadcast();

  List<Map<String, dynamic>> _lista(String coleccion) =>
      (_colecciones[coleccion] ?? {}).values.toList();

  @override
  Future<List<Map<String, dynamic>>> leer(
    String coleccion, {
    String? campo,
    Object? igualA,
  }) async =>
      _lista(coleccion)
          .where((dato) => campo == null || dato[campo] == igualA)
          .toList();

  @override
  Future<void> guardar(
    String coleccion,
    String id,
    Map<String, dynamic> dato,
  ) async {
    _colecciones.putIfAbsent(coleccion, () => {})[id] = dato;
    _guardados.add(coleccion);
  }

  int _contador = 0;

  @override
  Future<int> siguienteNumero(String contador, {required int minimo}) async {
    if (_contador < minimo) _contador = minimo;
    return ++_contador;
  }

  @override
  Stream<List<Map<String, dynamic>>> escuchar(String coleccion) async* {
    yield _lista(coleccion);
    await for (final cambiada in _guardados.stream) {
      if (cambiada == coleccion) yield _lista(coleccion);
    }
  }
}

/// Un servidor que no contesta nunca (sin señal).
class ServidorCaido implements BaseRemota {
  @override
  Future<List<Map<String, dynamic>>> leer(
    String coleccion, {
    String? campo,
    Object? igualA,
  }) => Completer<List<Map<String, dynamic>>>().future;

  @override
  Future<void> guardar(String c, String id, Map<String, dynamic> d) =>
      Completer<void>().future;

  @override
  Stream<List<Map<String, dynamic>>> escuchar(String coleccion) =>
      const Stream.empty();

  @override
  Future<int> siguienteNumero(String contador, {required int minimo}) =>
      Completer<int>().future;
}

const _rapido = Duration(milliseconds: 1);

/// Un teléfono: su propia base local, el servidor compartido, y la app
/// armada como en dependencias.dart.
typedef Telefono = ({
  CatalogoRepository catalogo,
  PedidosRepository pedidos,
  PedidosViewModel vm,
  NotificacionesFalsas sistema,
});

Future<Telefono> telefono(BaseRemota servidor) async {
  final base = AlmacenConServidor(
    local: AlmacenEnMemoria(),
    remota: servidor,
    limite: const Duration(milliseconds: 200),
  );
  final cuentas = CuentasRepository(
    servicio: const CuentasService(demora: _rapido),
    almacen: base,
  );
  final catalogo = CatalogoRepository(
    servicio: CatalogoService(almacen: base, demora: _rapido),
    cuentas: cuentas,
  );
  final pedidos = PedidosRepository(
    servicio: PedidosService(almacen: base, demora: _rapido),
    catalogo: catalogo,
    cuentas: cuentas,
  );
  final sistema = NotificacionesFalsas();
  final vm = PedidosViewModel(
    repositorio: pedidos,
    notificaciones: NotificacionesViewModel(
      repositorio: NotificacionesRepository(
        servicio: sistema,
        capacidades: const Capacidades(),
        almacen: base,
      ),
    ),
  );
  await vm.cargar();
  return (catalogo: catalogo, pedidos: pedidos, vm: vm, sistema: sistema);
}

/// Deja que los Streams entreguen lo que tienen pendiente.
Future<void> esperarAlServidor() =>
    Future.delayed(const Duration(milliseconds: 100));

Future<Pedido> comprar(Telefono tel, String idPieza) async {
  final pieza = tel.catalogo.buscarPorId(idPieza)!;
  final nuevos = await tel.vm.confirmarCompra([
    CompraTaller(
      taller: pieza.taller,
      items: [ItemCarrito(pieza)],
      entrega: MetodoEntrega.retiro,
    ),
  ], 'Sol Melocchi');
  return nuevos.single;
}

void main() {
  test('lo que compra el comprador en su celular le llega al taller en '
      'el suyo, con el aviso', () async {
    final servidor = ServidorFalso();
    final delComprador = await telefono(servidor);
    final delTaller = await telefono(servidor);

    final pedido = await comprar(delComprador, 'p1');
    await esperarAlServidor();

    // El pedido está en el otro teléfono...
    expect(
      delTaller.pedidos.todos.any((p) => p.numero == pedido.numero),
      isTrue,
    );
    // ...y le llegó la notificación al taller.
    expect(
      delTaller.sistema.mostradas,
      contains('Pedido nuevo ${pedido.numero}'),
    );
    // La pieza quedó vendida también allá.
    expect(delTaller.catalogo.buscarPorId('p1')!.vendida, isTrue);
  });

  test('el taller marca entregado en su celular y el comprador se entera '
      'en el suyo', () async {
    final servidor = ServidorFalso();
    final delComprador = await telefono(servidor);
    final delTaller = await telefono(servidor);
    final pedido = await comprar(delComprador, 'p1');
    await esperarAlServidor();

    final enElTaller = delTaller.pedidos.todos.firstWhere(
      (p) => p.numero == pedido.numero,
    );
    await delTaller.vm.cambiarEstado(enElTaller, EstadoPedido.entregado);
    await esperarAlServidor();

    expect(pedido.estado, EstadoPedido.entregado);
    expect(
      delComprador.sistema.mostradas,
      contains('Tu pedido ${pedido.numero} llegó'),
    );
  });

  test('el taller lo deja listo y el comprador se entera (retira en el '
      'taller, así que dice "listo", no "en camino")', () async {
    final servidor = ServidorFalso();
    final delComprador = await telefono(servidor);
    final delTaller = await telefono(servidor);
    final pedido = await comprar(delComprador, 'p1');
    await esperarAlServidor();

    final enElTaller = delTaller.pedidos.todos.firstWhere(
      (p) => p.numero == pedido.numero,
    );
    await delTaller.vm.cambiarEstado(enElTaller, EstadoPedido.enviado);
    await esperarAlServidor();

    expect(pedido.estado, EstadoPedido.enviado);
    expect(
      delComprador.sistema.mostradas,
      contains('Tu pedido ${pedido.numero} está listo'),
    );
  });

  test(
    'lo que hace un teléfono no se duplica cuando vuelve del servidor',
    () async {
      final servidor = ServidorFalso();
      final tel = await telefono(servidor);
      final antes = tel.pedidos.todos.length;

      final pedido = await comprar(tel, 'p1');
      await esperarAlServidor();

      expect(tel.pedidos.todos.length, antes + 1);
      expect(
        tel.sistema.mostradas.where(
          (t) => t == 'Pedido nuevo ${pedido.numero}',
        ),
        hasLength(1),
      );
    },
  );

  test(
    'una publicación nueva aparece en el catálogo del otro teléfono',
    () async {
      final servidor = ServidorFalso();
      final delTaller = await telefono(servidor);
      final otro = await telefono(servidor);
      final taller = delTaller.catalogo.buscarPorId('p1')!.taller;

      await delTaller.catalogo.publicar(
        Pieza(
          id: delTaller.catalogo.proximoId,
          titulo: 'Bobina de encendido',
          descripcion: 'Probada.',
          precio: 48000,
          estado: EstadoPieza.reacondicionado,
          taller: taller,
          icono: 'electric_bolt',
          compatibles: const [Compatibilidad('Fiat', 'Cronos', 2018, 2024)],
        ),
      );
      await esperarAlServidor();

      expect(
        otro.catalogo.piezas.any((p) => p.titulo == 'Bobina de encendido'),
        isTrue,
      );
    },
  );

  test('sin señal, la app sigue con lo del teléfono y no se traba', () async {
    final tel = await telefono(ServidorCaido());

    expect(tel.catalogo.piezas, isNotEmpty);
    final pedido = await comprar(tel, 'p1');
    expect(tel.pedidos.todos.any((p) => p.numero == pedido.numero), isTrue);
  });

  test('dos teléfonos que compran a la vez reciben números distintos, '
      'dados por el servidor', () async {
    final servidor = ServidorFalso();
    final uno = await telefono(servidor);
    final otro = await telefono(servidor);

    final (a, b) = await (comprar(uno, 'p1'), comprar(otro, 'p2')).wait;

    expect(a.numero, isNot(b.numero));
    expect(int.parse(a.numero.substring(1)), greaterThan(2000));
  });

  test(
    'si otro comprador ya se llevó la pieza, la compra no se arma',
    () async {
      final servidor = ServidorFalso();
      final uno = await telefono(servidor);
      final otro = await telefono(servidor);

      await comprar(uno, 'p1');
      await esperarAlServidor(); // al otro le llega que p1 se vendió

      expect(() => comprar(otro, 'p1'), throwsA(isA<PiezaNoDisponible>()));
    },
  );
}
