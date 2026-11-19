import '../../domain/models/notificacion.dart';
import '../../plataforma/capacidades.dart';
import '../local/almacen_local.dart';
import '../services/notificaciones_service.dart';

// =====================================================================
// REPOSITORIO: la bandeja de avisos.
//
// Dos preguntas distintas antes de avisar:
//   1. CAPACIDAD: ¿la plataforma sabe notificar? Si no, no hay bandeja
//      ni campanita (la app no asume lo que el aparato no tiene).
//   2. PERMISO: ¿el usuario dejó? Si dijo que no, el aviso igual queda
//      en la bandeja de la app; lo único que no sale es la notificación
//      del sistema. La app sigue siendo útil sin el permiso.
//
// Los avisos se guardan en la base local, así la campanita sigue
// marcando lo que no leíste aunque cierres la app.
// =====================================================================
class NotificacionesRepository {
  NotificacionesRepository({
    required NotificacionesService servicio,
    required Capacidades capacidades,
    required AlmacenLocal almacen,
  }) : _servicio = servicio,
       _capacidades = capacidades,
       _almacen = almacen;

  final NotificacionesService _servicio;
  final Capacidades _capacidades;
  final AlmacenLocal _almacen;

  final List<Notificacion> _bandeja = [];
  bool _cargada = false;

  /// La respuesta de la consulta al dispositivo, guardada para no
  /// preguntar lo mismo en cada aviso.
  bool? _puede;

  Future<bool> sePuedeNotificar() async {
    return _puede ??= await _capacidades.puedeNotificar();
  }

  /// Si el usuario dio permiso. No se guarda: lo puede cambiar desde los
  /// ajustes del teléfono en cualquier momento.
  Future<bool> tienePermiso() async {
    if (!await sePuedeNotificar()) return false;
    return _servicio.tienePermiso();
  }

  Future<bool> pedirPermiso() async {
    if (!await sePuedeNotificar()) return false;
    return _servicio.pedirPermiso();
  }

  Future<void> iniciar() async {
    if (await sePuedeNotificar()) await _servicio.iniciar();
  }

  /// Los avisos que el usuario toca con la app abierta.
  Stream<String> get toques => _servicio.toques;

  Future<String?> avisoConElQueSeAbrio() => _servicio.avisoConElQueSeAbrio();

  /// Trae de la base los avisos de otras veces.
  Future<void> cargar() async {
    if (_cargada) return;
    await _almacen.abrir();
    final guardados = await _almacen.leerAvisos();
    _bandeja
      ..clear()
      ..addAll(guardados.map(Notificacion.desdeJson))
      ..sort((a, b) => a.fecha.compareTo(b.fecha));
    _cargada = true;
  }

  /// Los avisos de alguien, del más nuevo al más viejo.
  List<Notificacion> para(String destinatario) =>
      _bandeja.where((n) => n.para == destinatario).toList().reversed.toList();

  int sinLeerDe(String destinatario) =>
      _bandeja.where((n) => n.para == destinatario && !n.leida).length;

  /// Avisa, si la plataforma puede: lo anota en la bandeja y, si hay
  /// permiso, muestra la notificación del sistema. Devuelve si quedó.
  ///
  /// [idDelSistema]: para lo que cambia de estado (un pedido), siempre el
  /// mismo id, así el aviso nuevo reemplaza al viejo. Si no viene, uno
  /// nuevo cada vez.
  Future<bool> avisar({
    required String para,
    required String titulo,
    required String texto,
    String? payload,
    int? idDelSistema,
  }) async {
    if (!await anotar(para: para, titulo: titulo, texto: texto)) return false;

    // La notificación del sistema, solo si el usuario dio permiso.
    if (await _servicio.tienePermiso()) {
      await _servicio.mostrar(
        id:
            idDelSistema ??
            DateTime.now().millisecondsSinceEpoch.remainder(1 << 30),
        titulo: titulo,
        texto: texto,
        payload: payload,
      );
    }
    return true;
  }

  /// Solo lo anota en la bandeja, sin mostrar nada. Es para las push que
  /// ya mostró el sistema: cuando la tocan, queda también en la campanita.
  Future<bool> anotar({
    required String para,
    required String titulo,
    required String texto,
  }) async {
    if (!await sePuedeNotificar()) return false;
    await cargar();

    final ahora = DateTime.now();
    final aviso = Notificacion(
      // El largo de la bandeja va en el id: dos avisos en el mismo
      // instante no pueden pisarse.
      id: '$para-${ahora.microsecondsSinceEpoch}-${_bandeja.length}',
      titulo: titulo,
      texto: texto,
      para: para,
      fecha: ahora,
    );
    _bandeja.add(aviso);
    await _almacen.guardarAviso(aviso.aJson());
    return true;
  }

  /// Le deja al sistema un aviso para más tarde (aunque la app esté
  /// cerrada). Si no hay permiso, no se programa nada.
  Future<void> programar({
    required int id,
    required String titulo,
    required String texto,
    required DateTime cuando,
    String? payload,
  }) async {
    if (!await tienePermiso()) return;
    await _servicio.programar(
      id: id,
      titulo: titulo,
      texto: texto,
      cuando: cuando,
      payload: payload,
    );
  }

  Future<void> cancelar(int id) async {
    if (!await sePuedeNotificar()) return;
    await _servicio.cancelar(id);
  }

  Future<void> marcarLeidas(String destinatario) async {
    for (final aviso in _bandeja) {
      if (aviso.para == destinatario && !aviso.leida) {
        aviso.leida = true;
        await _almacen.guardarAviso(aviso.aJson());
      }
    }
  }
}
