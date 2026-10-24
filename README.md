<p align="center">
  <img src="assets/images/chamba.png" alt="CHAMBA Logo" width="120" style="border-radius: 20px; box-shadow: 0 4px 12px rgba(0,0,0,0.1);" />
</p>

<h1 align="center">CHAMBA Perú 🇵🇪</h1>

<p align="center">
  <strong>Plataforma móvil bajo demanda para servicios técnicos y oficios en el hogar con modelo de negociación en tiempo real (estilo inDrive) y arquitectura Full Stack.</strong>
</p>

<p align="center">
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Frontend-Flutter%20%7C%20Dart-02569B?logo=flutter&logoColor=white" alt="Flutter"></a>
  <a href="https://nestjs.com"><img src="https://img.shields.io/badge/Backend-NestJS%2012%20%7C%20TypeScript-E0234E?logo=nestjs&logoColor=white" alt="NestJS"></a>
  <a href="https://www.postgresql.org"><img src="https://img.shields.io/badge/Database-PostgreSQL%20%2B%20PostGIS-336791?logo=postgresql&logoColor=white" alt="PostgreSQL"></a>
  <a href="https://redis.io"><img src="https://img.shields.io/badge/Cache%20%26%20Real--Time-Redis%20Pub%2FSub-DC382D?logo=redis&logoColor=white" alt="Redis"></a>
  <a href="https://aistudio.google.com"><img src="https://img.shields.io/badge/AI-Gemini%202.5%20Flash-8E75C2?logo=google&logoColor=white" alt="Gemini AI"></a>
  <a href="https://www.cloudflare.com/products/r2/"><img src="https://img.shields.io/badge/Storage-Cloudflare%20R2%20(S3)-F38020?logo=cloudflare&logoColor=white" alt="Cloudflare R2"></a>
  <img src="https://img.shields.io/badge/Flutter%20Tests-37%20Passed-237553?logo=checkmarx&logoColor=white" alt="Flutter Tests">
  <img src="https://img.shields.io/badge/Backend%20Tests-57%20Passed-237553?logo=vitest&logoColor=white" alt="Backend Tests">
  <img src="https://img.shields.io/badge/License-MIT-B84A1C" alt="License">
</p>

---

## 📌 Tabla de Contenidos

1. [Visión del Producto y Problema que Resuelve](#-visión-del-producto-y-problema-que-resuelve)
2. [Funcionalidades Core](#-funcionalidades-core)
3. [El Modelo de Negociación Justa (Estilo inDrive)](#-el-modelo-de-negociación-justa-estilo-indrive)
4. [Estado Real del Desarrollo por Módulos](#-estado-real-del-desarrollo-por-módulos)
5. [Experiencia y Funcionalidades por Rol](#-experiencia-y-funcionalidades-por-rol)
6. [Arquitectura y Estructura del Repositorio](#-arquitectura-y-estructura-del-repositorio)
7. [Tecnologías Utilizadas](#-tecnologías-utilizadas)
8. [Diseño Visual y Optimización Responsive](#-diseño-visual-y-optimización-responsive)
9. [Inicio Rápido](#-inicio-rápido)
10. [Pruebas Automatizadas y Calidad](#-pruebas-automatizadas-y-calidad)
11. [Guías de Colaboración y Ejecución](#-guías-de-colaboración-y-ejecución)
12. [Licencia](#-licencia)

---

## 🎯 Visión del Producto y Problema que Resuelve

En el mercado peruano (iniciando con validación en Chiclayo y Lambayeque), contratar un servicio técnico para el hogar (gasfitería, electricidad, cerrajería, pintura, albañilería) históricamente ha sufrido de:
- **Precios arbitrarios e inflados** sin un estándar orientativo claro.
- **Desconfianza y temores de seguridad** al dejar entrar a un técnico desconocido a casa.
- **Canales informales y dispersos** (avisos en postes, grupos de Facebook o recomendaciones sin trazabilidad).
- **Márgenes abusivos de intermediación** de empresas tradicionales.

**CHAMBA** democratiza el acceso a servicios de confianza conectando directamente a **Clientes** con **Maestros de Oficio y Especialistas**, mediante un **mecanismo de contraoferta bidireccional transparente**, donde el cliente propone su presupuesto inicial en Soles y los trabajadores postulan con ofertas o contraofertas justificadas.

---

## 🛡️ Funcionalidades Core

CHAMBA se fundamenta en tres pilares esenciales que transforman la experiencia de contratación técnica:

### 1. 💳 Pagos Escrow y Libro Mayor Inmutable (Custodia Segura)
- **Transacciones ACID:** Los fondos del cliente quedan retenidos en custodia (`HOLD_ESCROW`) en el instante en que acepta una propuesta, asegurando al técnico que el dinero está garantizado antes de desplazarse.
- **Libro Mayor Inmutable (Ledger Accounting):** El saldo de las billeteras nunca se sobrescribe en columnas mutables; se calcula sumando estrictamente los asientos contables históricos auditables.
- **Prevención de Doble Gasto:** Bloqueos a nivel de fila (`SELECT ... FOR UPDATE`) y nivel de aislamiento `SERIALIZABLE` en PostgreSQL para mitigar condiciones de carrera ante cobros concurrentes.
- **Liberación Controlada:** Los fondos solo se acreditan a la billetera del técnico (`RELEASE_ESCROW`) cuando el cliente confirma su conformidad en la fase de entrega del servicio.

### 2. 🚨 Chamba SOS (Urgencias Menores a 30 Minutos)
- **Despacho Inmediato de Emergencia:** Filtro prioritario para incidentes críticos del hogar que no pueden esperar (inundaciones por rotura de tubos, fugas de gas, cortocircuitos o puertas trabadas de noche).
- **Tarifa Dinámica Transparente:** Algoritmo que compensa el desplazamiento veloz del técnico con recargo justo y visible de mutuo acuerdo.
- **Temporizador Visual Activo:** Monitor interactivo con cuenta regresiva para seguimiento del arribo del especialista.

### 3. 🔰 Escudo de Confianza (Seguridad y Verificación Integral)
- **Validación de Identidad:** Sistema preparado para cotejo de identidad oficial (DNI) y verificación de antecedentes policiales/penales con la PNP.
- **Badges de Reputación y Reseñas Reales:** Sellos de *Técnico Verificado*, *Especialista Pro* y calificaciones mutuas obligatorias tras culminar cada servicio.
- **Historial de Portafolio Antes/Después:** Galería interactiva con slider táctil donde el trabajador expone evidencias fotográficas reales de sus trabajos concluidos.

---

## ⚡ El Modelo de Negociación Justa (Estilo inDrive)

A diferencia de modelos de tarifa rígida o presupuestos ciegos, el ciclo de vida en CHAMBA se estructura de la siguiente manera:

```
[1. Publicación de Necesidad] ──> Cliente describe avería + foto (R2) + IA Diagnóstico + presupuesto sugerido (S/)
            │
            ▼
[2. Postulación en Tiempo Real] ──> Técnicos cercanos (PostGIS) reciben alerta en WebSocket y envían propuesta
            │
            ▼
[3. Negociación Abierta] ──> Cliente compara ofertas por distancia, precio y reputación (Acepta o Negocia)
            │
            ▼
[4. Custodia Escrow FinTech] ──> Retención transaccional segura del pago en el Libro Mayor
            │
            ▼
[5. Rastreo del Servicio] ──> Estados visuales sincronizados vía Redis/Socket.IO (En camino ➔ Llegó ➔ Completado)
            │
            ▼
[6. Cierre, Liberación y Calificación] ──> Conformidad del cliente, liberación de fondos y reseña mutua
```

---

## 📊 Estado Real del Desarrollo por Módulos

Para máxima claridad técnica del equipo docente y colaboradores, se desglosa el nivel de implementación integral:

| Módulo / Capacidad | Estado de Implementación | Nivel de Persistencia / Backend |
| :--- | :--- | :--- |
| **Autenticación (Registro/Login)** | ✅ **Completo y Conectado** | API REST NestJS + PostgreSQL + JWT + Hash bcrypt + Almacenamiento seguro en Flutter (`flutter_secure_storage`). |
| **Búsqueda Geoespacial de Técnicos** | ✅ **Completo y Conectado** | Extensión nativa **PostGIS** en PostgreSQL (`ST_DWithin`, `ST_DistanceSphere`) con índice espacial GIST para filtrado en milisegundos. |
| **Sincronización en Tiempo Real** | ✅ **Completo y Conectado** | **Socket.IO + Redis Adapter (Pub/Sub)** con soporte multiclúster, sesiones efímeras (`user:online`) y salas dinámicas (`job:{id}`). |
| **Pagos Escrow y Libro Mayor** | ✅ **Completo y Conectado** | Transacciones ACID `SERIALIZABLE`, bloqueos de fila `FOR UPDATE`, ledger inmutable y webhooks con verificación HMAC-SHA256. |
| **Diagnóstico Visual con IA** | ✅ **Completo y Conectado** | Integración multimodal con **Google Gemini 2.5 Flash** (Structured Outputs JSON) y motor de respaldo de alta disponibilidad. |
| **Almacenamiento Multimedia R2** | ✅ **Completo y Conectado** | **Presigned URLs** con AWS SDK v3 hacia **Cloudflare R2** para subida directa de fotos de averías y notas de voz. |
| **Sesiones y Roles** | ✅ **Completo y Conectado** | Usuario único con alternancia dinámica entre **Modo Cliente** y **Modo Trabajador**, persistencia de sesión local y token Bearer. |
| **Publicación y Cotizaciones inDrive** | ✅ **Completo y Conectado** | Publicación con mapa, selector interactivo de averías asistido por IA y semáforo de precios justos (`PriceDialStepper`). |
| **Rastreo de Servicios y Chat** | ✅ **Completo y Conectado** | Telemetría de progreso, mensajería y actualización de estados sincronizada en tiempo real. |
| **Mi Billetera e Historial Financiero** | ✅ **Completo y Conectado** | Pantalla dedicada con saldo disponible, saldo retenido en custodia, desglose de asientos contables y recarga directa. |
| **Mi Portafolio (Antes/Después)** | ✅ **Completo y Conectado** | Slider interactivo táctil para comparación de fotos antes y después del servicio. |
| **Servicio SOS de Urgencias (< 30 min)** | ✅ **Completo y Conectado** | Tarifa dinámica de emergencia y despacho prioritario. |
| **Escudo de Confianza y Verificación** | ✅ **Completo y Conectado** | Tarjetas de verificación de identidad, badges profesionales y reputación comunitaria. |

---

## 👥 Experiencia y Funcionalidades por Rol

La aplicación utiliza dos interfaces modulares independientes coordinadas por `AppState`:

### 👤 Modo Cliente (`ClientShell`)
- **Inicio y Categorías:** Grilla responsiva de servicios con íconos vectoriales y banner de solicitud rápida SOS.
- **Publicación de Solicitudes (`PostJobScreen`):** Selección de especialidad, geolocalización en mapa interactivo OpenStreetMap, diagnóstico orientativo asistido por IA (`Gemini`) y ajuste de presupuesto con semáforo interactivo de precios (`PriceDialStepper`).
- **Mis Solicitudes (`ClientMyRequestsScreen`):** Seguimiento de órdenes activas, negociación y archivo histórico.
- **Bandeja de Ofertas (`ReceivedBidsScreen`):** Comparación transparente de técnicos postulantes con calificación, distancia y propuesta económica.
- **Rastreo y Chat (`JobTrackingScreen`, `ChatScreen`):** Vista de progreso del técnico y mensajería en vivo.
- **Perfil de Usuario (`UserProfileScreen`):** Datos personales, verificación y acceso al cambio de rol.

### 🛠️ Modo Trabajador (`WorkerShell`)
- **Chambas Disponibles (`AvailableJobsScreen`):** Lista filtrable por oficio (Gasfitería, Electricidad, etc.), distancia geoespacial PostGIS y etiqueta SOS urgente. Switch de disponibilidad para recibir ofertas.
- **Detalle y Envío de Propuesta (`SendBidScreen`):** Envío de presupuesto formal con opción de contraoferta justificada.
- **Mis Trabajos (`WorkerMyJobsScreen`):** Pestañas inmediatas (**Activas**, **Negociando**, **Historial**) sin elementos duplicados, con listados filtrados y estados vacíos amigables.
- **Mi Perfil (`WorkerProfileScreen`):** Tarjeta de identidad técnica, badges del Escudo de Confianza, botón directo para alternar a Cliente y lista de accesos independientes.
- **Mi Billetera (`WorkerWalletScreen`):** Desglose en vivo de saldo disponible, saldo en custodia (Escrow), libro mayor contable y niveles de gamificación.
- **Mi Portafolio (`WorkerPortfolioScreen`):** Pantalla secundaria dedicada para exhibir trabajos culminados mediante el control interactivo Antes/Después (`BeforeAfterSlider`).

---

## 🏗️ Arquitectura y Estructura del Repositorio

El proyecto mantiene una estricta separación de responsabilidades entre el frontend móvil y el backend de servicios:

```text
CHAMBA/
├── .env.example                    # Plantilla base de variables de entorno (sin secretos)
├── .gitignore                      # Reglas de exclusión seguras para Flutter, Node y PostgreSQL
├── CONTRIBUTING.md                 # Guía para el trabajo colaborativo en equipo con Git
├── HOW_TO_RUN.md                   # Manual detallado de instalación, ejecución y despliegue físico
├── README.md                       # Documento principal de presentación
├── pubspec.yaml                    # Dependencias y configuración de Flutter
│
├── backend/                        # Backend Full-Stack con NestJS, Prisma y Redis
│   ├── .env.example                # Plantilla de entorno (Postgres, Redis, R2, Gemini, JWT)
│   ├── package.json                # Dependencias npm y scripts (build, test, lint, test:e2e)
│   ├── tsconfig.json               # Configuración TypeScript moderna (ESNext / NodeNext)
│   ├── prisma/
│   │   ├── schema.prisma           # Esquema Prisma (User, WorkerProfile, Wallet, LedgerEntry)
│   │   ├── seed.ts                 # Datos de prueba (Ana García, José Torres, Carlos Ramírez)
│   │   └── migrations/             # Migraciones SQL (PostGIS, Wallet, Ledger)
│   ├── src/
│   │   ├── main.ts                 # Bootstrap NestJS, Redis IoAdapter, Swagger (/api/docs)
│   │   ├── app.module.ts           # Módulo raíz de la aplicación
│   │   ├── auth/                   # Autenticación JWT, bcrypt, guards y decoradores
│   │   ├── users/                  # Endpoints de consulta y perfil (/api/v1/users)
│   │   ├── worker-profile/         # Perfil de especialista (/api/v1/worker-profile)
│   │   ├── location/               # Motor geoespacial PostGIS (/api/v1/location)
│   │   ├── events/                 # Gateway WebSockets y salas de negociación en tiempo real
│   │   ├── redis/                  # Servicio Redis Pub/Sub y gestión de presencia
│   │   ├── finance/                # FinTech Escrow, Ledger inmutable y webhooks HMAC
│   │   ├── storage/                # Cloudflare R2 Presigned URLs para subida multimedia
│   │   ├── ai/                     # Diagnóstico visual de averías con Google Gemini IA
│   │   └── prisma/                 # Servicio de conexión y ciclo de vida de PrismaClient
│   └── test/                       # Pruebas e2e (auth, location, events, finance, cloud-integrations)
│
├── lib/                            # Código fuente de la aplicación Flutter
│   ├── main.dart                   # Punto de entrada, verificación de sesión e inicialización
│   ├── core/                       # Núcleo de diseño, temas y widgets transversales
│   │   ├── theme/                  # AppColors (paleta institucional), AppTypography y AppTheme
│   │   └── widgets/                # ChambaButton, ChambaCard, ChambaBadge, PriceDialStepper, BeforeAfterSlider
│   ├── data/                       # Capa de datos y persistencia
│   │   ├── models/                 # Modelos serializables: UserAccount, JobRequest, Bid, etc.
│   │   ├── services/               # AuthApiService (cliente HTTP REST) y SessionStorage (Secure Storage)
│   │   └── mock/                   # MockData para desarrollo de flujos offline
│   └── presentation/               # Capa de interfaz de usuario
│       ├── state/                  # AppState (gestor reactivo centralizado con ValueNotifier)
│       ├── screens/                # 21 pantallas optimizadas y adaptables
│       └── widgets/                # Componentes modulares y hojas modales (Notifications, AI Diagnosis)
│
├── odd/                            # Registros de Organic Driven Development (ODD)
│   └── tasks/                      # Tareas de arquitectura, seguridad, refactorización y changelog
│
├── postman/                        # Herramientas de prueba de endpoints REST
│   ├── CHAMBA_API.postman_collection.json
│   └── CHAMBA_Environment.postman_environment.json
│
└── test/                           # Pruebas automatizadas de Flutter (37 tests pasando)
    ├── core/                       # Pruebas de tokens, temas y widgets base
    ├── data/                       # Pruebas de modelos y ciclo de vida de estado
    └── presentation/               # Pruebas de integración, navegación y responsive layout
```

---

## 🛠️ Tecnologías Utilizadas

### Frontend Móvil
- **Framework:** Flutter SDK `^3.13.5` + Dart.
- **Gestión de Estado:** `ValueNotifier` reactivo centralizado en [`AppState`](file:///c:/Users/Julio/Desktop/Proyectos/CHAMBA/lib/presentation/state/app_state.dart).
- **Seguridad en Dispositivo:** `flutter_secure_storage` para almacenamiento protegido de tokens JWT.
- **Consumo HTTP y API:** [`ApiClient`](file:///c:/Users/Julio/Desktop/Proyectos/CHAMBA/lib/data/services/api_client.dart) desacoplado con inyección de Bearer tokens, intercepción 401 y flags `--dart-define`.
- **Tiempo Real y WebSockets:** `socket_io_client` para negociación bidireccional en vivo (`sendBid`, `counterOffer`, `acceptBid`).
- **Multimedia y Fotos:** `image_picker` integrado para captura de averías y subida directa a Cloudflare R2 con URL prefirmada.
- **Mapas y Geolocalización:** `flutter_map` (OpenStreetMap) + `latlong2` + `geolocator` con soporte PostGIS nativo.
- **Diseño y Tipografía:** `google_fonts` (Manrope para interfaz y DM Sans para datos/cifras) e `intl` (formato Soles S/.).

### Backend y Base de Datos
- **Entorno:** Node.js v24 (LTS) + TypeScript moderno (ESM / NodeNext).
- **Framework:** NestJS 12 modular con validación estricta de DTOs (`class-validator`, `class-transformer`).
- **Base de Datos Principal:** PostgreSQL 18 (`chamba_db`) con extensión geoespacial **PostGIS** (`geometry(Point, 4326)`) e índices espaciales GIST.
- **Caché y Mensajería Real-Time:** **Redis 7+** con adaptador Pub/Sub para Socket.IO multiclúster y control de presencia en tiempo real (`user:online`).
- **ORM:** Prisma 6.x con migraciones SQL versionadas y tipado seguro en tiempo de compilación.
- **Comunicación en Tiempo Real:** **Socket.IO** (`@nestjs/platform-socket.io`, `@nestjs/websockets`) con salas dinámicas por orden (`job:{id}`) y autenticación JWT.
- **Inteligencia Artificial Multimodal:** **Google Gemini 2.5 Flash** (`@google/genai`) con Structured Outputs JSON y motor de contingencia de alta disponibilidad.
- **Almacenamiento Cloud:** **Cloudflare R2** (compatible con S3) con **Presigned URLs** generadas mediante AWS SDK v3 para fotos y notas de voz.
- **FinTech y Criptografía:** Transacciones ACID con aislamiento `SERIALIZABLE`, bloqueos de fila `SELECT ... FOR UPDATE`, libro mayor inmutable, `bcrypt` (10 rounds) y HMAC-SHA256 con `timingSafeEqual`.
- **Documentación de API:** Swagger / OpenAPI interactivo en `/api/docs`.

---

## 🎨 Diseño Visual y Optimización Responsive

CHAMBA utiliza un sistema de diseño institucional inspirado en tonos peruanos:
- **Petroleum Blue (`#173B4D`):** Identidad, cabeceras y botones principales.
- **Brick Terracotta (`#B84A1C`):** Acentos de negociación, contraofertas y llamadas a la acción.
- **Highland Green (`#237553`):** Estados de éxito, acuerdos confirmados y saldos.
- **Warm Canvas (`#F8F6F1`):** Fondo cálido que previene la fatiga visual.

### Adaptabilidad Android
La interfaz ha sido sometida a una auditoría responsive para garantizar que **no existan desbordamientos (`RenderFlex overflow`)** en ningún dispositivo Android:
- **Resoluciones comprobadas:** Compacto (320 × 568 dp), Pequeño (360 × 640 dp), Mediano (393 × 852 dp), Grande (412 × 915 dp) y Grande Ancho (430 × 932 dp).
- **Accesibilidad:** Soporta aumentos de tamaño de fuente del sistema (1.3x y 1.5x) mediante contenedores con `Wrap` y `Flexible`.
- **Comportamiento con Teclado:** Pantallas de formulario con `SingleChildScrollView` y respeto de `viewInsets.bottom`.

---

## 🚀 Inicio Rápido

### 1. Iniciar el Backend (NestJS + PostgreSQL/PostGIS)
```bash
cd backend
npm install
# Configura backend/.env a partir de backend/.env.example
npx prisma migrate deploy
npx prisma db seed
npm run start:dev
```
- API REST: `http://localhost:3000/api/v1`
- Swagger Docs: `http://localhost:3000/api/docs`

### 2. Iniciar el Frontend Flutter
```bash
# En la raíz del proyecto
flutter pub get

# Ejecutar en Emulador Android apuntando a la API local
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:3000 --dart-define=USE_MOCKS=false

# O para celular físico conectado por USB (previamente: adb reverse tcp:3000 tcp:3000)
flutter run -d <device_id> --dart-define=API_BASE_URL=http://localhost:3000 --dart-define=USE_MOCKS=false
```

---

## 🧪 Pruebas Automatizadas y Calidad

El proyecto cuenta con suites de pruebas verificadas en verde:

```bash
# 1. Pruebas del Frontend Flutter
flutter test

# 2. Análisis estático del código Dart (0 errores)
flutter analyze

# 3. Pruebas de integración E2E del Backend (11 tests)
cd backend
npm run test:e2e

# 4. Pruebas unitarias del Backend (1 test)
npm run test
```

---

## 📚 Guías de Colaboración y Ejecución

Para profundizar en el trabajo con el repositorio, consulta la documentación dedicada:

- 📖 **[HOW_TO_RUN.md](HOW_TO_RUN.md):** Manual completo paso a paso para clonar, configurar PostgreSQL y PostGIS en Windows, correr migraciones, vincular el emulador Android (`10.0.2.2:3000`) o celular físico, y compilar la APK debug.
- 🤝 **[CONTRIBUTING.md](CONTRIBUTING.md):** Estándares de trabajo colaborativo para el equipo (ramas, Conventional Commits, Pull Requests, sincronización de Prisma sin perder datos y resolución de conflictos).

---

## 🗺️ Roadmap y Fases Implementadas

- [x] **Fase 1:** Arquitectura Flutter, 21 pantallas, estado reactivo `AppState`, backend NestJS, base de datos PostgreSQL, migraciones Prisma, autenticación JWT y optimización responsive.
- [x] **Fase 2:** Búsqueda geoespacial con **PostGIS** (`ST_DWithin`) en backend y frontend, mapa interactivo y actualización de ubicación del chambeador.
- [x] **Fase 3:** WebSockets con **Socket.IO** en NestJS y cliente Flutter para negociación bidireccional en tiempo real (`sendBid`, `counterOffer`, `acceptBid`) y salas dinámicas por solicitud.
- [x] **Fase 4 (FinTech & Cloud IA):** 
  - Pagos protegidos en custodia (**Escrow**) con transacciones ACID y Libro Mayor inmutable (`GET /finance/wallet`, `POST /finance/escrow/hold`, `POST /finance/escrow/release`).
  - Diagnóstico asistido por IA multimodal (**Google Gemini 2.5 Flash**) y subida de imágenes a **Cloudflare R2** vía URLs prefirmadas.
  - Integración total Frontend-Backend en Flutter con reglas de veracidad y honestidad de datos (sin sellos falsos, tarifas a convenir y source checks).
- [ ] **Fase 5:** Validación automatizada de identidad peruana con RENIEC y antecedentes PNP.
- [ ] **Fase 6:** Notificaciones Push nativas vía Firebase Cloud Messaging (FCM).

---

## 📄 Licencia

Este proyecto se distribuye bajo la licencia **MIT**. Consulta el archivo `LICENSE` para más detalles.
