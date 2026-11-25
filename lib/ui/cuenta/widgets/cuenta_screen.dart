import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../dependencias.dart';
import '../../core/aviso.dart';
import '../../core/colores.dart';
import '../../ingreso/widgets/cerrar_sesion.dart';
import '../../ingreso/widgets/ingreso_screen.dart';
import '../../notificaciones/widgets/notificaciones_screen.dart';
import 'editar_perfil_screen.dart';

/// La pestaña Cuenta: quién sos, tus datos, los avisos y salir. Es la
/// misma para el comprador y para el taller; cambia lo que muestra.
class CuentaScreen extends StatefulWidget {
  final Dependencias deps;

  const CuentaScreen({super.key, required this.deps});

  @override
  State<CuentaScreen> createState() => _CuentaScreenState();
}

class _CuentaScreenState extends State<CuentaScreen> {
  @override
  void initState() {
    super.initState();
    // Para saber si el permiso de avisos está dado.
    widget.deps.notificaciones.consultarCapacidad();
  }

  Dependencias get _deps => widget.deps;

  /// A quién van dirigidos sus avisos: el CUIT o el nombre.
  String get _para =>
      _deps.sesion.taller?.cuit ??
      _deps.sesion.idComprador ??
      _deps.sesion.nombreComprador;

  @override
  Widget build(BuildContext context) {
    final sesion = _deps.sesion;
    final taller = sesion.taller;
    final cliente = sesion.cliente;

    final nombre = taller?.nombre ?? cliente?.nombre ?? 'Invitado';
    final iniciales = nombre
        .split(' ')
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();

    return Scaffold(
      appBar: AppBar(title: const Text('Mi cuenta')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- Quién sos ---
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: azul,
                    child: Text(
                      iniciales,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nombre,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          taller != null
                              ? 'Taller'
                              : sesion.esAdmin
                              ? 'Administración de TalleresYa'
                              : 'Comprador',
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          _titulo('Mis datos'),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                if (taller != null) ...[
                  _dato(Icons.badge_outlined, 'CUIT', taller.cuit),
                  _dato(Icons.place_outlined, 'Zona', taller.zona),
                  _dato(Icons.phone_outlined, 'Teléfono', taller.telefono),
                  _dato(
                    Icons.percent,
                    'Comisión de TalleresYa',
                    '${(taller.comision * 100).round()}%',
                  ),
                  _dato(
                    Icons.delivery_dining_outlined,
                    'Cadete propio',
                    taller.tieneCadete ? 'Sí' : 'No',
                  ),
                ] else if (cliente != null) ...[
                  _dato(Icons.alternate_email, 'Usuario', cliente.usuario),
                  _dato(Icons.phone_outlined, 'Teléfono', cliente.telefono),
                ],
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.edit_outlined, color: azul),
                  title: const Text(
                    'Editar mis datos',
                    style: TextStyle(color: azul, fontWeight: FontWeight.w600),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditarPerfilScreen(deps: _deps),
                      ),
                    );
                    // Al volver, se redibuja con los datos nuevos.
                    if (mounted) setState(() {});
                  },
                ),
              ],
            ),
          ),

          // El BOTÓN DE ARREPENTIMIENTO, a la vista (Resolución 424/2020):
          // lleva a "Pedidos", donde se elige qué compra devolver.
          if (_deps.sesion.hayCliente && !_deps.sesion.esAdmin) ...[
            _titulo('Compras'),
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.undo, color: Colors.red),
                title: const Text('Botón de arrepentimiento'),
                subtitle: const Text(
                  'Devolvé una compra dentro de los 10 días desde que la '
                  'recibís, sin dar explicaciones.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _deps.pestanaComprador.value = 2; // Pedidos
                  avisar(context, 'Elegí el pedido que querés devolver');
                },
              ),
            ),
          ],

          _titulo('Avisos'),
          Card(
            margin: EdgeInsets.zero,
            child: ListenableBuilder(
              listenable: _deps.notificaciones,
              builder: (context, _) {
                final avisos = _deps.notificaciones;
                if (!avisos.puedeNotificar) {
                  return const ListTile(
                    leading: Icon(Icons.notifications_off_outlined),
                    title: Text('Este dispositivo no muestra notificaciones'),
                  );
                }
                final sinLeer = avisos.sinLeerDe(_para);
                return Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.notifications_outlined),
                      title: const Text('Notificaciones del teléfono'),
                      subtitle: Text(
                        avisos.tienePermiso
                            ? 'Activadas. Para apagarlas, andá a los '
                                  'Ajustes del teléfono.'
                            : 'Te avisamos aunque tengas la app cerrada.',
                      ),
                      value: avisos.tienePermiso,
                      // El permiso se pide acá, cuando la persona lo
                      // elige. Apagarlo solo se puede desde los Ajustes.
                      onChanged: avisos.tienePermiso
                          ? null
                          : (_) => avisos.pedirPermiso(),
                    ),
                    // Las PUSH: el token es la "dirección" de este
                    // teléfono en Firebase Cloud Messaging. Se copia y
                    // se pega en la consola de Firebase (Messaging →
                    // mensaje de prueba) para mandarle una push.
                    if (avisos.tokenPush case final token?) ...[
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.cloud_outlined),
                        title: const Text('Notificaciones push'),
                        subtitle: Text(
                          'Código de este teléfono: '
                          '${token.substring(0, 12)}...',
                        ),
                        trailing: const Icon(Icons.copy),
                        onTap: () async {
                          await Clipboard.setData(ClipboardData(text: token));
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Copiado. Pegalo en la consola de Firebase, '
                                'en Messaging.',
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.inbox_outlined),
                      title: const Text('Mis avisos'),
                      trailing: sinLeer > 0
                          ? Badge(label: Text('$sinLeer'))
                          : const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              NotificacionesScreen(deps: _deps, para: _para),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          if (taller == null && !sesion.esAdmin) ...[
            _titulo('¿Tenés un taller?'),
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.store_outlined),
                title: const Text('Vendé tus repuestos en RepoCar'),
                subtitle: const Text('Entrá o registrate con tu CUIT'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        IngresoScreen(deps: _deps, rolInicial: Rol.taller),
                  ),
                ),
              ),
            ),
          ],

          _titulo('Sobre la app'),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                _dato(Icons.storage_outlined, 'Datos', _deps.almacen.nombre),
                _dato(Icons.info_outline, 'Versión', '1.0.0'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => cerrarSesion(context, _deps),
            icon: const Icon(Icons.logout, color: Colors.red),
            label: const Text(
              'Cerrar sesión',
              style: TextStyle(color: Colors.red),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              side: const BorderSide(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _titulo(String texto) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
    child: Text(
      texto.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Colors.black54,
        letterSpacing: 0.6,
      ),
    ),
  );

  Widget _dato(IconData icono, String titulo, String valor) => ListTile(
    leading: Icon(icono),
    title: Text(titulo, style: const TextStyle(fontSize: 13)),
    subtitle: Text(
      valor,
      style: const TextStyle(fontSize: 15, color: Colors.black87),
    ),
    dense: true,
  );
}
