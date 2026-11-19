import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:repocar/data/local/almacen_memoria.dart';
import 'package:repocar/data/repositories/vehiculos_repository.dart';
import 'package:repocar/data/services/vehiculos_service.dart';
import 'package:repocar/data/services/vehiculos_service_http.dart';

// =====================================================================
// El repositorio de autos tiene tres fuentes en orden: la base local,
// la API y la lista que viene con la app. Estos tests prueban las tres
// sin red y sin teléfono, gracias a que todo entra por constructor.
// =====================================================================

const _servicio = VehiculosService(demora: Duration(milliseconds: 1));

VehiculosRepositoryConBase repositorioCon({
  required AlmacenEnMemoria almacen,
  VehiculosServiceHttp descarga = const VehiculosServiceHttp(),
}) => VehiculosRepositoryConBase(
  servicio: _servicio,
  descarga: descarga,
  almacen: almacen,
);

void main() {
  test('la primera vez, sin API, usa la lista de la app y la guarda', () async {
    final almacen = AlmacenEnMemoria();
    final repositorio = repositorioCon(almacen: almacen);

    final vehiculos = await repositorio.obtenerVehiculos();

    expect(vehiculos, isNotEmpty);
    expect(repositorio.origen, 'lista de la app');
    // Lo importante: quedó guardado para la próxima vez.
    expect((await almacen.leerVehiculos()).length, vehiculos.length);
  });

  test('la segunda vez sale de la base local', () async {
    final almacen = AlmacenEnMemoria();
    await almacen.guardarVehiculos([
      {'marca': 'Fiat', 'modelo': 'Cronos', 'desde': 2018, 'hasta': 2024},
    ]);
    final repositorio = repositorioCon(almacen: almacen);

    final vehiculos = await repositorio.obtenerVehiculos();

    expect(vehiculos.length, 1);
    expect(vehiculos.first.modelo, 'Cronos');
    expect(repositorio.origen, 'base local');
  });

  test('si la API contesta, se usa lo que bajó y queda en la base', () async {
    final almacen = AlmacenEnMemoria();
    final cliente = MockClient(
      (peticion) async => http.Response(
        '[{"marca":"Jeep","modelo":"Renegade","desde":2017,"hasta":2024}]',
        200,
      ),
    );
    final repositorio = repositorioCon(
      almacen: almacen,
      descarga: VehiculosServiceHttp(
        url: 'https://ejemplo.test/vehiculos',
        cliente: cliente,
      ),
    );

    final vehiculos = await repositorio.obtenerVehiculos();

    expect(repositorio.origen, 'descarga');
    expect(vehiculos.single.modelo, 'Renegade');
    expect((await almacen.leerVehiculos()).single['marca'], 'Jeep');
  });

  test('si la API falla, la app igual abre con su lista', () async {
    final almacen = AlmacenEnMemoria();
    final cliente = MockClient(
      (peticion) async => http.Response('se cayó', 500),
    );
    final repositorio = repositorioCon(
      almacen: almacen,
      descarga: VehiculosServiceHttp(
        url: 'https://ejemplo.test/vehiculos',
        cliente: cliente,
      ),
    );

    final vehiculos = await repositorio.obtenerVehiculos();

    expect(repositorio.origen, 'lista de la app');
    expect(vehiculos, isNotEmpty);
  });

  test('la base guarda una pieza con su compatibilidad', () async {
    final almacen = AlmacenEnMemoria();

    await almacen.guardarPieza({
      'id': 'p99',
      'titulo': 'Bobina de encendido',
      'compatibles': [
        {'marca': 'Fiat', 'modelo': 'Cronos', 'desde': 2018, 'hasta': 2024},
      ],
    });

    final guardadas = await almacen.leerPiezas();
    expect(guardadas.single['titulo'], 'Bobina de encendido');
    expect((guardadas.single['compatibles'] as List).length, 1);
  });
}
