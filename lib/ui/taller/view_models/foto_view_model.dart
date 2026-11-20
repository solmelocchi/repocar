import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/catalogo_repository.dart';
import '../../../data/services/fuente_de_fotos.dart';
import '../../../plataforma/capacidades.dart';

// =====================================================================
// VIEWMODEL de la foto de una publicación.
//
// Elegir una foto tiene TRES resultados, y cada uno se trata distinto:
//   · una foto  → se achica (en otro isolate), se guarda y reemplaza a
//                 la anterior, que se borra;
//   · null      → el usuario se arrepintió: no cambia nada, sin mensaje;
//   · un error  → se muestra el mensaje y la foto anterior se conserva.
//
// Hay uno por pantalla de publicar (lo arma dependencias.dart).
// =====================================================================
class FotoViewModel extends ChangeNotifier {
  FotoViewModel({
    required FuenteDeFotos fuente,
    required CatalogoRepository repositorio,
    required Capacidades capacidades,
    required String idPieza,
    String? inicial,
  }) : _fuente = fuente,
       _repositorio = repositorio,
       _capacidades = capacidades,
       _idPieza = idPieza,
       _original = inicial,
       _referencia = inicial;

  final FuenteDeFotos _fuente;
  final CatalogoRepository _repositorio;
  final Capacidades _capacidades;
  final String _idPieza;

  /// La foto que ya estaba publicada (editando). No se borra hasta que
  /// se guarden los cambios: si el taller se va sin guardar, la
  /// publicación la sigue usando.
  final String? _original;

  String? _referencia;
  bool _cargando = false;
  String? _error;
  bool _puedeUsarCamara = false;
  bool _puedeUsarGaleria = false;

  /// La foto elegida, ya achicada y guardada (null si no hay).
  String? get referencia => _referencia;

  /// Mientras se abre la cámara y se achica la foto.
  bool get cargando => _cargando;

  /// El mensaje si algo falló de verdad (null si no).
  String? get error => _error;

  bool get puedeUsarCamara => _puedeUsarCamara;

  bool get puedeUsarGaleria => _puedeUsarGaleria;

  /// Si hay de dónde sacar una foto. Si no, la sección no se dibuja.
  bool get hayDeDonde => _puedeUsarCamara || _puedeUsarGaleria;

  /// CAPACIDADES: el botón que no se puede usar no se muestra, en vez de
  /// fallar al tocarlo.
  Future<void> consultarCapacidades() async {
    try {
      _puedeUsarCamara = await _capacidades.tieneCamara();
      _puedeUsarGaleria = await _capacidades.tieneGaleria();
    } finally {
      notifyListeners();
    }
  }

  Future<void> elegir(OrigenDeFoto origen) async {
    if (_cargando) return; // evita abrir la cámara dos veces
    _cargando = true;
    _error = null;
    notifyListeners();
    try {
      final foto = await _fuente.elegir(origen);
      if (foto != null) await _usar(foto); // null: canceló, no pasa nada
    } on ErrorDeFoto catch (error) {
      _error = error.mensaje; // la foto anterior se conserva
    } catch (_) {
      _error = 'No se pudo guardar la foto.';
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  Future<void> _usar(Foto foto) async {
    // Se achica en otro isolate (compute) y se guarda en la carpeta de
    // documentos de la app, que no se borra sola.
    final nueva = await _repositorio.guardarFoto(_idPieza, foto.bytes);
    final anterior = _referencia;
    _referencia = nueva;
    await _soltar(anterior);
  }

  /// "Sin foto".
  void quitar() {
    final anterior = _referencia;
    _referencia = null;
    _error = null;
    notifyListeners();
    unawaited(_soltar(anterior));
  }

  /// La foto que había en el borrador (se sacó antes de que la app se
  /// cerrara).
  void restaurar(String? referencia) {
    _referencia = referencia;
    notifyListeners();
  }

  /// Se guardaron los cambios: si la foto publicada se reemplazó, ahora
  /// sí ya no la usa nadie y se borra.
  Future<void> confirmarGuardado() async {
    final original = _original;
    if (original != null && original != _referencia) {
      await _repositorio.borrarFoto(original);
    }
  }

  /// Borra una foto que se sacó en esta pantalla y ya no se usa. La
  /// original no: se borra recién al guardar.
  Future<void> _soltar(String? referencia) async {
    if (referencia == null || referencia == _original) return;
    try {
      await _repositorio.borrarFoto(referencia);
    } catch (_) {}
  }
}
