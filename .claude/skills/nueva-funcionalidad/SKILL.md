---
name: nueva-funcionalidad
description: Cómo agregar una funcionalidad a RepoCar respetando MVVM en capas (servicio abstracto, repositorio, ViewModel, pantalla, dependencias.dart y prueba). Usala cuando pidan una pantalla, un dato, un botón o una acción nueva.
---

# Agregar una funcionalidad a RepoCar

Antes de escribir código, decí en una línea **qué pidió el cliente** con esto y en qué capa va cada parte. Si no se puede explicar en el examen, no va.

## El orden (de abajo hacia arriba, como se arma la app)

1. **Dominio** (`lib/domain/`). Si hay un dato nuevo, el modelo y sus reglas puras, sin Flutter. Ejemplo: `Pedido.sePuedeCalificar`.
2. **Servicio** (`lib/data/services/<tema>_service.dart`). Solo si hay que hablar con algo de afuera (plugin, red, Firebase). Siempre:
   - una **clase abstracta** con lo que se necesita;
   - la implementación real;
   - una versión **falsa** en `test/fakes.dart`.
3. **Repositorio** (`lib/data/repositories/<tema>_repository.dart`). Las **reglas** y la fuente de verdad. Traduce lo crudo a modelos. Si algo falla por la red, se maneja acá (con `timeout` y un valor por defecto), no en la pantalla.
4. **ViewModel** (`lib/ui/<tema>/view_models/<tema>_view_model.dart`). `ChangeNotifier` con `EstadoCarga`. Patrón de carga:
   ```dart
   _estado = EstadoCarga.cargando;
   notifyListeners();
   try {
     _datos = await _repositorio.obtener...();
     _estado = EstadoCarga.exito;
   } catch (_) {
     _estado = EstadoCarga.error;
   } finally {
     notifyListeners(); // siempre: la pantalla se entera aunque falle
   }
   ```
   Si escucha un Stream, guarda la suscripción y la cancela en `dispose`.
5. **Pantalla** (`lib/ui/<tema>/widgets/`). Escucha con `ListenableBuilder` y muestra los tres estados: cargando, éxito y error con **Reintentar**. Nunca llama a un plugin ni a Firebase.
6. **Dependencias** (`lib/dependencias.dart`). Se crea en el paso que le corresponde (servicios, repositorios, ViewModels) y se pasa por constructor. Nada de variables globales.
7. **Prueba** (`test/`). Por lo menos una, con los falsos. Probá la regla, no el plugin.

## Antes de terminar

- Corré la skill `/antes-de-entregar`.
- Si se agregó una colección de Firestore, seguí `/firestore`.
- Contale al grupo en dos o tres frases **qué cambió y en qué archivos**, para que lo puedan defender.
