import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/borrador_repository.dart';
import '../../../data/repositories/catalogo_repository.dart';
import '../../../domain/models/auto.dart';
import '../../../domain/models/pieza.dart';
import '../../../domain/models/taller.dart';
import '../../core/estado_carga.dart';

// =====================================================================
// VIEWMODEL del catálogo: lo que ve el comprador en el inicio y lo que
// publica el taller (con su foto y su borrador).
// =====================================================================
class CatalogoViewModel extends ChangeNotifier {
  CatalogoViewModel({
    required CatalogoRepository repositorio,
    BorradorRepository? borradores,
  }) : _repositorio = repositorio,
       _borradores = borradores ?? BorradorRepository() {
    // Lo que cambia en el servidor (otro teléfono) se redibuja solo.
    _suscripcion = _repositorio.cambios.listen((_) => _refrescar());
  }

  late final StreamSubscription<void> _suscripcion;

  @override
  void dispose() {
    _suscripcion.cancel();
    super.dispose();
  }

  final CatalogoRepository _repositorio;
  final BorradorRepository _borradores;

  /// Achica la foto en otro isolate y la guarda. Devuelve la referencia.
  Future<String> guardarFoto(String id, Uint8List original) =>
      _repositorio.guardarFoto(id, original);

  // --- El borrador de lo que el taller está publicando ---

  Future<void> guardarBorrador(String cuit, Map<String, dynamic> datos) =>
      _borradores.guardar(cuit, datos);

  Future<Map<String, dynamic>?> leerBorrador(String cuit) =>
      _borradores.leer(cuit);

  Future<void> borrarBorrador(String cuit) => _borradores.borrar(cuit);

  EstadoCarga _estado = EstadoCarga.cargando;
  EstadoCarga get estado => _estado;

  List<Pieza> _piezas = [];
  List<Pieza> get piezas => List.unmodifiable(_piezas);

  /// Lo que se puede comprar: las vendidas, pausadas y borradas no
  /// aparecen.
  List<Pieza> get disponibles =>
      _piezas.where((pieza) => pieza.aLaVenta).toList();

  /// El corazón del sistema: solo lo que le sirve a ESE auto.
  List<Pieza> paraAuto(Auto auto) => _repositorio.paraAuto(auto);

  List<Pieza> deTaller(Taller taller) => _repositorio.deTaller(taller.cuit);

  String get proximoId => _repositorio.proximoId;

  /// La versión de ahora de una pieza (si la editaron, la nueva).
  Pieza? buscarPorId(String id) => _repositorio.buscarPorId(id);

  /// El buscador del inicio. Los filtros se suman:
  ///   · auto: solo lo que le sirve (marca, modelo y año)
  ///   · rubro: la clave del ícono (frenos, motor, eléctrico...)
  ///   · texto: lo que escribió, en el título o la descripción
  /// Siempre solo lo que se puede comprar.
  List<Pieza> filtrar({String texto = '', String? rubro, Auto? auto}) {
    final buscado = texto.trim().toLowerCase();
    return disponibles
        .where((p) => auto == null || p.sirvePara(auto))
        .where((p) => rubro == null || p.icono == rubro)
        .where(
          (p) =>
              buscado.isEmpty ||
              p.titulo.toLowerCase().contains(buscado) ||
              p.descripcion.toLowerCase().contains(buscado),
        )
        .toList();
  }

  Future<void> cargar() async {
    _estado = EstadoCarga.cargando;
    notifyListeners();

    try {
      _piezas = await _repositorio.obtenerPiezas();
      _estado = EstadoCarga.exito;
    } catch (_) {
      _estado = EstadoCarga.error;
    } finally {
      // Se ejecuta SIEMPRE, haya error o no: la vista siempre se entera
      // de que terminó la carga (aunque el catch volviera a lanzar el
      // error, o alguien lo cambiara por un "on" que no atrape todo).
      notifyListeners();
    }
  }

  // --- Comandos: después de cada uno, la lista se vuelve a leer y se
  //     avisa, así el inicio, los resultados y el taller se actualizan.

  Future<void> publicar(Pieza pieza) async {
    await _repositorio.publicar(pieza);
    _refrescar();
  }

  Future<void> pausar(Pieza pieza, {required bool pausada}) async {
    await _repositorio.pausar(pieza, pausada: pausada);
    _refrescar();
  }

  Future<void> borrar(Pieza pieza) async {
    await _repositorio.borrar(pieza);
    _refrescar();
  }

  Future<void> editar(Pieza editada) async {
    await _repositorio.editar(editada);
    _refrescar();
  }

  /// Lo llama la compra: el repuesto deja de estar a la venta.
  Future<void> marcarVendida(Pieza pieza) async {
    await _repositorio.marcarVendida(pieza);
    _refrescar();
  }

  /// Vuelve a leer la lista del repositorio y avisa. Lo usa la compra,
  /// que deja repuestos vendidos desde otro view model.
  void refrescarVista() => _refrescar();

  void _refrescar() {
    _piezas = _repositorio.piezas;
    notifyListeners();
  }
}
