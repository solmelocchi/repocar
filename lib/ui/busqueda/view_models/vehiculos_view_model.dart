// El ViewModel importa foundation (por ChangeNotifier), NO material:
// no conoce widgets ni BuildContext.
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/vehiculos_repository.dart';
import '../../../domain/models/auto.dart';
import '../../core/estado_carga.dart';

// =====================================================================
// VIEWMODEL (capa de UI)
// · Guarda el estado de la pantalla: cargando, éxito o error.
// · Ofrece COMANDOS que la vista engancha a los botones: cargar().
// · Solo conoce al repositorio, nunca al servicio.
// =====================================================================
class VehiculosViewModel extends ChangeNotifier {
  VehiculosViewModel({required VehiculosRepository repositorio})
    : _repositorio = repositorio {
    // Si por atrás llega una lista más nueva, la pantalla se actualiza
    // sola (el repositorio avisa por un Stream).
    _suscripcion = _repositorio.actualizaciones.listen((nuevos) {
      _vehiculos = nuevos;
      _estado = EstadoCarga.exito;
      notifyListeners();
    });
  }

  final VehiculosRepository _repositorio;
  late final StreamSubscription<List<ModeloVehiculo>> _suscripcion;

  EstadoCarga _estado = EstadoCarga.cargando;
  EstadoCarga get estado => _estado;

  List<ModeloVehiculo> _vehiculos = [];
  List<ModeloVehiculo> get vehiculos => List.unmodifiable(_vehiculos);

  List<String> get marcas =>
      _vehiculos.map((v) => v.marca).toSet().toList()..sort();

  List<ModeloVehiculo> modelosDe(String marca) =>
      _vehiculos.where((v) => v.marca == marca).toList();

  /// Los años en que se fabricó ese modelo, del más nuevo al más viejo.
  List<int> aniosDe(String marca, String modelo) {
    for (final v in _vehiculos) {
      if (v.marca == marca && v.modelo == modelo) {
        return [for (var a = v.hasta; a >= v.desde; a--) a];
      }
    }
    return [];
  }

  Future<void> cargar() async {
    _estado = EstadoCarga.cargando;
    notifyListeners(); // la vista muestra el indicador de carga

    try {
      _vehiculos = await _repositorio.obtenerVehiculos();
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

  @override
  void dispose() {
    _suscripcion.cancel();
    super.dispose();
  }
}
