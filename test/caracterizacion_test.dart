// =====================================================================
// TESTS DE CARACTERIZACIÓN
//
// No prueban lo que la app "debería" hacer: dejan clavado lo que HACE,
// y se escribieron ANTES de mover el código a capas. Que sigan en verde
// después del refactor es la prueba de que el comportamiento no cambió.
//
// Lo único que hubo que tocar fueron los imports, porque los modelos
// cambiaron de archivo. Las reglas no se tocaron.
// =====================================================================
import 'package:flutter_test/flutter_test.dart';

import 'package:repocar/data/politicas_remotas.dart';
import 'package:repocar/data/services/configuracion_service.dart';
import 'package:repocar/domain/cuit.dart';
import 'package:repocar/domain/models/auto.dart';
import 'package:repocar/domain/models/envio.dart';
import 'package:repocar/domain/models/pedido.dart';
import 'package:repocar/domain/models/pieza.dart';
import 'package:repocar/domain/models/taller.dart';
import 'package:repocar/ui/carrito/view_models/carrito_view_model.dart';
import 'package:repocar/ui/core/formato.dart';

import 'fakes.dart';

final tallerDePrueba = Taller(
  nombre: 'Taller de prueba',
  telefono: '+54 9 260 000-0000',
  cuit: '30-71234567-1',
  zona: 'San Rafael',
);

/// Una pieza armada a mano, para no depender del catálogo de ejemplo.
Pieza piezaDePrueba({
  String id = 'test1',
  int precio = 100000,
  List<Compatibilidad> compatibles = const [
    Compatibilidad('Volkswagen', 'Gol Trend', 2008, 2016),
  ],
}) {
  return Pieza(
    id: id,
    titulo: 'Pieza de prueba',
    descripcion: 'Para los tests',
    precio: precio,
    estado: EstadoPieza.usado,
    taller: tallerDePrueba,
    icono: 'build',
    compatibles: compatibles,
  );
}

void main() {
  group('Compatibilidad por rango de años', () {
    final pieza = piezaDePrueba();

    test('sirve para un año dentro del rango', () {
      const auto = Auto(marca: 'Volkswagen', modelo: 'Gol Trend', anio: 2014);
      expect(pieza.sirvePara(auto), isTrue);
    });

    test('sirve en los bordes del rango', () {
      expect(
        pieza.sirvePara(
          const Auto(marca: 'Volkswagen', modelo: 'Gol Trend', anio: 2008),
        ),
        isTrue,
      );
      expect(
        pieza.sirvePara(
          const Auto(marca: 'Volkswagen', modelo: 'Gol Trend', anio: 2016),
        ),
        isTrue,
      );
    });

    test('no sirve fuera del rango ni para otro modelo', () {
      expect(
        pieza.sirvePara(
          const Auto(marca: 'Volkswagen', modelo: 'Gol Trend', anio: 2017),
        ),
        isFalse,
      );
      expect(
        pieza.sirvePara(
          const Auto(marca: 'Ford', modelo: 'Ranger', anio: 2014),
        ),
        isFalse,
      );
    });
  });

  group('La plata de un pedido', () {
    Pedido pedidoDePrueba({double comisionPct = 0.10, int envio = 0}) {
      return Pedido(
        numero: '#9001',
        fecha: DateTime(2026, 11, 10),
        cliente: 'Cliente de prueba',
        taller: tallerDePrueba,
        items: [ItemCarrito(piezaDePrueba(precio: 200000))],
        entrega: MetodoEntrega.retiro,
        costoEnvio: envio,
        comisionPct: comisionPct,
      );
    }

    test('la comisión sale del subtotal, no del total con envío', () {
      final pedido = pedidoDePrueba(envio: 5000);
      expect(pedido.subtotal, 200000);
      expect(pedido.total, 205000);
      expect(pedido.comision, 20000); // el 10% de 200000, no de 205000
    });

    test('al taller le queda el subtotal menos la comisión', () {
      expect(pedidoDePrueba(envio: 5000).neto, 180000);
    });

    test('cada taller puede tener su propia comisión', () {
      expect(pedidoDePrueba(comisionPct: 0.08).comision, 16000);
    });

    test('la cantidad multiplica el subtotal', () {
      final item = ItemCarrito(piezaDePrueba(precio: 50000), cantidad: 3);
      expect(item.subtotal, 150000);
    });
  });

  group('Formato de precios', () {
    test('pone el punto de miles', () {
      expect(pesos(85000), '\$ 85.000');
      expect(pesos(1250000), '\$ 1.250.000');
      expect(pesos(500), '\$ 500');
    });
  });

  group('CUIT, como lo valida ARCA', () {
    test('acepta los CUIT de los talleres de ejemplo', () {
      expect(cuitValido('30-71234567-1'), isTrue);
      expect(cuitValido('20-12345678-6'), isTrue);
      expect(cuitValido('27-23456789-1'), isTrue);
    });

    test('rechaza un dígito verificador equivocado', () {
      expect(cuitValido('30-71234567-9'), isFalse);
    });

    test('rechaza un prefijo que no existe', () {
      expect(cuitValido('99-71234567-1'), isFalse);
    });

    test('rechaza lo que no tiene once dígitos', () {
      expect(cuitValido('3071234567'), isFalse);
      expect(cuitValido('hola'), isFalse);
    });
  });

  // El carrito pasó de ser una variable global a un view model que
  // recibe sus dependencias por constructor. Con un repositorio falso,
  // los mismos dos casos de antes siguen dando lo mismo.
  group('Carrito', () {
    CarritoViewModel carritoNuevo() => CarritoViewModel(
      vehiculos: VehiculosFake(),
      politicas: PoliticasRemotas(const ConfiguracionService()),
    );

    // CORRECCIÓN (no refactoring): antes, agregar dos veces sumaba
    // cantidad. Son repuestos usados y hay uno solo de cada uno.
    test('agregar la misma pieza dos veces no la duplica: hay una sola', () {
      final carrito = carritoNuevo();
      final pieza = piezaDePrueba();

      expect(carrito.agregar(pieza), isTrue);
      expect(carrito.agregar(pieza), isFalse);

      expect(carrito.items.length, 1);
      expect(carrito.cantidad, 1);
      expect(carrito.total, 100000);
    });

    test('quitar saca la pieza del carrito', () {
      final carrito = carritoNuevo();
      carrito.agregar(piezaDePrueba());
      carrito.quitar(carrito.items.first);

      expect(carrito.items, isEmpty);
      expect(carrito.total, 0);
    });

    test('una pieza vendida no se puede agregar, y si se vende estando en '
        'el carrito, aparece como no disponible', () {
      final carrito = carritoNuevo();
      final vendida = piezaDePrueba()..vendida = true;
      expect(carrito.agregar(vendida), isFalse);

      final pieza = piezaDePrueba();
      carrito.agregar(pieza);
      pieza.vendida = true; // otro comprador se la llevó
      expect(carrito.noDisponibles, [pieza]);
    });
  });
}
