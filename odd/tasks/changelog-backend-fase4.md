# Registro de Cambios y Arquitectura Backend — Fase 4: Cloud, FinTech, Real-Time & IA

**Proyecto:** CHAMBA Perú 🇵🇪  
**Fecha:** Octubre 2026  
**Autor:** Antigravity AI — Tech Lead & Cloud Integrations Architect  
**Estado:** ✅ Consolidado y Verificado (0 issues en `flutter analyze`, 0 warnings en `oxlint`, 100% tests passing)

---

## 1. Resumen Ejecutivo de la Fase 4

Desde el último commit (`803ec9c`), CHAMBA evolucionó de una API base de autenticación a una plataforma **Full-Stack de alta concurrencia y grado FinTech**, incorporando capacidades geoespaciales, sincronización bidireccional en tiempo real, custodia de pagos con libro mayor inmutable, almacenamiento directo en Cloudflare R2 y diagnóstico visual automatizado mediante Google Gemini IA.

```
┌────────────────────────────────────────────────────────────────────────┐
│                        CHAMBA Mobile (Flutter)                         │
└────────────┬───────────────────────────┬──────────────────────┬────────┘
             │ HTTP REST                 │ WebSockets           │ Direct Upload
             ▼                           ▼                      ▼
┌─────────────────────────┐  ┌───────────────────────┐  ┌────────────────┐
│   NestJS 12 Gateway     │  │ Socket.IO + Redis Pub │  │ Cloudflare R2  │
│  Controllers & Guards   │  │   Ephemeral Rooms     │  │ (Presigned S3) │
└────────────┬────────────┘  └───────────┬───────────┘  └────────────────┘
             │                           │
             ▼                           ▼
┌────────────────────────────────────────────────────┐
│      PostgreSQL 18 + PostGIS + Prisma ORM          │
│   (GIST Index, Immutable Ledger, ACID Escrow)       │
└────────────────────────────────────────────────────┘
```

---

## 2. Desglose Exhaustivo de Módulos Implementados

### 2.1 Motor Geoespacial con PostGIS (`src/location/`)
- **Migración SQL Nativa:** Habilitación de la extensión `postgis` en PostgreSQL (`CREATE EXTENSION IF NOT EXISTS postgis;`) y adición de la columna `location geometry(Point, 4326)` indexada con índice espacial GIST (`worker_profiles_location_idx`).
- **Prisma Schema:** Integración de la columna no nativa mediante `location Unsupported("geometry(Point, 4326)")?` en el modelo `WorkerProfile`.
- **Servicio `LocationService`:**
  - `findNearbyWorkers(lat, lng, radiusKm, specialty)`: Consulta cruda ultraoptimizada con `ST_DWithin` y `ST_DistanceSphere` para devolver trabajadores en un radio de acción en milisegundos, calculando distancia exacta en metros y kilómetros.
  - `updateWorkerLocation(userId, lat, lng)`: Actualización atómica de coordenadas GPS con `ST_SetSRID(ST_MakePoint(lng, lat), 4326)`.
- **Controlador `LocationController`:**
  - `GET /api/v1/location/workers/nearby` (Búsqueda geoespacial protegida con radio dinámico).
  - `PUT /api/v1/location/my-location` (Actualización de geoposición para técnicos).
- **Pruebas:** 4 tests unitarios y 7 tests E2E en [location.e2e-spec.ts](file:///c:/Users/megac/Desktop/chamba/V2/chamba/backend/test/location.e2e-spec.ts).

---

### 2.2 Comunicación en Tiempo Real y Redis Pub/Sub (`src/events/`, `src/redis/`)
- **Escalabilidad Horizontal:** Configuración del adaptador `IoAdapter` en `main.ts` con `@socket.io/redis-adapter` para sincronizar eventos en clústeres multi-instancia de NestJS.
- **Gateway WebSocket (`EventsGateway`):**
  - Autenticación en el apretón de manos (*handshake*) mediante JWT y extracción de identidad.
  - Sesiones efímeras y presencia en Redis (`user:online:{userId}`) con soporte para múltiples dispositivos simultáneos (móvil y web).
  - Salas de negociación por solicitud de trabajo (`job:{jobRequestId}`).
- **Eventos Bidireccionales Soportados:**
  - `bid:new`: Envío y difusión instantánea de cotizaciones de técnicos.
  - `bid:counter`: Contraofertas bidireccionales cliente-técnico (modelo inDrive).
  - `bid:accept`: Notificación inmediata de aceptación de propuesta.
  - `job:status:update`: Transiciones de estado del servicio (*En camino*, *Llegó*, *En progreso*, *Completado*).
  - `worker:location:stream`: Telemetría en vivo del técnico en desplazamiento.
- **Pruebas:** 10 tests unitarios y 6 tests E2E en [events.e2e-spec.ts](file:///c:/Users/megac/Desktop/chamba/V2/chamba/backend/test/events.e2e-spec.ts).

---

### 2.3 FinTech Escrow y Libro Mayor Inmutable (`src/finance/`)
- **Principio Contable Inmutable:** El saldo de una billetera nunca se sobrescribe en una columna mutable. Se calcula agregando algebraicamente los asientos del Libro Mayor (`LedgerEntry`).
- **Modelos Prisma:**
  - `Wallet`: Vinculada 1:1 con `User`.
  - `LedgerEntry`: Asiento inmutable con `id`, `walletId`, `amount` (Decimal con signo), `type` (`DEPOSIT`, `HOLD_ESCROW`, `RELEASE_ESCROW`, `WITHDRAW`, `REFUND_ESCROW`), `jobRequestId` y marcas de tiempo.
- **Servicio `FinanceService`:**
  - `holdFundsInEscrow(clientId, jobRequestId, amount)`: Retención de fondos en custodia al aceptar una oferta, ejecutada bajo nivel de aislamiento `SERIALIZABLE` y bloqueo de fila `SELECT ... FOR UPDATE` en PostgreSQL.
  - `releaseEscrow(clientId, workerUserId, jobRequestId, amount)`: Liberación del pago al técnico una vez que el cliente confirma la culminación satisfactoria.
  - `verifyWebhookSignature(payload, signature, secret)`: Verificación criptográfica HMAC-SHA256 mediante `crypto.timingSafeEqual` para prevenir ataques de temporización.
  - `getWalletSummary(userId)`: Auditoría de saldo disponible, saldo retenido y balance total.
- **Prevención de Doble Gasto (Race Conditions):** Simulación E2E de dos retenciones concurrentes de S/. 80 con un saldo de S/. 100 ejecutadas en paralelo (`Promise.all`), verificando que una transacción aprueba (201) y la otra rechaza (400), dejando el saldo exacto en S/. 20.
- **Pruebas:** 7 tests unitarios y 4 tests E2E en [finance.e2e-spec.ts](file:///c:/Users/megac/Desktop/chamba/V2/chamba/backend/test/finance.e2e-spec.ts).

---

### 2.4 Almacenamiento en Cloudflare R2 con Presigned URLs (`src/storage/`)
- **Arquitectura Directa al Almacenamiento:** Integración con AWS SDK v3 (`@aws-sdk/client-s3` y `@aws-sdk/s3-request-presigner`) sobre el endpoint S3-compatible de Cloudflare R2.
- **Endpoint `GET /api/v1/storage/upload-url`:**
  - Genera URLs firmadas para subida directa de fotografías de averías y notas de voz con expiración de 15 minutos (900s).
  - Sanitización estricta contra *directory traversal* (`../`) y caracteres peligrosos.
- **Pruebas:** 3 tests unitarios y 3 tests E2E en [cloud-integrations.e2e-spec.ts](file:///c:/Users/megac/Desktop/chamba/V2/chamba/backend/test/cloud-integrations.e2e-spec.ts).

---

### 2.5 Diagnóstico de Averías con Google Gemini IA (`src/ai/`)
- **SDK Oficial Google GenAI (`@google/genai`):** Utilización del modelo `gemini-2.5-flash` con **Structured Outputs** (`responseSchema` estricto con `Type.OBJECT`).
- **Endpoint `POST /api/v1/ai/diagnose`:**
  - Recibe `imageUrl` y descripción textual del usuario.
  - Retorna JSON estructurado: `category` (Gasfitería, Electricidad, Carpintería, etc.), `technicalDescription`, `estimatedPriceRange` (mínimo, máximo, Soles PEN) y `materialsNeeded` (lista de repuestos requeridos).
- **Alta Disponibilidad:** Motor interno de diagnóstico de contingencia que entra en acción ante fallos de conexión o cuotas de la API externa, evitando caídas en la experiencia del cliente.
- **Pruebas:** 5 tests unitarios y 4 tests E2E en [cloud-integrations.e2e-spec.ts](file:///c:/Users/megac/Desktop/chamba/V2/chamba/backend/test/cloud-integrations.e2e-spec.ts).

---

### 2.6 Refactorización y Mejoras de la UI en Flutter
- **Diagnóstico Visual con IA en `post_job_screen.dart`:** Tarjeta interactiva con simulación de escaneo multiescenario (Tubería goteando, Enchufe chispeando, Puerta trabada) y autocompletado de materiales y precios sugeridos.
- **Semáforo de Precio Justo en `price_dial_stepper.dart`:** Indicador visual de rango (Verde: Justo / Amarillo: Ajustado / Rojo: Fuera de mercado).
- **Tarifa Dinámica SOS y Escudo de Confianza:** Botones de acción inmediata (< 30 min) y credenciales de confianza visuales.
- **Limpieza de Recursos:** Eliminación de copias duplicadas de `chamba.png` en la raíz y en `assets/`, consolidando `assets/images/chamba.png` como única fuente de verdad en `pubspec.yaml` y pantallas.

---

## 3. Resumen de Calidad y Pruebas

| Componente | Herramienta | Resultado |
|---|---|---|
| **Frontend Dart Linter** | `flutter analyze` | **0 issues found** |
| **Frontend Tests** | `flutter test` | **37 passed** |
| **Backend TypeScript Linter** | `oxlint --type-aware` | **0 warnings, 0 errors** (66 archivos) |
| **Backend Unit Tests** | `vitest run` | **33 passed** (8 archivos) |
| **Backend E2E Tests** | `vitest run --config vitest.config.e2e.ts` | **24 passed** (4 suites) |
| **Backend Build** | `nest build` | **Compilación limpia (dist/ exit 0)** |
