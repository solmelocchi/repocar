import 'package:flutter/foundation.dart';

import '../../../data/repositories/cuentas_repository.dart';
import '../../../domain/models/taller.dart';

// =====================================================================
// VIEWMODEL de las comisiones: Ramallo cambia, desde su panel, cuánto le
// cobra a cada taller y si está en la promoción de bienvenida.
//
// La comisión NUEVA vale para los pedidos que vienen: los que ya se
// hicieron tienen la suya congelada.
// =====================================================================
class ComisionesViewModel extends ChangeNotifier {
  ComisionesViewModel({required CuentasRepository repositorio})
    : _repositorio = repositorio;

  final CuentasRepository _repositorio;

  bool _guardando = false;
  String? _error;

  bool get guardando => _guardando;

  String? get error => _error;

  /// [porcentaje] va como 0,10 para 10%. [promocion]: los primeros tres
  /// meses sin comisión. Devuelve true si se guardó.
  Future<bool> cambiar(
    Taller taller, {
    required double porcentaje,
    required bool promocion,
  }) async {
    if (!comisionValida(porcentaje)) {
      _error = 'La comisión tiene que estar entre 0 y 30%.';
      notifyListeners();
      return false;
    }
    final ahora = DateTime.now();
    final antes = (taller.comision, taller.sinComisionHasta);
    _guardando = true;
    _error = null;
    notifyListeners();
    try {
      taller
        ..comision = porcentaje
        // Si ya estaba en la promoción, sigue con la misma fecha de fin;
        // si es nueva, arranca hoy.
        ..sinComisionHasta = !promocion
            ? null
            : taller.enPromocion(ahora)
            ? taller.sinComisionHasta
            : ahora.add(duracionDeLaPromocion);
      await _repositorio.guardarTaller(taller);
      return true;
    } catch (_) {
      // Si no se pudo guardar, queda como estaba.
      taller
        ..comision = antes.$1
        ..sinComisionHasta = antes.$2;
      _error = 'No se pudo guardar. Probá de nuevo.';
      return false;
    } finally {
      _guardando = false;
      notifyListeners();
    }
  }
}
