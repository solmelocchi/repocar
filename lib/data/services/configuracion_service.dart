// =====================================================================
// SERVICIO: la configuración que decide TalleresYa desde el servidor.
// Es lo que permite cambiar reglas de la app sin publicar una versión
// nueva: el dueño toca un valor y a todos los teléfonos les llega.
// =====================================================================
class ConfiguracionService {
  const ConfiguracionService({
    Duration demora = const Duration(milliseconds: 500),
  }) : _demora = demora;

  final Duration _demora;

  Future<Map<String, dynamic>> obtenerConfiguracion() async {
    await Future.delayed(_demora);
    return const {'comision_default': 0.10, 'pagos_habilitados': true};
  }
}
