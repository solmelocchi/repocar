import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:repocar/data/local/almacen_local.dart';
import 'package:repocar/data/local/almacen_memoria.dart';
import 'package:repocar/data/local/almacen_preferencias.dart';
import 'package:repocar/data/repositories/catalogo_repository.dart';
import 'package:repocar/data/repositories/cuentas_repository.dart';
import 'package:repocar/data/repositories/pedidos_repository.dart';
import 'package:repocar/data/services/pedidos_service.dart';
import 'package:repocar/data/services/catalogo_service.dart';
import 'package:repocar/data/services/cuentas_service.dart';
import 'package:repocar/domain/cuit.dart';
import 'package:repocar/domain/models/auto.dart';
import 'package:repocar/domain/models/envio.dart';
import 'package:repocar/domain/models/pedido.dart';
import 'package:repocar/domain/models/pieza.dart';
import 'package:repocar/domain/models/taller.dart';

const _rapido = Duration(milliseconds: 1);

/// Arma la app como la arma main(), pero sobre una base que ya existe.
/// Cada llamada simula abrirla de nuevo: todo nuevo, menos la base.
({CatalogoRepository catalogo, CuentasRepository cuentas}) abrirLaApp(
  AlmacenLocal almacen,
) {
  final cuentas = CuentasRepository(
    servicio: const CuentasService(demora: _rapido),
    almacen: almacen,
  );
  return (
    catalogo: CatalogoRepository(
      servicio: CatalogoService(almacen: almacen, demora: _rapido),
      cuentas: cuentas,
    ),
    cuentas: cuentas,
  );
}

Pieza piezaDe(Taller taller, String id, String titulo) => Pieza(
  id: id,
  titulo: titulo,
  descripcion: 'Probada, sin fallas.',
  precio: 70000,
  estado: EstadoPieza.reacondicionado,
  taller: taller,
  icono: 'electric_bolt',
  compatibles: const [Compatibilidad('Fiat', 'Cronos', 2018, 2024)],
);

Future<void> publicarYVerificar(AlmacenLocal almacen) async {
  final app = abrirLaApp(almacen);
  final piezas = await app.catalogo.obtenerPiezas();

  await app.catalogo.publicar(
    piezaDe(piezas.first.taller, app.catalogo.proximoId, 'Bobina de encendido'),
  );
  expect(
    app.catalogo.piezas.any((p) => p.titulo == 'Bobina de encendido'),
    isTrue,
    reason: 'tiene que aparecer en el momento',
  );

  // Se cierra la app y se abre de nuevo.
  final despues = abrirLaApp(almacen);
  final piezasDespues = await despues.catalogo.obtenerPiezas();

  expect(
    piezasDespues.any((p) => p.titulo == 'Bobina de encendido'),
    isTrue,
    reason: 'tiene que seguir estando después de reiniciar',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('en el navegador, lo publicado sobrevive a recargar', () async {
    SharedPreferences.setMockInitialValues({});
    await publicarYVerificar(AlmacenPreferencias());
  });

  test('lo que publica el taller sigue estando al reiniciar la app', () async {
    await publicarYVerificar(AlmacenEnMemoria());
  });

  test('un taller que se registra sobrevive, y su repuesto también', () async {
    SharedPreferences.setMockInitialValues({});
    final almacen = AlmacenPreferencias();
    const cuit = '20-31222333-4';

    // --- Primera corrida: se registra un taller nuevo y publica.
    final app = abrirLaApp(almacen);
    await app.cuentas.cargar();

    final nuevo = Taller(
      nombre: 'Taller de Prueba',
      telefono: '+54 9 260 400-0000',
      zona: 'San Rafael',
      cuit: cuit,
    );
    await app.cuentas.agregarTaller(nuevo, 'clave-secreta');

    await app.catalogo.obtenerPiezas();
    await app.catalogo.publicar(
      piezaDe(nuevo, app.catalogo.proximoId, 'Tapa de cilindros'),
    );

    // --- Se reinicia la app.
    final despues = abrirLaApp(almacen);
    await despues.cuentas.cargar();

    // El taller sigue existiendo...
    final recuperado = despues.cuentas.buscarTallerPorCuit(soloNumeros(cuit));
    expect(recuperado, isNotNull);
    expect(recuperado!.nombre, 'Taller de Prueba');

    // ...puede volver a entrar...
    expect(
      despues.cuentas.claveCorrecta(soloNumeros(cuit), 'clave-secreta'),
      isTrue,
    );
    expect(despues.cuentas.claveCorrecta(soloNumeros(cuit), 'otra'), isFalse);

    // ...y su repuesto no quedó huérfano.
    final piezas = await despues.catalogo.obtenerPiezas();
    expect(piezas.any((p) => p.titulo == 'Tapa de cilindros'), isTrue);
  });

  test('la contraseña no se guarda, se guarda su huella', () async {
    SharedPreferences.setMockInitialValues({});
    final almacen = AlmacenPreferencias();
    final app = abrirLaApp(almacen);
    await app.cuentas.cargar();

    await app.cuentas.agregarTaller(
      Taller(
        nombre: 'Otro taller',
        telefono: '+54 9 260 400-0001',
        zona: 'Las Paredes',
        cuit: '20-31222333-4',
      ),
      'mi-clave',
    );

    final guardadas = await almacen.leerCuentas('claves');
    final texto = guardadas.toString();
    expect(texto.contains('mi-clave'), isFalse);
    expect(texto.length, greaterThan(40)); // está el hash
  });

  // ===================================================================
  // PEDIDOS: lo que se compra y todo lo que le pasa después tiene que
  // sobrevivir a cerrar la app.
  // ===================================================================
  group('Pedidos guardados', () {
    late AlmacenLocal almacen;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      almacen = AlmacenPreferencias();
    });

    /// Arma catálogo, cuentas y pedidos sobre la misma base, como main().
    Future<({CatalogoRepository catalogo, PedidosRepository pedidos})>
    abrir() async {
      final app = abrirLaApp(almacen);
      final pedidos = PedidosRepository(
        servicio: PedidosService(almacen: almacen, demora: _rapido),
        catalogo: app.catalogo,
        cuentas: app.cuentas,
      );
      await pedidos.obtenerPedidos();
      return (catalogo: app.catalogo, pedidos: pedidos);
    }

    Future<Pedido> comprarAlternador(
      PedidosRepository pedidos,
      CatalogoRepository catalogo,
    ) async {
      final alternador = catalogo.buscarPorId('p1')!;
      final nuevos = await pedidos.confirmarCompra([
        CompraTaller(
          taller: alternador.taller,
          items: [ItemCarrito(alternador)],
          entrega: MetodoEntrega.cadete,
          direccion: 'Av. Mitre 1240',
          costoEnvio: 3500,
        ),
      ], 'Sol Melocchi');
      return nuevos.single;
    }

    test('una compra sigue estando al reiniciar la app', () async {
      final app = await abrir();
      final pedido = await comprarAlternador(app.pedidos, app.catalogo);

      final despues = await abrir();
      final recuperado = despues.pedidos.deCliente('Sol Melocchi').single;

      expect(recuperado.numero, pedido.numero);
      expect(recuperado.total, pedido.total);
      expect(recuperado.direccion, 'Av. Mitre 1240');
      expect(recuperado.estado, EstadoPedido.pagado);
    });

    test(
      'el estado, la calificación y la respuesta también se guardan',
      () async {
        final app = await abrir();
        final pedido = await comprarAlternador(app.pedidos, app.catalogo);
        await app.pedidos.cambiarEstado(pedido, EstadoPedido.entregado);
        await app.pedidos.calificar(pedido, 4, 'Llegó bien');
        await app.pedidos.responder(pedido, 'Gracias por la compra');

        final despues = await abrir();
        final recuperado = despues.pedidos.deCliente('Sol Melocchi').single;

        expect(recuperado.estado, EstadoPedido.entregado);
        expect(recuperado.calificacion!.estrellas, 4);
        expect(recuperado.calificacion!.comentario, 'Llegó bien');
        expect(recuperado.calificacion!.respuesta, 'Gracias por la compra');
      },
    );

    test(
      'lo comprado deja de estar a la venta, también al reiniciar',
      () async {
        const gol = Auto(marca: 'Volkswagen', modelo: 'Gol Trend', anio: 2014);
        final app = await abrir();
        expect(app.catalogo.paraAuto(gol).any((p) => p.id == 'p1'), isTrue);

        await comprarAlternador(app.pedidos, app.catalogo);
        expect(app.catalogo.paraAuto(gol).any((p) => p.id == 'p1'), isFalse);

        final despues = await abrir();
        expect(
          despues.catalogo.paraAuto(gol).any((p) => p.id == 'p1'),
          isFalse,
        );
        // Pero sigue existiendo: el pedido lo tiene que poder mostrar.
        expect(despues.catalogo.buscarPorId('p1')!.vendida, isTrue);
      },
    );

    test('los números de pedido siguen después de reiniciar', () async {
      final app = await abrir();
      final primero = await comprarAlternador(app.pedidos, app.catalogo);

      // Al reiniciar, la próxima compra no puede repetir el número:
      // pisaría al pedido anterior en la base.
      final despues = await abrir();
      final radiador = despues.catalogo.buscarPorId('p7')!;
      final segundo = (await despues.pedidos.confirmarCompra([
        CompraTaller(
          taller: radiador.taller,
          items: [ItemCarrito(radiador)],
          entrega: MetodoEntrega.retiro,
        ),
      ], 'Sol Melocchi')).single;

      expect(segundo.numero, isNot(primero.numero));
      final otraVez = await abrir();
      expect(otraVez.pedidos.deCliente('Sol Melocchi').length, 2);
    });

    test('marcar en camino un pedido de ejemplo también se guarda', () async {
      final app = await abrir();
      final ejemplo = app.pedidos.todos.firstWhere((p) => p.numero == '#1044');
      await app.pedidos.cambiarEstado(ejemplo, EstadoPedido.enviado);

      final despues = await abrir();
      final recuperado = despues.pedidos.todos.firstWhere(
        (p) => p.numero == '#1044',
      );
      expect(recuperado.estado, EstadoPedido.enviado);
    });
  });
}
