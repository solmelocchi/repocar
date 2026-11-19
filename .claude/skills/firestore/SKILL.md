---
name: firestore
description: Trabajar con la base en la nube de RepoCar (Firestore) - colecciones, reglas de seguridad, el contador de pedidos y cómo publicar las reglas. Usala cuando haya que guardar o leer algo nuevo en el servidor o cambiar firestore.rules.
---

# Firestore en RepoCar

## Cómo está armado

- `lib/data/remoto/base_remota.dart`: `BaseFirestore`, lo único que habla con Firestore (leer, guardar, escuchar con `snapshots()`, transacciones).
- `lib/data/remoto/almacen_con_servidor.dart`: un **decorador** sobre la base del teléfono (SQLite). Cumple el mismo contrato, así los repositorios no saben si hay servidor.
  - Guardar: primero en el teléfono (`await`) y después al servidor **sin esperar** (`unawaited`).
  - Leer: junta las dos y gana la del servidor.
  - Si el servidor no contesta en 6 segundos, sigue con lo del teléfono.
- `lib/data/remoto/conectar_servidor.dart`: `Firebase.initializeApp`, la copia sin conexión (`persistenceEnabled: true`) y la espera de la sesión guardada.

## Colecciones

| Colección | Qué guarda | Quién escribe |
|---|---|---|
| `piezas` | El catálogo | El taller dueño; cualquiera con sesión, solo para marcarla vendida |
| `pedidos` | Los pedidos | Quien compra; el taller del pedido cambia estado y respuesta; el comprador, la calificación |
| `cuentas` | Datos de talleres y clientes (sin contraseñas) | Cada uno, la suya |
| `contadores` | El último número de pedido | Cualquiera con sesión, **solo sumando 1** |
| `tokens` | El token de push de cada teléfono | Cada uno, el suyo |

## Para agregar una colección

1. El acceso va en `BaseFirestore` o en una clase de `lib/data/remoto/` detrás de una **clase abstracta**, con una versión falsa para las pruebas.
2. Escribí la regla en `firestore.rules`, **antes** de la regla final que cierra todo. Usá las funciones que ya están: `adentro()`, `esElTaller(cuit)`, `esAdmin()`, `soloCambia([...])`.
3. Nunca `allow ... if true` para escribir. Borrar, en general, no se permite: se marca (`borrada`, `pausada`).
4. Publicá las reglas:
   ```bash
   firebase.cmd deploy --only firestore:rules --project repocar-8cad3
   ```
5. Verificá que el archivo `firestore.rules` y lo publicado sean lo mismo: el archivo es lo que se muestra en el examen.

## Cuidado

- Los números pueden volver como `int` aunque se guardaron con decimales: leer como `num` y convertir.
- Un contador que suben varios teléfonos va con **transacción** (`runTransaction`, como el número de pedido), no con leer, sumar y guardar. `FieldValue.increment` sirve si no hace falta saber el número nuevo.
- Plan gratis: no escuchar colecciones enteras sin necesidad, y nada que pida el plan Blaze (Cloud Functions, Storage).
