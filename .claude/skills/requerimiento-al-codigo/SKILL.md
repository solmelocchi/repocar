---
name: requerimiento-al-codigo
description: Explicar un pedido del cliente de RepoCar (TalleresYa) de punta a punta - qué problema tenía, qué propusimos, por qué, y en qué archivos y líneas está resuelto. Usala cuando pregunten "cómo resolvieron X", "dónde está X en el código" o para preparar la defensa.
---

# De un requerimiento al código

La evaluación pregunta por los requerimientos: qué quería el cliente, qué problema había, qué propusimos y por qué, y **cómo se ve eso en el código**. Contestá siempre con esta forma, corta y en español:

1. **Lo que pidió el cliente**, con sus palabras si se puede.
2. **El problema** que había detrás (qué pasaba si no se hacía).
3. **Lo que propusimos** y **por qué** esa opción y no otra (incluí lo que quedó afuera, como Mercado Pago real o push automática, y la razón).
4. **Dónde está en el código**: el camino por las capas, con archivo y función. Por ejemplo: pantalla → ViewModel → repositorio → servicio.
5. **Cómo se muestra en la app**: qué tocar en la demo para verlo.
6. **Qué prueba lo cubre**, en `test/`.

## Cómo buscar

- La tabla de requerimientos está en `CLAUDE.md`. Empezá por ahí.
- Para ubicar el código, buscá una palabra clave, no una ruta. Por ejemplo: `aLaVenta`, `PiezaNoDisponible`, `comision`, `MetodoEntrega`, `sePuedeCalificar`, `tieneDatosDeContacto`, `esSenalDeVentaPorFuera`, `idDeEstado`.
- Seguí el camino con "buscar referencias" desde el servicio hacia arriba hasta la pantalla.

## Ejemplo

**"Hay una sola unidad de cada repuesto"**

1. Ramallo: son repuestos usados, hay uno de cada uno.
2. Si dos personas compraban la misma pieza, el taller vendía algo que no tenía.
3. El carrito no tiene cantidad. La pieza vendida, pausada o borrada no se puede comprar, y se revisa justo antes de cobrar.
4. `Pieza.aLaVenta` (dominio) → `CarritoViewModel.noDisponibles` (antes de cobrar) → `PedidosRepository` tira `PiezaNoDisponible` → `pago_screen.dart` avisa "esa pieza ya se vendió".
5. Comprar la misma pieza desde dos teléfonos.
6. `servidor_test.dart`.

No inventes: si algo no está en el código, decilo.
