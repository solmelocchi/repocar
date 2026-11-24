# RepoCar

Marketplace de repuestos de auto usados para los talleres de **TalleresYa** (cliente: Ramallo). Es el proyecto integrador de Programación de Aplicaciones para Celulares (ITU UNCuyo). Está hecho en Flutter, para Android primero, y la versión web se publica en Firebase Hosting (https://repocar-8cad3.web.app).

El grupo defiende este código en un examen oral. Por eso cada decisión tiene que poder explicarse, y los comentarios dicen **por qué** se hizo así, en español.

## Lo que pidió el cliente (no romperlo)

| Requerimiento | Dónde está |
|---|---|
| TalleresYa cobra una comisión a cada taller (10%, con excepciones por taller; los primeros meses puede ser 0%) | `Taller.comision`, congelada en cada `Pedido`; panel en `ui/admin/` |
| Envíos híbridos: retiro, cadete del taller o envío por zona | `MetodoEntrega` en `domain/models/envio.dart`; checkout en `ui/carrito/` |
| Repuestos usados: hay **uno** de cada uno | Sin cantidad en el carrito; `Pieza.aLaVenta`; `PiezaNoDisponible` en `pedidos_repository.dart` |
| Califica solo quien compró y recibió; el taller responde | `Pedido.sePuedeCalificar`; `DialogoResponder` |
| Panel de administración con ventas y comisión | Cuenta `admin@talleresya.com`, `ui/admin/` |
| Consultas del comprador **adentro de la app** (Ramallo no quiere que la venta se vaya a WhatsApp) | Preguntas y respuestas en la publicación: `ui/preguntas/`, `PreguntasRepository`; no se pueden pasar teléfonos ni mails (`tieneDatosDeContacto`) |
| Que Ramallo pueda controlar que las ventas queden en la app | Sin WhatsApp ni teléfono del taller a la vista. En el panel: todas las preguntas y las publicaciones para revisar (`ui/admin/`, `domain/control_de_ventas.dart`) |
| Android primero, sin cerrarle la puerta a iPhone | Flutter: el mismo código compila para iOS |
| El taller se entera de cada pedido | Notificaciones locales, push (FCM) y WorkManager |

Quedaron **simulados** a propósito: el cobro con Mercado Pago (`PagosSimulados`) y la constancia de ARCA. Los dos necesitan un servidor propio con claves secretas.

## Arquitectura: MVVM en capas

```
lib/
  domain/                 modelos y reglas puras (sin Flutter ni plugins)
  data/services/          hablan con el exterior, siempre detrás de una clase abstracta
  data/repositories/      fuente de verdad y reglas; traducen datos crudos a modelos
  data/local/             SQLite, preferencias, almacenamiento seguro
  data/remoto/            Firebase: AlmacenConServidor decora a la base local
  plataforma/             lo del sistema: capacidades, conectividad, WorkManager
  ui/<tema>/view_models/  ChangeNotifier con EstadoCarga (cargando, exito, error)
  ui/<tema>/widgets/      pantallas; escuchan con ListenableBuilder
  dependencias.dart       arma las capas de abajo hacia arriba y las baja por constructor
  main.dart               servidor, dependencias, plataforma, sesión y recién ahí runApp
```

Reglas que siempre se cumplen:

- **Sin variables globales.** Todo se crea en `dependencias.dart` y se inyecta por constructor.
- **Un widget nunca llama a un plugin ni a Firebase.** El camino es pantalla → ViewModel → repositorio → servicio.
- **Todo plugin va detrás de una clase abstracta**, con una versión falsa en `test/fakes.dart`.
- El `notifyListeners()` del final de una carga va en un **`finally`**.
- Toda suscripción a un Stream se **cancela en `dispose`**.
- Archivos con el nombre `tema_capa.dart`: `pedidos_service.dart`, `pedidos_repository.dart`, `pedidos_view_model.dart`.
- Nombres del dominio en español (`Pieza`, `Taller`, `obtenerPiezas`); lo de Flutter, en inglés (`build`, `onPressed`). Verbos fijos: `obtener`, `buscar`, `agregar`, `quitar`, `confirmar`, `publicar`.
- Sin tildes ni ñ en los identificadores (`anio`, no `año`).

## Servidor: Firebase en el plan gratis (Spark)

- Proyecto `repocar-8cad3`: Firestore, Authentication, Hosting y Cloud Messaging.
- **Prohibido usar lo que pide el plan pago (Blaze)**: Cloud Functions y Storage. Al proyecto no se le carga ninguna tarjeta.
- Toda colección nueva de Firestore necesita su regla en `firestore.rules`. La última regla cierra todo lo demás.
- Los talleres inician sesión con el mail `<cuit>@taller.repocar.app`, y así las reglas saben qué taller es.

## Comandos

```bash
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter build apk --release
flutter build web --release
```

En Windows, la herramienta de Firebase se corre como `firebase.cmd`, porque PowerShell bloquea el `.ps1`:

```bash
firebase.cmd deploy --only hosting --project repocar-8cad3
firebase.cmd deploy --only firestore:rules --project repocar-8cad3
```

## Lo que no se toca

- `android/key.properties` y `android/app/repocar-release.jks`: son la firma del APK. No se comparten, no se suben y no se muestran.
- No agregar un servicio en primer plano ni temas que no se vieron en la materia: hay que poder defender todo lo que está.

## Skills del proyecto

Están en `.claude/skills/`. El agente las usa solo cuando la tarea coincide con su descripción, o se llaman con `/nombre`:

| Skill | Para qué |
|---|---|
| `/nueva-funcionalidad` | Agregar algo respetando las capas, con su prueba |
| `/firestore` | Una colección nueva, sus reglas y cómo publicarlas |
| `/avisos` | Notificaciones locales, programadas, push y WorkManager |
| `/antes-de-entregar` | Formato, analizador, pruebas, APK y web publicados |
| `/requerimiento-al-codigo` | Mostrar dónde y cómo está resuelto un pedido del cliente |
