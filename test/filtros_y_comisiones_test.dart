import 'package:flutter_test/flutter_test.dart';

import 'package:repocar/data/local/almacen_memoria.dart';
import 'package:repocar/data/repositories/catalogo_repository.dart';
import 'package:repocar/data/repositories/cuentas_repository.dart';
import 'package:repocar/data/repositories/pedidos_repository.dart';
import 'package:repocar/data/services/catalogo_service.dart';
import 'package:repocar/data/services/cuentas_service.dart';
import 'package:repocar/data/services/pedidos_service.dart';
import 'package:repocar/domain/cuit.dart';
import 'package:repocar/domain/filtro_de_pedidos.dart';
import 'package:repocar/domain/models/auto.dart';
import 'package:repocar/domain/models/envio.dart';
import 'package:repocar/domain/models/pedido.dart';
import 'package:repocar/domain/models/pieza.dart';
import 'package:repocar/domain/models/taller.dart';
import 'package:repocar/ui/admin/view_models/comisiones_view_model.dart';

final _taller = Taller(nombre: 'El Torno', telefono: '', zona: 'San Rafael');

Pieza _pieza(String titulo) => Pieza(
  id: titulo,
  titulo: titulo,
  descripcion: '',
  precio: 10000,
  estado: EstadoPieza.usado,
  taller: _taller,
  icono: 'build',
  compatibles: const [Compatibilidad('Fiat', 'Cronos', 2018, 2024)],
);

Pedido _pedido(
  String numero,
  int diasAtras, {
  String cliente = 'Sol Melocchi',
  String pieza = 'Amortiguador',
  EstadoPedido estado = EstadoPedido.pagado,
}) => Pedido(
  numero: numero,
  fecha: DateTime.now().subtract(Duration(days: diasAtras)),
  cliente: cliente,
  taller: _taller,
  items: [ItemCarrito(_pieza(pieza))],
  entrega: MetodoEntrega.retiro,
  comisionPct: 0.10,
  estado: estado,
);

void main() {
  group('Buscar, filtrar y ordenar pedidos', () {
    final pedidos = [
      _pedido('#1044', 2, cliente: 'Diego Funes', pieza: 'Alternador'),
      _pedido('#2003', 7, estado: EstadoPedido.enviado),
      _pedido('#999', 1, cliente: 'Bruno Olaiz', pieza: 'Radiador'),
    ];

    test('por fecha: los más nuevos o los más viejos primero', () {
      expect(filtrarPedidos(pedidos).map((p) => p.numero), [
        '#999',
        '#1044',
        '#2003',
      ]);
      expect(
        filtrarPedidos(
          pedidos,
          orden: OrdenDePedidos.masViejos,
        ).map((p) => p.numero),
        ['#2003', '#1044', '#999'],
      );
    });

    test('por número, como número y no como texto', () {
      expect(
        filtrarPedidos(
          pedidos,
          orden: OrdenDePedidos.porNumero,
        ).map((p) => p.numero),
        ['#2003', '#1044', '#999'],
      );
    });

    test('se busca por número (con o sin #), comprador o repuesto', () {
      expect(filtrarPedidos(pedidos, texto: '#2003').single.numero, '#2003');
      expect(filtrarPedidos(pedidos, texto: '1044').single.numero, '#1044');
      expect(filtrarPedidos(pedidos, texto: 'bruno').single.numero, '#999');
      expect(
        filtrarPedidos(pedidos, texto: 'alternador').single.numero,
        '#1044',
      );
    });

    test('y por estado', () {
      expect(
        filtrarPedidos(pedidos, estado: EstadoPedido.enviado).single.numero,
        '#2003',
      );
    });

    test('el período del resumen', () {
      final ahora = DateTime(2026, 11, 24);
      expect(PeriodoDeResumen.semana.desde(ahora), DateTime(2026, 11, 17));
      expect(PeriodoDeResumen.todo.desde(ahora), isNull);
    });
  });

  group('La comisión de cada taller', () {
    test('en la promoción no paga comisión, y la promoción termina sola', () {
      final taller = Taller(
        nombre: 'Nuevo',
        telefono: '',
        zona: 'San Rafael',
        sinComisionHasta: DateTime(2027, 2, 24),
      );
      expect(taller.comisionVigente(DateTime(2027, 1, 1)), 0);
      expect(taller.comisionVigente(DateTime(2027, 3, 1)), 0.10);
    });

    test('solo valen porcentajes entre 0 y 30', () {
      expect(comisionValida(0), isTrue);
      expect(comisionValida(0.05), isTrue);
      expect(comisionValida(0.5), isFalse);
      expect(comisionValida(-0.1), isFalse);
    });

    test('un pedido hecho durante la promoción queda sin comisión, y uno '
        'hecho después, con la del taller', () async {
      final almacen = AlmacenEnMemoria();
      final cuentas = CuentasRepository(
        servicio: const CuentasService(demora: Duration.zero),
        almacen: almacen,
      );
      final catalogo = CatalogoRepository(
        servicio: CatalogoService(almacen: almacen, demora: Duration.zero),
        cuentas: cuentas,
      );
      final pedidos = PedidosRepository(
        servicio: PedidosService(almacen: almacen, demora: Duration.zero),
        catalogo: catalogo,
        cuentas: cuentas,
      );
      final piezas = await catalogo.obtenerPiezas();
      final taller = piezas.first.taller;
      final dos = piezas.where((p) => p.taller == taller).take(2).toList();

      taller.sinComisionHasta = DateTime.now().add(duracionDeLaPromocion);
      final enPromocion = await pedidos.confirmarCompra([
        CompraTaller(
          taller: taller,
          items: [ItemCarrito(dos[0])],
          entrega: MetodoEntrega.retiro,
        ),
      ], 'Sol Melocchi');

      taller.sinComisionHasta = null; // terminó
      final despues = await pedidos.confirmarCompra([
        CompraTaller(
          taller: taller,
          items: [ItemCarrito(dos[1])],
          entrega: MetodoEntrega.retiro,
        ),
      ], 'Sol Melocchi');

      expect(enPromocion.single.comisionPct, 0);
      expect(enPromocion.single.comision, 0);
      expect(despues.single.comisionPct, taller.comision);
    });

    test('Ramallo la cambia desde el panel y queda guardada', () async {
      final almacen = AlmacenEnMemoria();
      CuentasRepository abrir() => CuentasRepository(
        servicio: const CuentasService(demora: Duration.zero),
        almacen: almacen,
      );
      final cuentas = abrir();
      await cuentas.cargar();
      final taller = cuentas.talleres.first;
      final comisiones = ComisionesViewModel(repositorio: cuentas);

      expect(
        await comisiones.cambiar(taller, porcentaje: 0.05, promocion: true),
        isTrue,
      );
      expect(taller.enPromocion(DateTime.now()), isTrue);

      // Se cierra la app y se vuelve a abrir: sigue igual.
      final otraVez = abrir();
      await otraVez.cargar();
      final guardado = otraVez.buscarTallerPorCuit(soloNumeros(taller.cuit))!;
      expect(guardado.comision, 0.05);
      expect(guardado.enPromocion(DateTime.now()), isTrue);

      // Un error de tipeo no se guarda.
      expect(
        await comisiones.cambiar(taller, porcentaje: 0.5, promocion: false),
        isFalse,
      );
      expect(comisiones.error, contains('30%'));
      expect(taller.comision, 0.05);
    });
  });
}
