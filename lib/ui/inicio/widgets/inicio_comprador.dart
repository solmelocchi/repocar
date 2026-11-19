import 'package:flutter/material.dart';

import '../../../dependencias.dart';
import '../../carrito/widgets/carrito_screen.dart';
import '../../catalogo/widgets/home_screen.dart';
import '../../cuenta/widgets/cuenta_screen.dart';
import '../../pedidos/widgets/mis_pedidos_screen.dart';

/// La app del comprador, con la barra de abajo como cualquier app:
/// Inicio, Carrito, Pedidos y Cuenta.
///
/// IndexedStack mantiene viva cada pestaña: si escribiste en el buscador
/// y vas al carrito, al volver lo escrito sigue ahí.
class InicioComprador extends StatelessWidget {
  final Dependencias deps;

  const InicioComprador({super.key, required this.deps});

  @override
  Widget build(BuildContext context) {
    // La pestaña elegida vive en las dependencias para que otra pantalla
    // (la de "pedido confirmado") pueda mandar al usuario a una.
    return ValueListenableBuilder<int>(
      valueListenable: deps.pestanaComprador,
      builder: (context, pestana, _) => Scaffold(
        body: IndexedStack(
          index: pestana,
          children: [
            HomeScreen(deps: deps),
            CarritoScreen(deps: deps),
            MisPedidosScreen(deps: deps),
            CuentaScreen(deps: deps),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: pestana,
          onDestinationSelected: (i) => deps.pestanaComprador.value = i,
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Inicio',
            ),
            NavigationDestination(
              // El numerito del carrito escucha al view model del carrito.
              icon: ListenableBuilder(
                listenable: deps.carrito,
                builder: (context, _) => Badge(
                  label: Text('${deps.carrito.cantidad}'),
                  isLabelVisible: deps.carrito.cantidad > 0,
                  child: const Icon(Icons.shopping_cart_outlined),
                ),
              ),
              selectedIcon: const Icon(Icons.shopping_cart),
              label: 'Carrito',
            ),
            const NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Pedidos',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Cuenta',
            ),
          ],
        ),
      ),
    );
  }
}
