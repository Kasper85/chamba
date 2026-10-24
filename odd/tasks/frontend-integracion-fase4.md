# Feature: CHAMBA — Integración Frontend con Backend Fase 4 (Geolocalización, FinTech, WebSockets y Cloud IA)

## Objetivo
Integrar la aplicación móvil Flutter (`lib/`) con los servicios backend NestJS + PostgreSQL/PostGIS (`backend/`) en la rama `feature/frontend-integracion-fase4`, aplicando ODD con TDD estricto (Red -> Green -> Refactor), análisis estático (`flutter analyze`), pruebas automatizadas (`flutter test`) y validación interactiva en vivo con Mobile MCP en el emulador Android `Medium_Phone`.

---

## Alcance y Restricciones Aprobados

### En Alcance (Porciones S0 a S6)
1. **S0. Infraestructura de Red y Configuración:**
   - Creación de un `ApiClient` centralizado y desacoplado (base URL configurable por `--dart-define=API_BASE_URL=...`, inyección de token Bearer desde `flutter_secure_storage`, timeouts, manejo estructurado de errores y cierre de sesión seguro ante respuestas `401 Unauthorized` redirigiendo al login).
   - Refactorización de `AuthApiService` para delegar su transporte HTTP en `ApiClient` sin alterar su comportamiento ni romper contratos existentes.
   - Interruptor global `--dart-define=USE_MOCKS=true|false`. En modo `USE_MOCKS=false`, cualquier fallo de red/API muestra estado de error con reintento (NUNCA cae a mocks en silencio).
   - Declaración de permisos `INTERNET`, `ACCESS_FINE_LOCATION` y `ACCESS_COARSE_LOCATION` en `android/app/src/main/AndroidManifest.xml`.
   - Configuración de seguridad de red (`network_security_config.xml`) limitando tráfico HTTP en texto claro únicamente a hosts de desarrollo local (`10.0.2.2`, `localhost`).
2. **S1. Búsqueda y Despliegue de Técnicos Cercanos (Modo Cliente):**
   - Consumo de `GET /api/v1/location/nearby` con coordenadas obtenidas mediante `geolocator` (`lat`, `lng`, `radiusKm`, `specialty` opcional).
   - Renderizado dinámico en `ChambaInteractiveMap` y en lista de tarjetas ordenadas por `distanceKm`.
   - Manejo de permisos de geolocalización (denegado/desactivado -> mensaje claro y búsqueda sobre el centro de Chiclayo, indicándolo en pantalla).
   - Estados de carga (shimmer/spinner), estado vacío («No hay técnicos disponibles en X km») y estado de error con reintento.
   - **Regla estricta de UI:** No mostrar el correo electrónico de los técnicos en la interfaz aunque la API lo devuelva. Para técnicos reales, mostrar «Tarifa a convenir» (sin inventar montos) y ocultar sellos de verificación falsos.
3. **S2. Ubicación y Disponibilidad del Técnico (Modo Chambeador):**
   - Actualización de geoposición mediante `PUT /api/v1/location/worker` al abrir el shell del técnico (`WorkerShell`) y al alternar el switch de disponibilidad.
   - Respetar que no existe telemetría de seguimiento continuo en el backend.
4. **S3. Billetera y Libro Mayor del Técnico:**
   - Consumo de `GET /api/v1/finance/wallet` en `WorkerWalletScreen` para mostrar saldo disponible real, saldo en custodia (Escrow) y lista de transacciones recientes del Ledger inmutable.
   - Gráfico semanal derivado legítimamente de las transacciones reales del usuario en los últimos 7 días.
   - **Prohibido:** NO agregar botón de recarga directa que consuma `POST /finance/deposit` (vulnerabilidad de backend).
5. **S4. Diagnóstico Técnico con IA Multimodal:**
   - Incorporación del paquete `image_picker` (aprobado).
   - Flujo: Obtener URL prefirmada con `GET /api/v1/storage/upload-url` -> Subida directa a Cloudflare R2 -> Llamada a `POST /api/v1/ai/diagnose` con `{ imageUrl, prompt }` -> Precarga de categoría profesional y rango de precio sugerido en `PostJobScreen` (editable por el usuario).
   - **Manejo de contingencia y honestidad:**
     * Si la subida a R2 falla (por R2 no configurado o error de red), mostrar mensaje claro «No se pudo subir la foto» y permitir continuar sin diagnóstico.
     * Inspeccionar el campo `source` de `/ai/diagnose`. Si no proviene de Gemini (ej. motor de contingencia), la UI debe rotular «Sugerencia automática (sin IA)» en lugar de «Diagnóstico con IA». Jamás vender el respaldo como IA.
     * Evidencia: probar ambos caminos (subida fallida y motor de respaldo).
6. **S5. Ofertas y Contraofertas en Tiempo Real (Socket.IO):**
   - Incorporación del paquete `socket_io_client` compatible con Socket.IO v4.8.4 del backend.
   - Conexión WebSocket autenticada inyectando el token JWT en el handshake (`auth: { token }`).
   - Gestión de salas por solicitud (`joinJobRoom`) al abrir un trabajo (usando los IDs de MockData como `jobRequestId`).
   - Envío de ofertas (`sendBid`) desde el técnico, recepción en vivo en cliente (`newBidReceived`), contraofertas (`counterOffer` -> `counterOfferReceived`) y aceptación (`acceptBid` -> `bidAccepted`).
   - Reconexión automática y estado visible de «Sin conexión en vivo».
   - Distintivo visual: «Trabajo DEMO · ofertas en vivo».
7. **S6. Retención y Liberación de Fondos en Custodia (Escrow FinTech):**
   - Al aceptar una oferta: llamada a `POST /api/v1/finance/escrow/hold` con el monto acordado y el `jobRequestId`.
   - Al confirmar el trabajo culminado: llamada a `POST /api/v1/finance/escrow/release` enviando el `workerUserId` real obtenido en la oferta recibida por socket.
   - Manejo de excepciones transaccionales: Saldo insuficiente (`400`) o retención duplicada (`409`) muestran aviso claro al usuario sin corromper el estado local de la app.

### Fuera de Alcance
- Persistencia en base de datos de solicitudes de trabajo (`JobRequest`), mensajes de chat y notificaciones push (el backend no cuenta con tablas para estas entidades en `schema.prisma`).

---

## 1. Tabla de Contrato Real del Backend

| Endpoint / Evento | Protocolo | Auth | Request (Body / Query) | Response Real del Backend | Pantalla Flutter Receptora |
|---|---|---|---|---|---|
| `GET /api/v1/location/nearby` | HTTP GET | Pública (Sin Auth) | Query: `lat` (num, req), `lng` (num, req), `radiusKm` (num, opt, def: 5), `specialty` (str, opt) | `{ searchCenter: { latitude, longitude, radiusKm, specialty }, count: number, workers: [ NearbyWorkerResult ] }` | `ClientHomeScreen`, `ChambaInteractiveMap` |
| `PUT /api/v1/location/worker` | HTTP PUT | Bearer JWT (Técnico) | Body: `{ latitude: number, longitude: number }` | `{ success: true, message: string, workerProfileId: string, userId: string, latitude: number, longitude: number, updatedAt: string }` | `WorkerShell`, `AvailableJobsScreen` |
| `GET /api/v1/location/worker/me` | HTTP GET | Bearer JWT (Técnico) | Ninguno | `{ workerProfileId: string, userId: string, latitude: number \| null, longitude: number \| null }` | `WorkerProfileScreen` |
| `GET /api/v1/finance/wallet` | HTTP GET | Bearer JWT | Ninguno | `{ walletId, userId, availableBalance, inEscrowBalance, totalBalance, currency: 'PEN', recentTransactions: [ { id, amount, type, jobRequestId, description, createdAt } ] }` | `WorkerWalletScreen` |
| `POST /api/v1/finance/deposit` | HTTP POST | Bearer JWT | Body: `{ amount: number, description?: string, jobRequestId?: string }` | `{ success: true, message: string, ledgerEntryId: string, amount: number, newBalance: number }` | *Bloqueado en UI por seguridad* |
| `POST /api/v1/finance/escrow/hold` | HTTP POST | Bearer JWT (Cliente) | Body: `{ jobRequestId: string, amount: number, description?: string }` | `{ success: true, message: string, ledgerEntryId: string, jobRequestId: string, amountHeld: number, remainingAvailableBalance: number }` | Flujo de Aceptación de Oferta (S6) |
| `POST /api/v1/finance/escrow/release` | HTTP POST | Bearer JWT (Cliente) | Body: `{ workerUserId: string, jobRequestId: string, amount?: number }` | `{ success: true, message: string, releaseEntryId: string, jobRequestId: string, amountReleased: number, workerUserId: string, workerNewAvailableBalance: number }` | Flujo de Confirmación de Término (S6) |
| `GET /api/v1/storage/upload-url` | HTTP GET | Pública / Swagger | Query: `filename?: string`, `contentType?: string` (def: 'image/jpeg'), `folder?: string` (def: 'uploads') | `{ uploadUrl: string, fileKey: string, publicUrl: string, expiresIn: 900, contentType: string }` | `PostJobScreen` (Diagnóstico IA - S4) |
| `POST /api/v1/ai/diagnose` | HTTP POST | Pública / Swagger | Body: `{ imageUrl: string, prompt?: string }` | `{ category: string, technicalDescription: string, estimatedPriceRange: { min, max, currency, formatted }, materialsNeeded: string[], source: string, confidence: number }` | `PostJobScreen` (Autocompletado - S4) |
| `WS joinJobRoom` | WebSocket Emit | Conexión JWT | Payload: `{ jobRequestId: string }` | Ack / Evento: `joinedJobRoom` `{ event, success, jobRequestId, room }` | `JobTrackingScreen` / `ReceivedBidsScreen` (S5) |
| `WS sendBid` | WebSocket Emit | Conexión JWT | Payload: `{ jobRequestId, amount, message?, estimatedArrival?, includesMaterials?, ... }` | Broadcast a sala: `newBidReceived` `{ id, jobRequestId, workerId, workerName, amount, ... }` | `SendBidScreen` (S5) |
| `WS counterOffer` | WebSocket Emit | Conexión JWT | Payload: `{ jobRequestId, counterAmount, note? }` | Broadcast a sala: `counterOfferReceived` `{ jobRequestId, senderId, senderName, counterAmount, note, timestamp }` | Negociación en tiempo real (S5) |
| `WS acceptBid` | WebSocket Emit | Conexión JWT | Payload: `{ jobRequestId, bidId, agreedAmount }` | Broadcast a sala: `bidAccepted` `{ jobRequestId, bidId, agreedAmount, acceptedBy, timestamp }` | Cierre de Trato en vivo (S5 / S6) |

---

## 2. Matriz de Brechas Corregida y Decisiones de Integración

| Modelo Dart | Campo en UI | En Backend | Decisión Aprobada | Estado de Propuestas Anteriores |
|---|---|---|---|---|
| **WorkerProfile** | `id` / `workerProfileId` | ✅ Presente | Mapeo directo. | Aprobado. |
| **WorkerProfile** | `name` / `fullName` | ✅ Presente | Mapeo directo. | Aprobado. |
| **WorkerProfile** | `avatarInitials` | ❌ No existe | Derivar en cliente desde `fullName` (ej. "Ana García" -> "AG"). | Aprobado. |
| **WorkerProfile** | `email` | ✅ Presente | **Oculto en UI:** No mostrar correo en interfaz por privacidad. | Ajuste solicitado. |
| **WorkerProfile** | `phone` | ✅ Presente | Mapeo directo desde `User`. | Aprobado. |
| **WorkerProfile** | `rating` | ✅ Presente | Mapeo directo (`double`). | Aprobado. |
| **WorkerProfile** | `completedJobs` | ✅ Presente | Mapeo directo (`int`). | Aprobado. |
| **WorkerProfile** | `specialty` | ✅ Presente | Mapeo directo (string). | Aprobado. |
| **WorkerProfile** | `skills` | ❌ No existe | Lista con la especialidad única registrada (`[specialty]`). | Aprobado. |
| **WorkerProfile** | `district` | ✅ Presente | Mapeo directo. | Aprobado. |
| **WorkerProfile** | `baseRate` | ❌ No existe | **"Tarifa a convenir"** para técnicos reales. | ❌ *Rechazada propuesta previa de fallback S/ 40.* |
| **WorkerProfile** | `isIdVerified`, `hasCleanRecord`, `offersWarranty` | ❌ No existen | **Ocultos para técnicos reales.** Un sello falso es inaceptable. Solo se muestran en datos DEMO rotulados. | ❌ *Rechazada propuesta previa de inferir por estado ACTIVE.* |
| **WorkerProfile** | `experienceYears` | ❌ No existe | **Oculto para técnicos reales** (no estimar). | ❌ *Rechazada propuesta previa de estimación.* |
| **WorkerProfile** | `reviews` | ❌ Sin tabla | **Estado vacío ("Aún sin reseñas")** para técnicos reales. Reseñas demo solo en perfiles demo. | Aprobado. |
| **WorkerProfile** | `portfolioCases` | ❌ Sin tabla | **Estado vacío** para técnicos reales. Casos demo solo en perfiles demo. | Aprobado. |
| **WorkerProfile** | `latitude`, `longitude`, `distanceKm` | ✅ Presente en PostGIS | Mapeo directo de coordenadas y cálculo de distancia. | Aprobado. |
| **Wallet / Ledger** | `availableBalance`, `inEscrowBalance` | ✅ Presente | Mapeo directo desde `GET /finance/wallet`. | Aprobado. |
| **Wallet / Ledger** | `recentTransactions` | ✅ Presente | Mapeo directo desde `ledger_entries`. | Aprobado. |
| **Wallet / Ledger** | Gráfico semanal (Lun-Dom) | ❌ No agregado en API | **Cálculo legítimo:** Agrupar transacciones reales de los últimos 7 días por día. | Aprobado (cálculo real, no invento). |
| **Wallet / Ledger** | Nivel/Gamificación | ❌ No en backend | **Oculto o marcado DEMO**; no inventar umbrales no respaldados. | ❌ *Rechazada propuesta previa de cálculo heurístico.* |
| **JobRequest** | Campos de trabajo | ❌ Sin tabla en DB | Gestionado en memoria por `AppState` con IDs usados como `jobRequestId` para sockets y escrow. | Aprobado. |
| **Bid** | Cotizaciones y contraofertas | ❌ Sin tabla en DB | Transmitidas en vivo por WebSockets (`sendBid`, `counterOffer`, `acceptBid`). | Aprobado. |

---

## 3. Entidades Sin Persistencia en Backend (Modo Demo Señalizado)

Las siguientes 7 entidades no tienen tabla en `schema.prisma`:
1. `JobRequest` (Solicitudes de Chamba).
2. `Bid` (Cotizaciones).
3. `ChatMessage` (Mensajes de chat).
4. `AppNotification` (Notificaciones).
5. `WorkerReview` (Reseñas escritas).
6. `PortfolioCase` (Galería Antes/Después).
7. `Category` (Catálogo relacional).

En Fase 2, estas entidades operan con el catálogo base de `mock_data.dart`, utilizando sus identificadores para las salas de tiempo real y transacciones de escrow, bajo el rótulo honesto **«Trabajo DEMO · ofertas en vivo»**.

---

## 4. Hallazgos Críticos de Backend

1. **Rutas reales vs documentación de PR:** `PUT /api/v1/location/worker` y `GET /api/v1/location/nearby` (no `/my-location` ni `/workers/nearby`).
2. **Eventos WebSocket reales:** `sendBid`, `counterOffer`, `acceptBid` (entrada); `newBidReceived`, `counterOfferReceived`, `bidAccepted` (salida). No existen `job:status:update` ni `worker:location:stream`.
3. **Vulnerabilidad en `POST /api/v1/finance/deposit`:** Permite auto-acreditarse saldo arbitrario sin verificación bancaria. Bloqueado en UI.
4. **Vulnerabilidad en `POST /api/v1/finance/escrow/release`:** Recibe `workerUserId` y `amount` directamente del cliente; el cliente decide a quién pagar y cuánto en vez de derivarse de la oferta aceptada en el servidor.
5. **Endpoints públicos sin autenticación que exponen datos y cuotas:**
   - `GET /api/v1/location/nearby` es público y expone el email y teléfono personal de los técnicos.
   - `GET /api/v1/storage/upload-url` y `POST /api/v1/ai/diagnose` son completamente públicos sin rate-limiting ni auth, permitiendo a terceros consumir las cuotas de R2 y Gemini.
6. **Contraseñas y secretos hardcodeados:**
   - `JWT_SECRET` posee un valor por defecto escrito en 5 archivos del backend.
7. **Permisos y Seguridad de Red Android:**
   - `AndroidManifest.xml` carece de permisos de ubicación y red segura.

---

## Checklist de Implementación por Porciones (TDD)

- [x] **S0. Infraestructura Común:**
  * Tests unitarios de `ApiClient` (resolución de URLs, headers Bearer, errores tipados, intercepción 401).
  * Implementación de `ApiClient` y refactor de `AuthApiService`.
  * Configuración de `--dart-define=API_BASE_URL` y `--dart-define=USE_MOCKS`.
  * `AndroidManifest.xml` con permisos (`INTERNET`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`) y `network_security_config.xml`.
  * Verificación: `flutter analyze` (0 lints), `flutter test` (46/46 tests). Commit: `8404584` (`feat(s0): infraestructura comun con ApiClient, dart-defines y permisos de red`).

- [x] **S1. Técnicos Cercanos (Cliente):**
  * Tests unitarios y de widgets para `LocationApiService`, `ClientHomeScreen` y `WorkerProfileDetailScreen`.
  * `WorkerProfile.fromNearbyJson` con estricto cumplimiento de reglas de veracidad:
    - `baseRate: 0.0` activa "Tarifa a convenir" (nunca inventar S/ 40).
    - Sellos falsos de verificación (`isIdVerified`, `hasCleanRecord`, `offersWarranty`, `isVerified`) deshabilitados para técnicos reales.
    - `experienceYears` oculto para técnicos reales.
    - `reviews` y `portfolioCases` vacíos con mensaje "Aún sin reseñas" y "Aún sin casos comparativos".
    - `email` del técnico no se expone en UI.
  * `ChambaInteractiveMap` con pines para técnicos reales cercanos.
  * Selector de radio (5 km, 10 km, 15 km, 30 km) y toggle mapa/lista.
  * Verificación en emulador Android con Mobile MCP:
    - Ubicación fijada en Santa Victoria (`-6.7824, -79.8415`).
    - Ana García aparece a 1.1 km con "Tarifa a convenir", Electricidad, 4.9⭐.
    - Carlos Ramírez aparece a 11.9 km en Pimentel con Gasfitería, 4.8⭐.
    - Capturas de evidencia: `odd/evidence/frontend-integracion-fase4/s1_nearby_workers_list.png` y `s1_worker_detail.png`.
  * Verificación: `flutter analyze` (0 lints), `flutter test` (51/51 tests). Commit: `69218a1` (`feat(s1): tecnicos cercanos con postgis y mapa interactivo`).

- [ ] **S2. Ubicación del Técnico (Chambeador):**
  * Tests de `updateWorkerLocation` (`PUT /api/v1/location/worker`).
  * Disparo al abrir `WorkerShell` y al alternar disponibilidad en el switch de disponibilidad.
  * Verificación en emulador + commit `feat(s2): ...`.
- [ ] **S3. Billetera del Técnico:**
  * Tests de `WalletSummary` y parsing de Ledger.
  * Integración en `WorkerWalletScreen` con cálculo real de gráfico semanal a partir de `recentTransactions`. Sin botón de recarga.
  * Verificación de saldo del seed + commit `feat(s3): ...`.
- [ ] **S4. Diagnóstico con IA:**
  * Paquete `image_picker`.
  * Flujo R2 + Gemini con discriminación de `source` y mensaje «No se pudo subir la foto» ante fallos.
  * Verificación de ambos caminos + commit `feat(s4): ...`.
- [ ] **S5. Ofertas en Tiempo Real:**
  * Paquete `socket_io_client`.
  * Servicio `EventsSocketService` con reconexión y salas `jobRequestId`.
  * Simulación bidireccional cliente-técnico + commit `feat(s5): ...`.
- [ ] **S6. Escrow FinTech:**
  * Integración de `holdEscrow` y `releaseEscrow` con manejo de 400 y 409.
  * Verificación de ciclo completo con actualización de balances + commit `feat(s6): ...`.

---

## Progreso y Estado de Ejecución
- **Fase 1 (Diagnóstico):** ✅ Aprobado con correcciones.
- **Fase 2 (S0 - Infraestructura):** ✅ Completado (commit `8404584`).
- **Fase 2 (S1 - Técnicos Cercanos):** ✅ Completado (commit `69218a1`).
- **Siguiente paso:** Implementar S2 (Ubicación del Técnico: `PUT /location/worker` al abrir shell y al activarse disponible).
