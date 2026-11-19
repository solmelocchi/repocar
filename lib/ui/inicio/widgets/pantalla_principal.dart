import 'package:flutter/material.dart';

import '../../../dependencias.dart';
import '../../admin/widgets/inicio_admin.dart';
import '../../ingreso/widgets/ingreso_screen.dart';
import '../../taller/widgets/taller_screen.dart';
import 'inicio_comprador.dart';

/// A dónde va cada uno según quién tiene la sesión: el taller a su
/// panel, TalleresYa al de administración, el comprador al catálogo, y
/// si no hay nadie, a iniciar sesión.
///
/// Está en un solo lugar: lo usan el arranque de la app (con la sesión
/// recordada) y la pantalla de ingreso.
Widget pantallaPrincipal(Dependencias deps) {
  final sesion = deps.sesion;
  if (sesion.hayTaller) return TallerScreen(deps: deps);
  if (sesion.esAdmin) return InicioAdmin(deps: deps);
  if (sesion.hayCliente) return InicioComprador(deps: deps);
  return IngresoScreen(deps: deps);
}
