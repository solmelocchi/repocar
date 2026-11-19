# RepoCar

Marketplace de repuestos de auto usados y reacondicionados para los talleres
del barrio. Prototipo del proyecto integrador (caso TalleresYa).

El comprador elige su vehículo (marca, modelo y año) y ve solo los repuestos
que le sirven; el taller publica lo que tiene y recibe los pedidos.

## Cómo correr la app

```bash
flutter pub get
flutter run
```

Está pensada para Android. Para probarla en el navegador: `flutter run -d chrome`.

## Cómo correr las pruebas

```bash
flutter test
```

## Cómo está organizado

MVVM en capas. Todo se arma en `lib/dependencias.dart` y baja por constructor (no hay variables globales).

| Carpeta / archivo | Qué hay adentro |
|---|---|
| `lib/main.dart` | Arranque: servidor, dependencias, notificaciones y WorkManager, sesión guardada y `runApp` |
| `lib/dependencias.dart` | Arma las capas de abajo hacia arriba |
| `lib/domain/` | Modelos (`Pieza`, `Taller`, `Pedido`...) y reglas puras, como el CUIT y la política de avisos |
| `lib/data/services/` | Lo que habla con el exterior, detrás de clases abstractas (notificaciones, push, pagos, API de autos) |
| `lib/data/repositories/` | La fuente de verdad y las reglas de cada tema |
| `lib/data/local/` | Base SQLite, preferencias y almacenamiento seguro |
| `lib/data/remoto/` | Firebase: Firestore (con copia sin conexión), Authentication y tokens de push |
| `lib/plataforma/` | Lo del sistema: capacidades, conectividad, WorkManager y WhatsApp |
| `lib/ui/<tema>/view_models/` | El estado de cada pantalla (`ChangeNotifier`) |
| `lib/ui/<tema>/widgets/` | Las pantallas |
| `firestore.rules` | Las reglas de seguridad de la base |
| `test/` | Pruebas con servicios falsos (`test/fakes.dart`) |
| `CLAUDE.md` y `.claude/skills/` | La configuración del agente: contexto del proyecto y skills |

El dato que hace funcionar la búsqueda es la compatibilidad: cada pieza guarda
marca, modelo y un rango de años, y el taller los **elige** de una lista fija.

## Convenciones

Acordadas por el grupo (apunte de Código limpio, secciones 2, 3 y 5).

### Idioma

- **Español para el dominio**: `Pieza`, `Taller`, `carrito`, `buscar()`.
- **Inglés para lo que viene de Flutter**: `build`, `Widget`, `notifyListeners`,
  `onPressed`.
- Sin tildes ni ñ en los nombres, porque Dart no los acepta: `anio`, no `año`.

### Cómo se escriben los nombres

| Forma | Para qué |
|---|---|
| `UpperCamelCase` | Clases, enums y typedefs: `CarritoModel`, `EstadoPieza` |
| `lowerCamelCase` | Variables, parámetros, métodos y constantes: `piezasDeEjemplo`, `precio` |
| `lowercase_with_underscores` | Archivos y carpetas: `buscar_auto.dart` |

Nada de constantes en mayúsculas sostenidas ni prefijo `k`.

### Cómo se llaman las piezas de cada pantalla

- Pantalla: `<Funcionalidad>Screen` → `ResultadosScreen`, `CarritoScreen`.
- Estado de una pantalla: `<Tema>ViewModel` → `CarritoViewModel`.
- Widget reutilizable: el nombre de lo que muestra → `EtiquetaEstado`,
  `BotonCarrito`.
- Widget que es parte de una sola pantalla: privado, con guion bajo →
  `_PiezaCard`.
- Un archivo por clase pública importante, con el mismo nombre.

### Verbos para las acciones

Una sola palabra por acción en todo el proyecto, para que nadie piense que
`traer()` y `obtener()` hacen cosas distintas:

| Acción | Verbo que usamos |
|---|---|
| Traer datos | `obtener...` |
| Buscar con filtros | `buscar...` |
| Sumar algo al carrito | `agregar...` |
| Sacar algo | `quitar...` / `vaciar()` |
| Mandar el pedido | `confirmar...` |
| Publicar una pieza | `publicar...` |

Los booleanos se leen como una pregunta: `tienePiezas`, `estaCargando`,
`puedeConfirmar`. Lo que solo devuelve un valor va como getter con sustantivo
(`total`), no como `getTotal()`.

### Antes de cada entrega

```bash
dart format .
flutter analyze
flutter test
```

El proyecto tiene que quedar formateado y pasar `flutter analyze` sin errores
ni warnings.
