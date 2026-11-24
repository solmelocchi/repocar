import 'package:flutter_test/flutter_test.dart';

import 'package:repocar/data/local/almacen_memoria.dart';
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
import 'package:repocar/domain/models/taller.dart';
import 'package:repocar/plataforma/capacidades.dart';
import 'package:repocar/ui/notificaciones/view_models/notificaciones_view_model.dart';
import 'package:repocar/ui/pedidos/view_models/pedidos_view_model.dart';

import 'fakes.dart';

Pedido _pedido({
  EstadoPedido estado = EstadoPedido.pagado,
  DateTime? entregadoEl,
  DateTime? fecha,
}) {
  final taller = Taller(nombre: 'El Torno', telefono: '', zona: 'San Rafael');
  return Pedido(
    numero: '#2010',
    fecha: fecha ?? DateTime(2026, 11, 1),
    cliente: 'Sol Melocchi',
    taller: taller,
    items: [
      ItemCarrito(
        Pieza(
          id: 'p1',
          titulo: 'Alternador',
          descripcion: '',
          precio: 50000,
          estado: EstadoPieza.usado,
          taller: taller,
          icono: 'build',
          compatibles: const [Compatibilidad('Fiat', 'Cronos', 2018, 2024)],
        ),
      ),
    ],
    entrega: MetodoEntrega.retiro,
    comisionPct: 0.10,
    estado: estado,
    entregadoEl: entregadoEl,
  );
}

void main() {
  group('El plazo para arrepentirse (Ley 24.240)', () {
    final entrega = DateTime(2026, 11, 10);

    test('antes de recibir la compra, se puede', () {
      expect(_pedido().puedeArrepentirse(DateTime(2026, 11, 20)), isTrue);
    });

    test('hasta 10 días corridos desde que la recibe', () {
      final pedido = _pedido(
        estado: EstadoPedido.entregado,
        entregadoEl: entrega,
      );
      expect(pedido.limiteParaArrepentirse, DateTime(2026, 11, 20));
      expect(pedido.puedeArrepentirse(DateTime(2026, 11, 15)), isTrue);
      expect(pedido.puedeArrepentirse(DateTime(2026, 11, 21)), isFalse);
    });

    test('una sola vez', () {
      final pedido = _pedido()..arrepentidoEl = DateTime(2026, 11, 2);
      expect(pedido.puedeArrepentirse(DateTime(2026, 11, 3)), isFalse);
    });

    test('un pedido viejo entregado, que no guardaba la entrega, cuenta '
        'desde la compra', () {
      final pedido = _pedido(estado: EstadoPedido.entregado);
      expect(pedido.limiteParaArrepentirse, DateTime(2026, 11, 11));
    });
  });

  test('el comprador se arrepiente: queda registrado y al taller le llega '
      'el aviso; la segunda vez no se puede', () async {
    final almacen = AlmacenEnMemoria();
    final cuentas = CuentasRepository(
      servicio: const CuentasService(demora: Duration.zero),
      almacen: almacen,
    );
    final catalogo = CatalogoRepository(
      servicio: CatalogoService(almacen: almacen, demora: Duration.zero),
      cuentas: cuentas,
    );
    final repositorio = PedidosRepository(
      servicio: PedidosService(almacen: almacen, demora: Duration.zero),
      catalogo: catalogo,
      cuentas: cuentas,
    );
    final sistema = NotificacionesFalsas();
    final vm = PedidosViewModel(
      repositorio: repositorio,
      notificaciones: NotificacionesViewModel(
        repositorio: NotificacionesRepository(
          servicio: sistema,
          capacidades: const Capacidades(),
          almacen: almacen,
        ),
      ),
    );
    final pieza = (await catalogo.obtenerPiezas()).first;
    final pedido = (await vm.confirmarCompra([
      CompraTaller(
        taller: pieza.taller,
        items: [ItemCarrito(pieza)],
        entrega: MetodoEntrega.retiro,
      ),
    ], 'Sol Melocchi')).single;

    await vm.cambiarEstado(pedido, EstadoPedido.entregado);
    expect(pedido.entregadoEl, isNotNull); // desde acá corren los 10 días

    expect(await vm.arrepentirse(pedido), isTrue);
    await pumpEventQueue();

    expect(pedido.arrepentido, isTrue);
    expect(
      sistema.mostradas,
      contains('Devolución del pedido ${pedido.numero}'),
    );
    expect(await vm.arrepentirse(pedido), isFalse);
    vm.dispose();
  });
}
