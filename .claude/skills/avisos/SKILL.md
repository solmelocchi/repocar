---
name: avisos
description: Notificaciones de RepoCar - locales (inmediata y programada), push con Firebase Cloud Messaging y la tarea de segundo plano con WorkManager. Usala cuando haya que avisarle algo al taller o al comprador, o cambiar cuándo y cómo se avisa.
---

# Avisos en RepoCar

## Qué hay

| Forma | Archivo | Cuándo |
|---|---|---|
| Local inmediata | `notificaciones_service.dart` → `mostrar()` | Pedido nuevo (al taller); en camino o listo, y entregado (al comprador) |
| Local programada | `programar()` con `zonedSchedule`, inexacta | "¿Ya probaste el repuesto?", 24 h después de la entrega; se cancela si califica |
| Segundo plano | `plataforma/segundo_plano.dart` (WorkManager) | Cada 15 min o más, con red: pedidos nuevos con la app cerrada |
| Push (FCM) | `push_service.dart`, `push_repository.dart` | Mensajes desde la consola de Firebase, en los tres estados de la app |

Quién decide avisar: `pedidos_view_model.dart` (`_alCambiar`), cuando llega un cambio por el Stream del repositorio.

## Reglas

- **Política en un solo lugar**: `lib/domain/politica_de_avisos.dart` (cuánto esperar, cada cuánto revisar, los ids).
- **Lo que cambia de estado usa siempre el mismo id** (`PoliticaDeAvisos.idDeEstado`): el aviso nuevo reemplaza al viejo en la barra.
- **Permiso en contexto**: nunca al abrir la app. Lo pide el botón Activar (`activar_avisos.dart`) o Cuenta. Sin permiso, el aviso igual queda en la campanita.
- Siempre un **payload** para saber qué abrir al tocarla.
- El canal es "pedidos" (importancia alta). Cambiar la importancia de un canal ya creado no tiene efecto.
- Todo pasa por `NotificacionesViewModel` → `NotificacionesRepository` → servicio. Las pruebas usan `NotificacionesFalsas`.

## Push

- La app guarda el token en Firestore (`tokens/{uid}`) al entrar, de nuevo si cambia y lo borra al salir.
- Los tres estados están en `NotificacionesViewModel`: abierta (`onMessage`, la mostramos nosotros), minimizada (`onMessageOpenedApp`) y cerrada (`getInitialMessage`).
- El manejador de segundo plano es una función de nivel superior con `@pragma('vm:entry-point')`; corre en otro isolate.
- **No hay servidor que mande push solo**: eso sería Cloud Functions, que pide el plan pago. Se prueban desde la consola de Firebase (Messaging, mensaje de prueba, con el token que se copia en Cuenta).
- Solo Android: en la web se usa `SinPush`.

## Para agregar un aviso

1. Decidí si vale la pena interrumpir. Si es un estado, usá el id fijo del pedido.
2. Agregalo en el `switch` de `_alCambiar` en `pedidos_view_model.dart`.
3. Prueba en `test/` con `NotificacionesFalsas`: que aparezca en `mostradas` y que sin permiso no aparezca.
