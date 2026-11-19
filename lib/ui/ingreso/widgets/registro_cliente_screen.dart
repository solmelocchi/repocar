import 'package:flutter/material.dart';

import '../../../dependencias.dart';
import '../../inicio/widgets/inicio_comprador.dart';
import '../../core/aviso.dart';

/// El alta de un comprador. Pide poco a propósito: comprar lo puede
/// hacer cualquiera, el que tiene que demostrar quién es es el taller.
class RegistroClienteScreen extends StatefulWidget {
  final Dependencias deps;

  const RegistroClienteScreen({super.key, required this.deps});

  @override
  State<RegistroClienteScreen> createState() => _RegistroClienteScreenState();
}

class _RegistroClienteScreenState extends State<RegistroClienteScreen> {
  final _formulario = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _usuario = TextEditingController();
  final _telefono = TextEditingController();
  final _clave = TextEditingController();

  @override
  void dispose() {
    _nombre.dispose();
    _usuario.dispose();
    _telefono.dispose();
    _clave.dispose();
    super.dispose();
  }

  Future<void> _registrar() async {
    if (!_formulario.currentState!.validate()) return;

    final error = await widget.deps.sesion.registrarCliente(
      nombre: _nombre.text.trim(),
      usuario: _usuario.text.trim(),
      telefono: _telefono.text.trim(),
      clave: _clave.text,
    );

    if (!mounted) return;

    // El servidor puede decir que no (por ejemplo, si ya existe la cuenta).
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    avisar(context, 'Bienvenida, ${widget.deps.sesion.cliente!.nombre}');
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => InicioComprador(deps: widget.deps)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear mi cuenta')),
      body: Form(
        key: _formulario,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Con una cuenta seguís tus pedidos y podés calificar al taller '
              'cuando te llega el repuesto.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nombre,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre y apellido',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (valor) => (valor == null || valor.trim().isEmpty)
                  ? 'Poné tu nombre'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _usuario,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Usuario (tu mail)',
                hintText: 'tumail@mail.com',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.alternate_email),
              ),
              validator: (valor) {
                final texto = (valor ?? '').trim();
                if (texto.isEmpty) return 'Poné tu mail';
                if (!texto.contains('@') || !texto.contains('.')) {
                  return 'Ese mail no parece válido';
                }
                if (widget.deps.sesion.usuarioOcupado(texto)) {
                  return 'Ya hay una cuenta con ese mail';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _telefono,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'WhatsApp',
                hintText: '+54 9 260 400-1122',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.chat),
              ),
              validator: (valor) => (valor == null || valor.trim().isEmpty)
                  ? 'Poné un teléfono para que te escriba el taller'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _clave,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Contraseña',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline),
              ),
              validator: (valor) => (valor == null || valor.length < 6)
                  ? 'Poné al menos 6 caracteres'
                  : null,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _registrar,
              icon: const Icon(Icons.person_add),
              label: const Text('Crear cuenta'),
            ),
          ],
        ),
      ),
    );
  }
}
