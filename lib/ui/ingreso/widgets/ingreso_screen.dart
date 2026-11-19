import 'package:flutter/material.dart';

import '../../../dependencias.dart';
import '../../inicio/widgets/pantalla_principal.dart';
import '../../core/colores.dart';
import 'registro_cliente_screen.dart';
import 'registro_taller_screen.dart';

/// Las dos puertas de la app.
enum Rol { cliente, taller }

/// La primera pantalla: primero decís qué sos y después entrás.
/// El comprador va al catálogo; el taller, a sus publicaciones.
class IngresoScreen extends StatefulWidget {
  final Dependencias deps;
  final Rol rolInicial;

  const IngresoScreen({
    super.key,
    required this.deps,
    this.rolInicial = Rol.cliente,
  });

  @override
  State<IngresoScreen> createState() => _IngresoScreenState();
}

class _IngresoScreenState extends State<IngresoScreen> {
  late Rol _rol = widget.rolInicial;
  final _usuario = TextEditingController();
  final _clave = TextEditingController();
  String? _error;
  bool _entrando = false;

  bool get _esTaller => _rol == Rol.taller;

  @override
  void dispose() {
    _usuario.dispose();
    _clave.dispose();
    super.dispose();
  }

  void _cambiarRol(Rol rol) {
    setState(() {
      _rol = rol;
      _error = null;
      _usuario.clear();
      _clave.clear();
    });
  }

  /// Entrar es asíncrono: las cuentas las trae la capa de datos, así que
  /// mientras tanto el botón muestra que está trabajando.
  Future<void> _ingresar() async {
    setState(() {
      _entrando = true;
      _error = null;
    });

    final error = _esTaller
        ? await widget.deps.sesion.ingresarTaller(_usuario.text, _clave.text)
        : await widget.deps.sesion.ingresarCliente(_usuario.text, _clave.text);

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _entrando = false;
        _error = error;
      });
      return;
    }

    Navigator.pushReplacement(
      context,
      // El taller a su panel, TalleresYa al de administración, el
      // comprador al catálogo.
      MaterialPageRoute(builder: (_) => pantallaPrincipal(widget.deps)),
    );
  }

  void _registrarse() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _esTaller
            ? RegistroTallerScreen(deps: widget.deps)
            : RegistroClienteScreen(deps: widget.deps),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 30),
            const Icon(Icons.car_repair, size: 64, color: naranja),
            const SizedBox(height: 10),
            const Text(
              'RepoCar',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.bold,
                color: azul,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Repuestos usados y reacondicionados\nde los talleres de tu zona',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 28),

            // Primero: ¿qué sos?
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFE7EBF3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _opcion(Rol.cliente, Icons.person, 'Soy cliente'),
                  ),
                  Expanded(
                    child: _opcion(Rol.taller, Icons.store, 'Soy un taller'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Iniciar sesión',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _usuario,
                      keyboardType: _esTaller
                          ? TextInputType.number
                          : TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: _esTaller ? 'CUIT' : 'Usuario',
                        hintText: _esTaller
                            ? '30-71234567-1'
                            : 'tumail@mail.com',
                        border: const OutlineInputBorder(),
                        prefixIcon: Icon(
                          _esTaller ? Icons.badge : Icons.alternate_email,
                        ),
                      ),
                      onChanged: (_) {
                        if (_error != null) setState(() => _error = null);
                      },
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _clave,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      onSubmitted: (_) => _ingresar(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFB3261E),
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: _entrando ? null : _ingresar,
                      child: Text(_entrando ? 'Entrando...' : 'Ingresar'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '¿No tenés cuenta?',
                  style: TextStyle(color: Colors.black54),
                ),
                TextButton(
                  onPressed: _registrarse,
                  child: Text(
                    _esTaller ? 'Registrá tu taller' : 'Registrate',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _ayuda(),
          ],
        ),
      ),
    );
  }

  Widget _opcion(Rol rol, IconData icono, String texto) {
    final activo = _rol == rol;
    return InkWell(
      onTap: () => _cambiarRol(rol),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: activo ? azul : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icono,
              size: 18,
              color: activo ? Colors.white : Colors.black54,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                texto,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: activo ? Colors.white : Colors.black54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Los datos de prueba, para no tener que acordarse nada en la demo.
  Widget _ayuda() => Card(
    color: azulClaro,
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_outline, size: 18, color: Colors.black45),
              SizedBox(width: 8),
              Text(
                'Para probar',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _esTaller
                ? '30-71234567-1   (TalleresYa Ramallo)\n'
                      '27-23456789-1   (Auto Partes Nahuel)\n'
                      '33-69876543-2   (Turbo Diesel Sur)\n'
                      'Todos entran con la clave 123456.'
                : 'sol@gmail.com · 123456\n'
                      'TalleresYa (panel): admin@talleresya.com · 123456',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    ),
  );
}
