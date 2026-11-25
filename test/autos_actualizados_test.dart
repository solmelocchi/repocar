import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:repocar/data/local/almacen_memoria.dart';
import 'package:repocar/data/repositories/vehiculos_repository.dart';
import 'package:repocar/data/services/catalogo_service.dart';
import 'package:repocar/data/services/vehiculos_service.dart';
import 'package:repocar/data/services/vehiculos_service_http.dart';
import 'package:repocar/domain/models/auto.dart';
import 'package:repocar/ui/busqueda/view_models/vehiculos_view_model.dart';

import 'fakes.dart';

// =====================================================================
// La lista de autos vive en internet (web/api/vehiculos.json). La app
// muestra al instante la copia guardada y, por atrás, vuelve a pedirla:
// si cambió, la reemplaza. Así se agregan autos sin sacar otro APK.
// =====================================================================

const _servicio = VehiculosService(demora: Duration(milliseconds: 1));

const _cronos = {
  'marca': 'Fiat',
  'modelo': 'Cronos',
  'desde': 2018,
  'hasta': 2024,
};
const _renegade = {
  'marca': 'Jeep',
  'modelo': 'Renegade',
  'desde': 2016,
  'hasta': 2025,
};

/// Un repositorio con la base ya cargada y una API que contesta [json].
Future<(VehiculosRepositoryConBase, AlmacenEnMemoria)> _conGuardados(
  String json, {
  int codigo = 200,
}) async {
  final almacen = AlmacenEnMemoria();
  await almacen.guardarVehiculos([_cronos]);
  final repositorio = VehiculosRepositoryConBase(
    servicio: _servicio,
    almacen: almacen,
    descarga: VehiculosServiceHttp(
      url: 'https://ejemplo.test/vehiculos.json',
      cliente: MockClient((_) async => http.Response(json, codigo)),
    ),
  );
  return (repositorio, almacen);
}

void main() {
  test('muestra al instante la lista guardada y por atrás trae la nueva', () async {
    final (repositorio, almacen) = await _conGuardados(
      jsonEncode([_cronos, _renegade]),
    );
    final llegadas = <List<ModeloVehiculo>>[];
    final escucha = repositorio.actualizaciones.listen(llegadas.add);

    // Al instante: la que estaba en el teléfono.
    final primero = await repositorio.obtenerVehiculos();
    expect(primero.single.modelo, 'Cronos');
    expect(repositorio.origen, 'base local');

    // Por atrás: llegó la nueva, se avisó y quedó guardada.
    await repositorio.revisando;
    await pumpEventQueue(); // el aviso del Stream llega en la vuelta siguiente
    expect(llegadas.single.map((a) => a.modelo), ['Cronos', 'Renegade']);
    expect(repositorio.origen, 'actualizada');
    expect((await almacen.leerVehiculos()).length, 2);
    expect((await repositorio.obtenerVehiculos()).length, 2);
    await escucha.cancel();
  });

  test('si la API contesta lo mismo, no avisa nada', () async {
    final (repositorio, _) = await _conGuardados(jsonEncode([_cronos]));
    final llegadas = <List<ModeloVehiculo>>[];
    final escucha = repositorio.actualizaciones.listen(llegadas.add);

    await repositorio.obtenerVehiculos();
    await repositorio.revisando;
    await pumpEventQueue();

    expect(llegadas, isEmpty);
    expect(repositorio.origen, 'base local');
    await escucha.cancel();
  });

  test('sin internet o con la API caída, se queda con la que tenía', () async {
    final (repositorio, almacen) = await _conGuardados('se cayó', codigo: 500);

    await repositorio.obtenerVehiculos();
    await repositorio.revisando;

    expect(repositorio.origen, 'base local');
    expect((await almacen.leerVehiculos()).single['modelo'], 'Cronos');
  });

  test('cuando llega una lista nueva, la pantalla se entera sola', () async {
    final repositorio = VehiculosFake();
    final vm = VehiculosViewModel(repositorio: repositorio);
    await vm.cargar();
    var avisos = 0;
    vm.addListener(() => avisos++);

    repositorio.nuevas.add(const [
      ModeloVehiculo('Jeep', 'Renegade', 2016, 2025),
    ]);
    await pumpEventQueue();

    expect(avisos, 1);
    expect(vm.marcas, ['Jeep']);
    vm.dispose();
  });

  test(
    'el JSON publicado es válido y tiene todos los autos de las piezas',
    () async {
      final publicado =
          (jsonDecode(File('web/api/vehiculos.json').readAsStringSync())
                  as List)
              .map(
                (a) => ModeloVehiculo.desdeJson(Map<String, dynamic>.from(a)),
              )
              .toList();
      expect(publicado.length, greaterThanOrEqualTo(80));

      // Ningún auto repetido y los años en orden.
      final claves = publicado.map((a) => '${a.marca}|${a.modelo}').toSet();
      expect(claves.length, publicado.length);
      for (final auto in publicado) {
        expect(auto.desde, lessThanOrEqualTo(auto.hasta), reason: auto.modelo);
      }

      // Las piezas de ejemplo usan autos que el taller puede elegir.
      final piezas = await CatalogoService(
        almacen: AlmacenEnMemoria(),
        demora: Duration.zero,
      ).obtenerPiezas();
      for (final pieza in piezas) {
        for (final c in pieza['compatibles'] as List) {
          expect(
            claves,
            contains('${c['marca']}|${c['modelo']}'),
            reason: pieza['titulo'] as String,
          );
        }
      }
    },
  );
}
