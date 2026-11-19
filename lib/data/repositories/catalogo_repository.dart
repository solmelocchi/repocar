import 'dart:async';
import 'dart:typed_data';

import '../../domain/cuit.dart';
import '../../domain/models/auto.dart';
import '../../domain/models/pieza.dart';
import '../local/fotos_locales.dart';
import '../procesamiento/achicar_foto.dart';
import '../services/catalogo_service.dart';
import 'cuentas_repository.dart';

// =====================================================================
// REPOSITORIO: el catálogo de publicaciones.
// · Le pide el crudo al servicio.
// · Resuelve el taller de cada pieza preguntándole al repositorio de
//   cuentas: en el JSON viene solo el CUIT.
// · Guarda la lista, que es la fuente de verdad del catálogo. Lo que se
//   publica y lo que se vende pasa por la base.
// =====================================================================
class CatalogoRepository {
  CatalogoRepository({
    required CatalogoService servicio,
    required CuentasRepository cuentas,
    FotosLocales fotos = const FotosLocales(),
  }) : _servicio = servicio,
       _cuentas = cuentas,
       _fotos = fotos;

  final CatalogoService _servicio;
  final CuentasRepository _cuentas;
  final FotosLocales _fotos;

  /// Todas, vendidas incluidas: un pedido viejo las tiene que mostrar.
  final List<Pieza> _todas = [];
  bool _cargado = false;

  // Avisa que algo cambió desde el servidor (otro teléfono publicó,
  // vendió o editó). Lo escucha el view model para redibujar.
  final _cambios = StreamController<void>.broadcast();
  Stream<void> get cambios => _cambios.stream;
  StreamSubscription<List<Map<String, dynamic>>>? _delServidor;

  /// Lo último publicado primero, como en cualquier marketplace.
  List<Pieza> get piezas => List.unmodifiable(_todas.reversed);

  Future<List<Pieza>> obtenerPiezas() async {
    if (_cargado) return piezas;

    // Sin los talleres no se puede armar una pieza, así que primero eso.
    await _cuentas.cargar();
    final crudas = await _servicio.obtenerPiezas();

    _todas.clear();
    for (final cruda in crudas) {
      final taller = _cuentas.buscarTallerPorCuit(
        soloNumeros(cruda['taller_cuit'] as String),
      );
      // Una publicación de un taller que no existe no se muestra.
      if (taller == null) continue;
      _todas.add(Pieza.desdeJson(cruda, taller));
    }

    _cargado = true;
    // Desde ahora, lo que cambie en el servidor llega solo (Stream).
    _delServidor ??= _servicio.cambiosDelServidor().listen(_aplicarDelServidor);
    return piezas;
  }

  /// Lo que llega del servidor: piezas nuevas de otros talleres, ventas
  /// y ediciones. Se compara con lo que hay, y si algo cambió se avisa.
  /// Lo que hizo este mismo teléfono vuelve igual y no cambia nada.
  Future<void> _aplicarDelServidor(List<Map<String, dynamic>> crudas) async {
    var cambio = false;
    for (final cruda in crudas) {
      final llegada = await _armar(cruda);
      if (llegada == null) continue;

      final lugar = _todas.indexWhere((p) => p.id == llegada.id);
      if (lugar == -1) {
        _todas.add(llegada);
        cambio = true;
      } else if (!_mismosDatos(_todas[lugar], llegada)) {
        _todas[lugar] = llegada;
        cambio = true;
      } else if (_todas[lugar].vendida != llegada.vendida ||
          _todas[lugar].pausada != llegada.pausada ||
          _todas[lugar].borrada != llegada.borrada) {
        // Solo cambió si está a la venta: se marca la MISMA pieza (el
        // carrito y los pedidos la tienen).
        _todas[lugar]
          ..vendida = llegada.vendida
          ..pausada = llegada.pausada
          ..borrada = llegada.borrada;
        cambio = true;
      }
    }
    if (cambio) _cambios.add(null);
  }

  /// Arma una pieza cruda. Si es de un taller que se registró en otro
  /// teléfono después de abrir la app, primero se vuelven a leer las
  /// cuentas.
  Future<Pieza?> _armar(Map<String, dynamic> cruda) async {
    final cuit = soloNumeros(cruda['taller_cuit'] as String);
    var taller = _cuentas.buscarTallerPorCuit(cuit);
    if (taller == null) {
      await _cuentas.recargar();
      taller = _cuentas.buscarTallerPorCuit(cuit);
    }
    return taller == null ? null : Pieza.desdeJson(cruda, taller);
  }

  static bool _mismosDatos(Pieza a, Pieza b) =>
      a.titulo == b.titulo &&
      a.descripcion == b.descripcion &&
      a.precio == b.precio &&
      a.estado == b.estado &&
      a.icono == b.icono &&
      (a.foto == null) == (b.foto == null) &&
      a.compatibles.length == b.compatibles.length;

  /// Para un pedido que llega del servidor con una pieza que todavía no
  /// tenemos (la publicaron recién en otro teléfono): se la trae.
  Future<Pieza?> buscarOTraer(String id) async {
    final ya = buscarPorId(id);
    if (ya != null) return ya;
    for (final cruda in await _servicio.obtenerPiezas()) {
      if (cruda['id'] != id) continue;
      final pieza = await _armar(cruda);
      if (pieza != null) _todas.add(pieza);
      return pieza;
    }
    return null;
  }

  Pieza? buscarPorId(String id) {
    for (final pieza in _todas) {
      if (pieza.id == id) return pieza;
    }
    return null;
  }

  /// Las que le sirven a ese auto y todavía se pueden comprar.
  List<Pieza> paraAuto(Auto auto) =>
      piezas.where((p) => p.aLaVenta && p.sirvePara(auto)).toList();

  /// Las del taller, vendidas incluidas: las ve con el cartel "Vendido".
  List<Pieza> deTaller(String cuit) =>
      piezas.where((p) => p.taller.cuit == cuit && !p.borrada).toList();

  /// Con el servidor, dos teléfonos pueden publicar a la vez: un número
  /// correlativo chocaría. La hora (en base 36) no se repite.
  String get proximoId =>
      'p${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';

  /// Prepara la foto que sacó el taller: la achica en OTRO ISOLATE (es
  /// cálculo pesado) y la guarda en un archivo. Devuelve la referencia
  /// que va en la pieza.
  Future<String> guardarFoto(String id, Uint8List original) async {
    final chica = await achicarFotoAparte(original);
    return _fotos.guardar(id, chica);
  }

  Future<void> publicar(Pieza pieza) async {
    // Primero en la lista y después a la base: cuando el servidor
    // devuelve el eco de esto mismo, ya está y no se duplica.
    _todas.add(pieza);
    await _servicio.guardar(_aCrudo(pieza));
  }

  /// Guarda la versión nueva de una publicación (mismo id). En la base
  /// la fila se reemplaza; en la lista, también, en el mismo lugar.
  /// Los pedidos viejos no cambian: guardan la pieza como era al comprar.
  Future<void> editar(Pieza editada) async {
    final lugar = _todas.indexWhere((p) => p.id == editada.id);
    if (lugar == -1) {
      _todas.add(editada);
    } else {
      _todas[lugar] = editada;
    }
    await _servicio.guardar(_aCrudo(editada));
  }

  /// Sacarla de la venta por un tiempo, o volver a publicarla.
  Future<void> pausar(Pieza pieza, {required bool pausada}) async {
    pieza.pausada = pausada;
    await _servicio.guardar(_aCrudo(pieza));
  }

  /// Borrarla: deja de verse, pero queda guardada para los pedidos.
  Future<void> borrar(Pieza pieza) async {
    pieza.borrada = true;
    await _servicio.guardar(_aCrudo(pieza));
  }

  Future<void> marcarVendida(Pieza pieza) async {
    pieza.vendida = true;
    await _servicio.guardar(_aCrudo(pieza));
  }

  Map<String, dynamic> _aCrudo(Pieza pieza) => {
    'id': pieza.id,
    'titulo': pieza.titulo,
    'descripcion': pieza.descripcion,
    'precio': pieza.precio,
    'estado': pieza.estado.clave,
    'taller_cuit': pieza.taller.cuit,
    'icono': pieza.icono,
    'compatibles': [
      for (final c in pieza.compatibles)
        {
          'marca': c.marca,
          'modelo': c.modelo,
          'desde': c.desde,
          'hasta': c.hasta,
        },
    ],
    'foto': pieza.foto,
    'vendida': pieza.vendida,
    'pausada': pieza.pausada,
    'borrada': pieza.borrada,
  };
}
