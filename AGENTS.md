# AGENTS.md — Guía para agentes en CHAMBA

Proyecto: app **Flutter** (`lib/`) + backend **NestJS + Prisma + PostgreSQL/PostGIS** (`backend/`). Marketplace de servicios del hogar en Chiclayo, Perú, con dos roles (cliente y chambeador/técnico), ofertas en tiempo real (Socket.IO) y pagos en garantía (escrow).

**La fuente de verdad del producto es [`ALCANCE.md`](ALCANCE.md).** Si algo de este archivo o del código contradice a `ALCANCE.md`, manda `ALCANCE.md`. Si la spec es ambigua, **pregunta; no inventes**.

## Metodología: ODD (Organic-Driven Development)
- Preguntas y revisiones son **solo lectura** hasta que se pida un cambio.
- Trabajo pequeño: se hace directo. Trabajo grande (que no puede reanudarse desde el diff): guarda la spec literal en `odd/tasks/<nombre>.md`.
- Ciclo: **autorizar y entender → implementar → verificar → cerrar**.
- **TDD por defecto** (Red → Green → Refactor) cuando hay tests ejecutables.
- **Commits:** permitidos **solo en una rama de trabajo** (hoy `feature/flujo-v2`), **un commit local por loop cerrado** (ver "Cómo ejecutar el trabajo"). **Nunca commitees en `main`, nunca hagas push, nunca reescribas historia** (`--amend`, `rebase`, `reset --hard`, `push --force`). El push y el merge a `main` los decide el humano.

## Cómo ejecutar el trabajo (loops)
Trabaja `ALCANCE.md` §8 en orden, **un loop (L0, L1, …) a la vez**. Para cada loop:
1. Lee el loop y las secciones de `ALCANCE.md` que referencia. Resume en 3–5 líneas lo que vas a hacer y los riesgos.
2. Implementa con TDD, en cambios pequeños.
3. Verifica **solo con los tests del propio loop** (`flutter test <archivo>`; en backend, el vitest del módulo tocado). **NO compiles la app, NO levantes el emulador, NO uses Mobile MCP y NO corras la suite completa al cerrar un loop**: eso se hace una única vez en **L11**.
4. **Registra en ODD** (obligatorio): por cada tarea del loop agrega una entrada a `odd/tasks/flujo-v2-registro.md` con el formato definido en `ALCANCE.md` §8 (Qué · Por qué · Para qué · Pruebas · Decisiones). Explica el *por qué* y el *para qué*, no solo el qué.
5. Marca `[x]` las tareas hechas en `ALCANCE.md` y agrega **una línea** a la Bitácora (fecha · loop · tareas cerradas · tests del loop).
6. **Commit del loop** (si estás en la rama de trabajo): confirma con `git branch --show-current` que NO estás en `main`; agrega solo los archivos del loop (nunca `.env`, secretos ni scripts temporales); mensaje `feat(L<n>): <resumen corto>` o `fix(L<n>): ...` con una línea explicando qué y por qué. Si cambiaste `backend/prisma/schema.prisma`, el commit incluye su migración en `backend/prisma/migrations/` (genérala con `prisma migrate diff`, sin borrar datos; no uses `migrate dev` si pide resetear la base). Si no hay rama de trabajo, no commitees y avisa.

### Modo continuo (autorizado por el dueño el 2026-11-09)
El humano revisará **solo al final**. Tras cerrar un loop, **continúa con el siguiente sin esperar aprobación**, hasta completar L10 y luego ejecuta **L11 (revisión general final)**: analyze, suite completa, compilación y Mobile MCP, una sola vez.
Detente y reporta (sin avanzar) únicamente si:
- los tests del loop siguen fallando tras una corrección acotada;
- la spec es ambigua en algo que afecta dinero, seguridad o privacidad;
- necesitas una dependencia nueva o cambiar un contrato de API no previsto en `ALCANCE.md`.
Las decisiones menores que tomes por tu cuenta anótalas en el campo "Decisiones" de la entrada del registro ODD para que el humano las revise al final.
**Higiene de documentos:** no crees archivos `.md` sueltos (resúmenes, changelogs, reportes por loop). Los únicos documentos vivos son `AGENTS.md`, `ALCANCE.md` y `odd/tasks/flujo-v2-registro.md`. L2 (persistencia backend) queda **aprobado**.

Si una verificación falla: una corrección acotada y vuelve a verificar. Si sigue fallando, **detente y reporta**; no escondas el fallo ni marques `[x]`.

## Reglas duras
- **Dinero:** el ledger es inmutable y la fuente de verdad. Todo movimiento es un asiento. Invariante: `custodia = liberación + comisión + tarifa`; el saldo nunca es negativo. Todo cambio de lógica monetaria lleva test.
- **Prohibido** un botón o llamada de recarga directa que consuma `POST /finance/deposit` (vulnerabilidad conocida del backend).
- **Pagos 100 % simulados.** No integres pasarelas reales ni manejes credenciales de pago.
- **Honestidad de UI:** con `USE_MOCKS=false`, un fallo de red/API muestra error con reintento; **nunca cae a mocks en silencio**. Datos demo con etiqueta "DEMO". No mostrar verificaciones, DNI, tarifas o métricas inventadas como reales. Si la IA no responde y se usa el motor de respaldo, rotular "Sugerencia automática (sin IA)".
- **Privacidad:** no mostrar el correo de los técnicos; la dirección exacta del cliente solo se revela al chambeador tras el depósito.
- **Seguridad:** no commitear `.env` ni secretos; no loguear tokens; validar entradas en el backend.
- **Nada de botones muertos** (`onTap: () {}`): o hacen algo real o no se muestran.
- La IA **recomienda, no decide** en disputas: nunca ejecuta movimientos de dinero por sí sola.
- No agregues dependencias ni cambies contratos de API sin dejarlo anotado en la spec del loop.

## Convenciones del código
- Estado de la app: `lib/presentation/state/app_state.dart` (un `ChangeNotifier`). No navegues dentro de listeners que puedan dispararse varias veces; usa un gate central.
- Pantallas en `lib/presentation/screens/`, widgets reutilizables en `lib/core/widgets/`, tema en `lib/core/theme/`.
- Servicios HTTP/WS en `lib/data/services/` (todo por `ApiClient`).
- Textos de UI en **español (Perú)**, moneda `S/` con formato `S/ 100`.
- Pruebas en `test/` (Flutter) y `backend/test` / `*.spec.ts` (backend). Todo código nuevo con tests.
- Fuera de alcance salvo pedido explícito: ver `ALCANCE.md` §9.

## Comandos útiles
```bash
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000 --dart-define=USE_MOCKS=false
cd backend && npm install && npm run start:dev
```
Consulta `HOW_TO_RUN.md` para la puesta en marcha completa (Docker/Postgres, variables de entorno).
