import 'package:flutter/material.dart';

import '../../../dependencias.dart';
import '../../../domain/cuit.dart';
import '../../core/aviso.dart';
import '../../core/colores.dart';
import '../../taller/widgets/taller_screen.dart';

/// El alta de un taller nuevo. Acá es donde la app se asegura de que el
/// que va a publicar es un taller: CUIT válido y constancia de ARCA.
class RegistroTallerScreen extends StatefulWidget {
  final Dependencias deps;

  const RegistroTallerScreen({super.key, required this.deps});

  @override
  State<RegistroTallerScreen> createState() => _RegistroTallerScreenState();
}

class _RegistroTallerScreenState extends State<RegistroTallerScreen> {
  final _formulario = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _cuit = TextEditingController();
  final _telefono = TextEditingController();
  final _clave = TextEditingController();
  final _costoCadete = TextEditingController(text: '3500');

  String? _zona;
  bool _tieneCadete = false;
  bool _constancia = false;

  @override
  void dispose() {
    _nombre.dispose();
    _cuit.dispose();
    _telefono.dispose();
    _clave.dispose();
    _costoCadete.dispose();
    super.dispose();
  }

  Future<void> _registrar() async {
    final mensajero = ScaffoldMessenger.of(context);

    if (!_formulario.currentState!.validate()) return;

    if (!_constancia) {
      mensajero.clearSnackBars();
      mensajero.showSnackBar(
        const SnackBar(
          content: Text('Falta la constancia de inscripción de ARCA'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final error = await widget.deps.sesion.registrarTaller(
      nombre: _nombre.text.trim(),
      cuit: _cuit.text,
      telefono: _telefono.text.trim(),
      zona: _zona!,
      clave: _clave.text,
      tieneCadete: _tieneCadete,
      costoCadete: int.tryParse(_costoCadete.text.trim()) ?? 0,
    );

    if (!mounted) return;

    // El servidor puede decir que no (por ejemplo, si ya existe la cuenta).
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    avisar(
      context,
      '${widget.deps.sesion.taller!.nombre} quedó verificado y registrado',
    );
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => TallerScreen(deps: widget.deps)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar mi taller')),
      body: Form(
        key: _formulario,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Con estos datos verificamos que sos un taller y no un '
              'comprador. El CUIT se valida con su dígito verificador, igual '
              'que en ARCA.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nombre,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre del taller',
                hintText: 'Ej: Repuestos El Torno',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.store),
              ),
              validator: (valor) => (valor == null || valor.trim().isEmpty)
                  ? 'Poné el nombre del taller'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _cuit,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'CUIT',
                hintText: '30-71234567-1',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.badge),
              ),
              validator: (valor) {
                if (valor == null || valor.trim().isEmpty) {
                  return 'Poné el CUIT del taller';
                }
                if (!cuitValido(valor)) {
                  return 'Ese CUIT no existe: revisá el número';
                }
                if (widget.deps.sesion.buscarPorCuit(valor) != null) {
                  return 'Ya hay un taller registrado con ese CUIT';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _telefono,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Teléfono del taller',
                hintText: '+54 9 260 411-2233',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.chat),
              ),
              validator: (valor) => (valor == null || valor.trim().isEmpty)
                  ? 'Poné un teléfono de contacto'
                  : null,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _zona,
              decoration: const InputDecoration(
                labelText: 'Zona',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.place),
              ),
              items: [
                for (final zona in widget.deps.sesion.zonasDisponibles)
                  DropdownMenuItem(value: zona, child: Text(zona)),
              ],
              onChanged: (valor) => setState(() => _zona = valor),
              validator: (valor) => valor == null ? 'Elegí tu zona' : null,
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
            const SizedBox(height: 20),

            // La prueba de que es un taller.
            Card(
              color: _constancia
                  ? const Color(0xFFDDF1E6)
                  : const Color(0xFFF3F5F9),
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _constancia ? Icons.check_circle : Icons.upload_file,
                          color: _constancia ? verde : Colors.black45,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _constancia
                                ? 'constancia-arca.pdf adjuntada'
                                : 'Constancia de inscripción de ARCA',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _constancia ? verde : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Sirve la constancia o una factura del taller. En la '
                      'app real se chequea solo contra el padrón de ARCA.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () =>
                          setState(() => _constancia = !_constancia),
                      icon: Icon(
                        _constancia ? Icons.delete_outline : Icons.attach_file,
                        size: 18,
                      ),
                      label: Text(
                        _constancia ? 'Quitar' : 'Adjuntar constancia',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _tieneCadete,
              onChanged: (valor) => setState(() => _tieneCadete = valor),
              title: const Text('Tengo cadete propio'),
              subtitle: const Text(
                'Si no tenés, el envío lo cotiza la empresa por zona.',
                style: TextStyle(fontSize: 12),
              ),
            ),
            if (_tieneCadete)
              TextFormField(
                controller: _costoCadete,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Lo que cobra tu cadete',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(),
                ),
              ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _registrar,
              icon: const Icon(Icons.verified_user),
              label: const Text('Registrar taller'),
            ),
            const SizedBox(height: 10),
            const Text(
              'Al registrarte aceptás la comisión del 10% de TalleresYa '
              'sobre cada venta.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.black45),
            ),
          ],
        ),
      ),
    );
  }
}
