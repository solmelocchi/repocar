import 'dart:async';

import '../../domain/cuit.dart';
import '../../domain/models/envio.dart';
import '../../domain/models/pedido.dart';
import '../../domain/models/taller.dart';
import '../services/pedidos_service.dart';
import 'catalogo_repository.dart';
import 'cuentas_repository.dart';

/// Se quiso comprar una pieza que ya no está a la venta.
class PiezaNoDisponible implements Exception {
  const PiezaNoDisponible(this.titulo);

  final String titulo;

  @override
  String toString() => '$titulo ya no está disponible';
}

/// Qué le pasó a un pedido.
enum TipoDeCambio { nuevo, estado, calificacion, respuesta }

/// Un evento del Stream de pedidos: cuál cambió y qué le pasó.
typedef CambioDePedido = ({Pedido pedido, TipoDeCambio tipo});

// =====================================================================
// REPOSITORIO: los pedidos.
// Para armar un pedido necesita el catálogo (los items vienen como id
// de pieza) y las cuentas (el taller viene como CUIT). Eso es normal:
// un repositorio puede apoyarse en otro, mientras no suba de capa.
//
// Todo cambio de un pedido se guarda: la compra, el estado, la
// calificación y la respuesta del taller.
//
// Además, cada cambio sale por un STREAM (cambios). Un pedido cambia
// varias veces a lo largo del tiempo (se paga, se envía, se entrega, se
// califica): eso es justo lo que modela un Stream. Hoy los cambios se
// producen en este mismo teléfono; cuando esté el servidor, los de
// otros teléfonos van a entrar por este mismo Stream, y la app no se
// entera de la diferencia.
// =====================================================================
class PedidosRepository {
  PedidosRepository({
    required PedidosService servicio,
    required CatalogoRepository catalogo,
    required CuentasRepository cuentas,
  }) : _servicio = servicio,
       _catalogo = catalogo,
       _cuentas = cuentas;

  final PedidosService _servicio;
  final CatalogoRepository _catalogo;
  final CuentasRepository _cuentas;

  final List<Pedido> _pedidos = [];
  bool _cargado = false;

  /// El último número usado. Se calcula al cargar, porque puede haber
  /// pedidos guardados de otras veces.
  int _ultimoNumero = 1050;

  /// Desde dónde numera el servidor.
  static const _primeroDelServidor = 2000;

  List<Pedido> get todos => List.unmodifiable(_pedidos);

  // Broadcast: lo pueden escuchar varios (el view model de pedidos y,
  // más adelante, el que sincroniza con el servidor). El controlador
  // queda privado: afuera solo se ve el stream, para que nadie más
  // pueda meter eventos.
  final _cambios = StreamController<CambioDePedido>.broadcast();

  StreamSubscription<List<Map<String, dynamic>>>? _delServidor;

  /// Cada cambio de un pedido, a medida que pasa.
  Stream<CambioDePedido> get cambios => _cambios.stream;

  void _avisarCambio(Pedido pedido, TipoDeCambio tipo) =>
      _cambios.add((pedido: pedido, tipo: tipo));

  /// Cierra el Stream: los que lo escuchaban reciben el evento de fin.
  Future<void> cerrar() => _cambios.close();

  Future<List<Pedido>> obtenerPedidos() async {
    if (_cargado) return todos;

    await _catalogo.obtenerPiezas();
    final crudos = await _servicio.obtenerPedidos();

    _pedidos
      ..clear()
      ..addAll(crudos.map(_armar).whereType<Pedido>());
    _pedidos.forEach(_anotarNumero);

    _cargado = true;
    // Desde ahora, lo que cambie en el servidor llega solo (Stream).
    _delServidor ??= _servicio.cambiosDelServidor().listen(_aplicarDelServidor);
    return todos;
  }

  /// Traduce un pedido crudo a un Pedido. Null si le falta el taller o
  /// las piezas (un dato roto no rompe la lista).
  Pedido? _armar(Map<String, dynamic> crudo) {
    final taller = _cuentas.buscarTallerPorCuit(
      soloNumeros(crudo['taller_cuit'] as String),
    );
    if (taller == null) return null;

    final items = <ItemCarrito>[];
    for (final item in crudo['items'] as List) {
      final mapa = item as Map<String, dynamic>;
      final pieza = _catalogo.buscarPorId(mapa['pieza_id'] as String);
      if (pieza == null) continue;
      items.add(ItemCarrito(pieza, cantidad: mapa['cantidad'] as int));
    }
    if (items.isEmpty) return null;

    // Los de ejemplo traen "hace cuántos días"; los guardados, la fecha.
    final fecha = crudo['fecha'] != null
        ? DateTime.parse(crudo['fecha'] as String)
        : DateTime.now().subtract(Duration(days: crudo['dias_atras'] as int));

    return Pedido(
      numero: crudo['numero'] as String,
      fecha: fecha,
      cliente: crudo['cliente'] as String,
      taller: taller,
      items: items,
      entrega: _entregaDesde(crudo['entrega'] as String),
      direccion: crudo['direccion'] as String,
      costoEnvio: crudo['costo_envio'] as int,
      comisionPct: (crudo['comision_pct'] as num).toDouble(),
      estado: _estadoDesde(crudo['estado'] as String),
      calificacion: _calificacionDesde(
        crudo['calificacion'] as Map<String, dynamic>?,
      ),
    );
  }

  /// El número más alto visto, para que el próximo pedido siga desde ahí.
  void _anotarNumero(Pedido pedido) {
    final numero = int.tryParse(soloNumeros(pedido.numero)) ?? 0;
    if (numero > _ultimoNumero) _ultimoNumero = numero;
  }

  /// Lo que llega del servidor: pedidos que hicieron en otros teléfonos
  /// y cambios de estado, calificaciones y respuestas. Se compara con lo
  /// que hay, y cada diferencia sale por el MISMO Stream de cambios que
  /// usa este teléfono. Así, el view model avisa igual, venga de donde
  /// venga. Lo que hizo este mismo teléfono vuelve igual y no cambia nada.
  Future<void> _aplicarDelServidor(List<Map<String, dynamic>> crudos) async {
    for (final crudo in crudos) {
      final actual = _buscar(crudo['numero'] as String);

      if (actual == null) {
        // Un pedido nuevo de otro teléfono. Si trae piezas o un taller
        // que todavía no conocemos, primero se traen.
        for (final item in crudo['items'] as List) {
          await _catalogo.buscarOTraer(
            (item as Map<String, dynamic>)['pieza_id'] as String,
          );
        }
        if (_cuentas.buscarTallerPorCuit(
              soloNumeros(crudo['taller_cuit'] as String),
            ) ==
            null) {
          await _cuentas.recargar();
        }
        final nuevo = _armar(crudo);
        if (nuevo == null || _buscar(nuevo.numero) != null) continue;
        _pedidos.add(nuevo);
        _anotarNumero(nuevo);
        _avisarCambio(nuevo, TipoDeCambio.nuevo);
        continue;
      }

      final estado = _estadoDesde(crudo['estado'] as String);
      if (estado != actual.estado) {
        actual.estado = estado;
        _avisarCambio(actual, TipoDeCambio.estado);
      }

      final calificacion = _calificacionDesde(
        crudo['calificacion'] as Map<String, dynamic>?,
      );
      if (calificacion != null && actual.calificacion == null) {
        actual.calificacion = calificacion;
        _avisarCambio(actual, TipoDeCambio.calificacion);
      } else if (calificacion?.respuesta != null &&
          actual.calificacion?.respuesta == null) {
        actual.calificacion?.respuesta = calificacion!.respuesta;
        _avisarCambio(actual, TipoDeCambio.respuesta);
      }
    }
  }

  Pedido? _buscar(String numero) {
    for (final pedido in _pedidos) {
      if (pedido.numero == numero) return pedido;
    }
    return null;
  }

  /// Arma un pedido por cada taller de la compra, lo da por pagado, lo
  /// guarda, y deja vendidos los repuestos: son usados, hay uno solo.
  Future<List<Pedido>> confirmarCompra(
    List<CompraTaller> compras,
    String cliente,
  ) async {
    await obtenerPedidos();

    // Última barrera: si alguna pieza ya no está a la venta (otro la
    // compró y llegó por el Stream del servidor), no se arma nada.
    for (final compra in compras) {
      for (final item in compra.items) {
        if (!item.pieza.aLaVenta) throw PiezaNoDisponible(item.pieza.titulo);
      }
    }

    final nuevos = <Pedido>[];

    for (final compra in compras) {
      // El número lo da el SERVIDOR: si cada teléfono contara solo, dos
      // podrían darle el mismo número a pedidos distintos, y el del taller
      // creería que ya lo tenía (y no avisaría). Los del servidor arrancan
      // en #2001, así no chocan con los que quedaron de las pruebas viejas,
      // guardados solo en algún teléfono. Sin señal, cuenta el teléfono.
      final delServidor = await _servicio.numeroDelServidor(
        _ultimoNumero < _primeroDelServidor
            ? _primeroDelServidor
            : _ultimoNumero,
      );
      _ultimoNumero = delServidor ?? _ultimoNumero + 1;
      final pedido = Pedido(
        numero: '#$_ultimoNumero',
        fecha: DateTime.now(),
        cliente: cliente,
        taller: compra.taller,
        items: compra.items,
        entrega: compra.entrega,
        direccion: compra.direccion,
        costoEnvio: compra.costoEnvio,
        comisionPct: compra.taller.comision, // se congela acá
      );

      // Primero en la lista y después a la base: cuando el servidor
      // devuelve el eco de este pedido, ya está y no se duplica.
      _pedidos.add(pedido);
      nuevos.add(pedido);

      await _servicio.guardar(_aCrudo(pedido));
      for (final item in pedido.items) {
        await _catalogo.marcarVendida(item.pieza);
      }
      _avisarCambio(pedido, TipoDeCambio.nuevo);
    }

    return nuevos;
  }

  Future<void> cambiarEstado(Pedido pedido, EstadoPedido estado) async {
    pedido.estado = estado;
    await _servicio.guardar(_aCrudo(pedido));
    _avisarCambio(pedido, TipoDeCambio.estado);
  }

  Future<void> calificar(
    Pedido pedido,
    int estrellas,
    String comentario,
  ) async {
    pedido.calificacion = Calificacion(
      estrellas: estrellas,
      comentario: comentario,
    );
    await _servicio.guardar(_aCrudo(pedido));
    _avisarCambio(pedido, TipoDeCambio.calificacion);
  }

  Future<void> responder(Pedido pedido, String respuesta) async {
    pedido.calificacion?.respuesta = respuesta;
    await _servicio.guardar(_aCrudo(pedido));
    _avisarCambio(pedido, TipoDeCambio.respuesta);
  }

  List<Pedido> deTaller(Taller taller) =>
      _pedidos.where((p) => p.taller.cuit == taller.cuit).toList()
        ..sort((a, b) => b.fecha.compareTo(a.fecha));

  List<Pedido> deCliente(String nombre) =>
      _pedidos.where((p) => p.cliente == nombre).toList()
        ..sort((a, b) => b.fecha.compareTo(a.fecha));

  /// Los pedidos del último mes, que son los que mira TalleresYa.
  List<Pedido> get ultimos30Dias {
    final desde = DateTime.now().subtract(const Duration(days: 30));
    return _pedidos.where((p) => p.fecha.isAfter(desde)).toList();
  }

  /// El pedido como se guarda: igual que llegaría de un servidor.
  Map<String, dynamic> _aCrudo(Pedido pedido) {
    final calificacion = pedido.calificacion;
    return {
      'numero': pedido.numero,
      'fecha': pedido.fecha.toIso8601String(),
      'cliente': pedido.cliente,
      'taller_cuit': pedido.taller.cuit,
      'items': [
        for (final item in pedido.items)
          {'pieza_id': item.pieza.id, 'cantidad': item.cantidad},
      ],
      'entrega': pedido.entrega.clave,
      'direccion': pedido.direccion,
      'costo_envio': pedido.costoEnvio,
      'comision_pct': pedido.comisionPct,
      'estado': pedido.estado.clave,
      'calificacion': calificacion == null
          ? null
          : {
              'estrellas': calificacion.estrellas,
              'comentario': calificacion.comentario,
              'respuesta': calificacion.respuesta,
            },
    };
  }

  MetodoEntrega _entregaDesde(String clave) => switch (clave) {
    'cadete' => MetodoEntrega.cadete,
    'envio' => MetodoEntrega.envio,
    _ => MetodoEntrega.retiro,
  };

  EstadoPedido _estadoDesde(String clave) => switch (clave) {
    'enviado' => EstadoPedido.enviado,
    'entregado' => EstadoPedido.entregado,
    _ => EstadoPedido.pagado,
  };

  Calificacion? _calificacionDesde(Map<String, dynamic>? crudo) {
    if (crudo == null) return null;
    return Calificacion(
      estrellas: crudo['estrellas'] as int,
      comentario: crudo['comentario'] as String,
      respuesta: crudo['respuesta'] as String?,
    );
  }
}
