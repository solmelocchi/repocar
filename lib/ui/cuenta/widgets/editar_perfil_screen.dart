import 'package:flutter/material.dart';

import '../../../dependencias.dart';
import '../../core/aviso.dart';
import '../../ingreso/view_models/sesion_view_model.dart';

/// Editar mis datos. El taller cambia teléfono, zona y cadete; el
/// comprador, el teléfono.
///
/// Lo que NO se edita, a propósito: el CUIT y el mail (son con lo que
/// se entra) y el nombre del comprador (los pedidos lo guardan).
class EditarPerfilScreen extends StatefulWidget {
  final Dependencias deps;

  const EditarPerfilScreen({super.key, required this.deps});

  @override
  State<EditarPerfilScreen> createState() => _EditarPerfilScreenState();
}

class _EditarPerfilScreenState extends State<EditarPerfilScreen> {
  final _formulario = GlobalKey<FormState>();
  late final _telefono = TextEditingController(
    text: _sesion.taller?.telefono ?? _sesion.cliente?.telefono ?? '',
  );
  late final _costoCadete = TextEditingController(
    text: '${_sesion.taller?.costoCadete ?? 0}',
  );
  late String? _zona = _sesion.taller?.zona;
  late bool _tieneCadete = _sesion.taller?.tieneCadete ?? false;
  bool _guardando = false;

  SesionViewModel get _sesion => widget.deps.sesion;

  bool get _esTaller => widget.deps.sesion.hayTaller;

  @override
  void dispose() {
    _telefono.dispose();
    _costoCadete.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formulario.currentState!.validate()) return;
    setState(() => _guardando = true);

    final sesion = widget.deps.sesion;
    if (_esTaller) {
      await sesion.actualizarTaller(
        telefono: _telefono.text.trim(),
        zona: _zona!,
        tieneCadete: _tieneCadete,
        costoCadete: int.tryParse(_costoCadete.text.trim()) ?? 0,
      );
    } else {
      await sesion.actualizarCliente(telefono: _telefono.text.trim());
    }

    if (!mounted) return;
    avisar(context, 'Guardaste tus datos');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar mis datos')),
      body: Form(
        key: _formulario,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _telefono,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Teléfono',
                hintText: '+54 9 261 123-4567',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
              validator: (valor) =>
                  (valor == null ||
                      valor.replaceAll(RegExp(r'[^0-9]'), '').length < 10)
                  ? 'Poné el número completo, con característica'
                  : null,
            ),
            if (_esTaller) ...[
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _zona,
                decoration: const InputDecoration(
                  labelText: 'Zona',
                  prefixIcon: Icon(Icons.place),
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final zona in widget.deps.sesion.zonasDisponibles)
                    DropdownMenuItem(value: zona, child: Text(zona)),
                ],
                onChanged: (valor) => setState(() => _zona = valor),
                validator: (valor) => valor == null ? 'Elegí la zona' : null,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Tengo cadete propio'),
                subtitle: const Text(
                  'Si no tenés, el envío lo cotiza la empresa según la zona.',
                ),
                value: _tieneCadete,
                onChanged: (valor) => setState(() => _tieneCadete = valor),
              ),
              if (_tieneCadete)
                TextFormField(
                  controller: _costoCadete,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Cuánto cobra el cadete',
                    prefixText: '\$ ',
                    border: OutlineInputBorder(),
                  ),
                  validator: (valor) =>
                      (int.tryParse((valor ?? '').trim()) ?? -1) < 0
                      ? 'Poné un número'
                      : null,
                ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _guardando ? null : _guardar,
              icon: const Icon(Icons.save),
              label: Text(_guardando ? 'Guardando...' : 'Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
