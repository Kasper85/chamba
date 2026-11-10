# CHAMBA — Alcance del Flujo v2 (Cliente y Chambeador)

> Documento de referencia aprobado por el dueño del producto. Es la spec literal para ODD.
> Estado de avance: marcar `[x]` al cerrar cada tarea y registrar en la **Bitácora** al final.
> Todo pago es **simulado** (el ledger es la fuente de verdad). No hay pasarela real todavía.

---

## 0. Principios

1. **Una sola máquina de estados por chamba.** Cliente y chambeador ven vistas distintas del mismo estado.
2. **Cada pantalla tiene un rol.** Prohibido "Simular Técnico" y vistas mezcladas.
3. **Todo botón hace algo o no se muestra.** Cero `onTap: () {}`.
4. **Honestidad de datos.** Lo demo lleva etiqueta "DEMO". Nunca vender un respaldo como IA real, ni un dato fijo como verificado.
5. **Cambio de rol:** un único punto de cambio, el botón de **Perfil**. Se elimina la píldora (`RoleSwitcherPill`) de las cabeceras.

---

## 1. Máquina de estados de una chamba

```
BUSCANDO ─► NEGOCIANDO ─► ACEPTADA ─► EN_CAMINO ─► EN_SITIO ─► EN_EJECUCION ─► POR_CONFIRMAR ─► COMPLETADA
                              │                                                       │
                              │ (15 min sin depósito → oferta caduca)                 └─► EN_DISPUTA ─► COMPLETADA / REEMBOLSADA
                              └──────────────────────► CANCELADA (reglas en §4)
```

| Estado | Disparador | Quién actúa |
|---|---|---|
| BUSCANDO | Cliente publica | — |
| NEGOCIANDO | Llega la primera oferta | Chambeadores ofertan / cliente contraoferta |
| ACEPTADA | Cliente acepta una oferta; tiene **15 min** para depositar | Cliente deposita (escrow) |
| EN_CAMINO | Chambeador pulsa "Estoy en camino" (requiere depósito) | Chambeador |
| EN_SITIO | Chambeador llega | Cliente dicta PIN → chambeador lo valida |
| EN_EJECUCION | PIN validado + **foto del antes** subida | Chambeador |
| POR_CONFIRMAR | **Foto del después** subida | Cliente confirma o reclama (**24 h**) |
| COMPLETADA | Cliente confirma, o pasan 24 h sin respuesta/reclamo | Sistema libera fondos |
| EN_DISPUTA | Cliente reporta problema dentro de las 24 h | Soporte |
| CANCELADA / REEMBOLSADA | Ver §4 y §5 | — |

**SOS:** el cliente **elige entre ofertas** (no gana el más rápido). Ventana de ofertas de **5 min**; si no hay ninguna se amplía el radio.
**Expiraciones:** solicitud sin ofertas en 24 h → avisar al cliente y sugerir subir el precio.
**Privacidad:** el chambeador ve solo la **zona** hasta que el cliente deposita; la dirección exacta se revela tras el depósito.

---

## 2. Dinero (todo simulado vía ledger)

**Precio mínimo duro: S/ 20.** Sin tope duro. La IA "precio justo" es una **alerta suave**: si el precio es < 50% o > 300% del estimado, preguntar "¿Seguro?".

### Comisiones
| Concepto | Quién | Valor |
|---|---|---|
| Comisión | Chambeador, restada del precio | **8 %** |
| Tarifa de servicio | Cliente, sumada al precio | **S/ 2 fijos** |

Ejemplo, precio acordado S/ 100:
```
Cliente deposita:   S/ 102  (100 + 2)
Chambeador recibe:  S/  92  (100 − 8)
Plataforma:         S/  10  (8 + 2)
```
- El chambeador ve *"Ofertas S/ 100 → recibes S/ 92"* antes de enviar.
- El cliente ve *"S/ 100 + S/ 2 tarifa = S/ 102"* antes de depositar.
- Mismo porcentaje en SOS (el 1.35x ya sube el precio).

### Asientos del ledger
Existentes (`LedgerEntryType`): `DEPOSIT, HOLD_ESCROW, RELEASE_ESCROW, WITHDRAW, REFUND_ESCROW`.
Nuevos a agregar: `COMMISSION`, `SERVICE_FEE`, `COMPENSATION`.

Al liberar: `RELEASE_ESCROW` (→ chambeador, P − comisión) + `COMMISSION` + `SERVICE_FEE` (→ plataforma).
**Invariante (con test obligatorio):** `monto en custodia = liberación + comisión + tarifa`, siempre, y el saldo nunca queda negativo.

---

## 3. Confirmación del cliente (24 h)

1. Foto del después subida → estado **POR_CONFIRMAR**.
2. Al cliente le aparece una **pantalla obligatoria** "Confirma tu servicio" con slider antes/después y dos botones: **Todo bien, liberar pago** / **Reportar un problema**. Muestra cuenta regresiva de 24 h.
3. **Mientras exista una chamba POR_CONFIRMAR, el cliente no puede publicar otra** (se muestra el mismo cartel con el botón).
4. Recordatorios a las 2 h, 12 h y 24 h (notificación).
5. A las **24 h sin respuesta ni reclamo → liberación automática**.
6. Pasado el pago, el reclamo solo se abre vía soporte.

---

## 4. Cancelación (precio P, depositado P + S/ 2)

| Fase | Quién cancela | Cliente recibe | Chambeador | Notas |
|---|---|---|---|---|
| Antes de depositar (ofertas, o aceptada sin pagar) | Cualquiera | — | — | Sin movimiento de dinero |
| Depositado, técnico aún no sale | Cliente | Reembolso total | — | |
| Técnico EN_CAMINO | Cliente | Reembolso − compensación | **Compensación** (sin comisión) | Compensación = **10 % de P, mínimo S/ 5, máximo S/ 20** |
| Técnico no llega (>30 min de retraso) | Cliente | Reembolso total | Incidente de reputación | 3 incidentes en 30 días → suspensión temporal |
| Chambeador cancela tras el depósito | Chambeador | Reembolso total | Incidente de reputación | |
| PIN validado en adelante | — | Disputa (§5) | — | Solo con soporte |

La tarifa de servicio (S/ 2) se reembolsa en toda cancelación.

---

## 5. Disputas y soporte

1. Ventana de reclamo: dentro de las **24 h** de POR_CONFIRMAR.
2. Al abrir disputa los **fondos quedan congelados** (nadie cobra).
3. **Ambas partes declaran** (texto + evidencia: fotos, chat) con **24 h** cada una.
4. **Soporte** revisa con: fotos antes/después, PIN validado, ruta GPS y chat. Meta: 48 h.
5. Resultados: liberar todo al chambeador, reembolsar todo al cliente, o **dividir** (porcentaje).
6. Una sola apelación con evidencia nueva.
7. Abuso repetido → marca para revisión.
8. **Liquidación de la tarifa de servicio fija (S/ 2.00) en disputas (L13):** En la resolución de una disputa, la tarifa de servicio de S/ 2.00 se reembolsa al cliente **únicamente si el veredicto es reembolso total (`REFUND_CLIENT`)**. En caso de división (`SPLIT`) o resolución favorable al técnico (`RELEASE_WORKER`), la plataforma retiene los S/ 2.00 de tarifa fija en su tesorería.

**Soporte (por ahora, abstracto):** una persona que recibe un correo/ticket, lo analiza y da veredicto. Cada disputa crea un **ticket en backend** con enlace de revisión, y notifica a ambas partes. Quién es soporte queda abierto.
**IA:** *recomienda, no decide.* Resume declaraciones y evidencia y propone un veredicto con justificación; soporte aprueba con un clic. Con registro de auditoría. (Resolución automática solo de casos objetivos, en una fase posterior.)

---

## 6. Calificación, recibo, notificaciones

- **Calificación mutua** (cliente y chambeador se califican, 1–5 + comentario). Propina opcional del cliente, 100 % al chambeador.
- **Recibo** al completar: precio, comisión, tarifa, fotos, fecha.
- **Notificación por cada cambio de estado**, a ambos roles.

---

## 7. Pantallas y botones

### Cliente
| Pantalla | Debe tener | Botones → destino |
|---|---|---|
| Bienvenida | Propuesta de valor | Iniciar sesión · Crear cuenta |
| Login/Registro | Errores claros (backend caído, credenciales) | Entrar → Modo de uso |
| Modo de uso | Cliente / Especialista | Continuar → Shell |
| **Inicio** | Saludo, distrito, SOS, publicar, 8 categorías, **solicitudes activas (misma fuente que la pestaña)**, técnicos cercanos reales (demo etiquetados) | SOS/Publicar/Categoría → PostJob · tarjeta → según estado |
| Publicar | Título, descripción, fotos, categoría, presupuesto (mín. S/ 20), dirección, urgencia, ayuda IA | Publicar → BUSCANDO |
| Mis solicitudes | Filtros Buscando/Negociando/En curso/Finalizadas | Tarjeta → detalle según estado |
| Ofertas recibidas | Precio, ETA, reputación, verificación; contraoferta en vivo | Aceptar · Contraofertar · Chatear · Ver perfil |
| Depósito en garantía | Desglose P + S/ 2, método, cuenta regresiva de 15 min | Depositar → ACEPTADA |
| Seguimiento | Mapa, tarjeta del técnico, **PIN visible**, línea de tiempo | Llamar · Chat · Cancelar (con reglas) |
| Confirmar servicio | Slider antes/después, cuenta regresiva 24 h | Liberar · Reportar problema |
| Calificación + recibo | Estrellas, comentario, propina | Enviar → Inicio |
| Mensajes | Una conversación por chamba; estado de la chamba arriba | Abrir chat |
| Perfil | Métricas reales (solicitudes publicadas, servicios contratados, rating recibido) | Notificaciones · Direcciones (CRUD, una por defecto) · Métodos de pago · Verificación DNI · Soporte (WhatsApp/correo) · **Cambiar a modo Chambeador** · Cerrar sesión |

### Chambeador
| Pantalla | Debe tener | Botones → destino |
|---|---|---|
| Chambas disponibles | Switch de disponibilidad **persistente**, filtros (SOS, categoría, distancia), SOS fijadas arriba | Tarjeta → detalle · Cabecita → **pestaña Mi Perfil** |
| Detalle y propuesta | Descripción, fotos, solo zona; precio con sugerencia IA, nota de voz 15 s, qué incluye, ETA, mensaje; **"recibes S/ X"** | Enviar propuesta → Mis trabajos |
| Mis trabajos | Negociando · Activos · Historial | Tarjeta → según estado |
| Trabajo activo | Línea de tiempo con fases | Ver tabla abajo |
| Mensajes | Igual que cliente | |
| Mi perfil | Escudo de confianza **real**, portafolio, billetera (saldo, custodia, comisión descontada, retiro), servicios, notificaciones, soporte | Cambiar a modo Cliente · Cerrar sesión |

| Fase del trabajo activo | Qué ve el chambeador | Botón |
|---|---|---|
| ACEPTADA | "Esperando depósito del cliente" | — |
| Depositado | Ruta en vivo, dirección exacta | "Estoy en camino" |
| EN_SITIO | Campo PIN de 4 dígitos | Validar PIN |
| EN_EJECUCION | "Sube la foto del antes" | Subir foto |
| Finalizando | "Sube la foto del después" | Marcar terminado → POR_CONFIRMAR |
| COMPLETADA | Pago liberado a billetera | Ver ganancias |

---

## 8. Fases / Loops de implementación

Cada loop (L1 en adelante): implementar con TDD → correr **solo los tests del propio loop** (`flutter test <archivo>` / vitest del módulo) → **registrar en ODD** (ver abajo) → marcar `[x]` aquí → pasar al siguiente loop sin esperar (el commit lo decide el humano).
**NO compilar la app, NO levantar el emulador y NO usar Mobile MCP al cerrar cada loop** (es lo que más tiempo consume). La verificación completa (analyze, suite completa, compilación y Mobile MCP) se hace **una sola vez, en L11**.

**Registro ODD obligatorio (por tarea):** en `odd/tasks/flujo-v2-registro.md`, una entrada por cada tarea de cada loop, con este formato:
```
### L<n> · Tarea <n.m> — <título corto>
- Qué: qué se cambió (archivos clave)
- Por qué: el problema o la regla de ALCANCE.md que lo exige
- Para qué: qué consigue el usuario o el sistema con esto
- Pruebas: tests agregados/corridos y su resultado
- Decisiones: lo que se decidió sin consultar (o "ninguna")
```
La Bitácora de este archivo (§10) guarda solo una línea por loop: fecha · loop · tareas cerradas · tests del loop.

### L0 — Estabilidad y limpieza
- [x] Corregir el bucle de `pushReplacement` en `ClientShell`/`WorkerShell` al cambiar de rol (un solo gate de rol que decida el shell; sin navegación dentro de los shells).
- [x] Eliminar `RoleSwitcherPill` de todas las cabeceras; dejar solo el botón de Perfil.
- [x] Inicio del cliente usa la misma fuente que "Solicitudes" (`clientJobs`); quitar parches `client-1` y `worker-1` de `app_state.dart`.
- [x] Cabecita del chambeador → pestaña "Mi Perfil" del `WorkerShell`.
- [x] Eliminar `BottomNavigationBar` duplicada (`showBottomNav`) en `ClientHomeScreen` y `AvailableJobsScreen`.
- [x] Quitar "Elegir Modo de Uso" del perfil del cliente (ya existe el botón de cambiar de modo).
- **Verifica (Mobile MCP):** cambiar de rol 10 veces seguidas sin crash; conteo de solicitudes igual en Inicio y Solicitudes.

### L1 — Modelo y máquina de estados
- [x] Enum de estados de §1 en modelo Flutter y backend; transiciones válidas en un solo lugar; tests de transiciones válidas e inválidas.

### L2 — Persistencia backend de chambas *(requiere confirmación: antes estaba fuera de alcance)*
- [x] Modelos Prisma: `JobRequest`, `Bid`, `Dispute`, `Rating`, `SupportTicket`; migración; endpoints REST + eventos.
- [x] El frontend deja de depender de mocks para estas entidades cuando `USE_MOCKS=false`.

### L3 — Escrow, comisión y ledger
- [x] Nuevos `LedgerEntryType`: `COMMISSION`, `SERVICE_FEE`, `COMPENSATION`.
- [x] Depósito (P + S/ 2) con plazo de 15 min; liberación con comisión 8 % y tarifa; reembolsos.
- [x] Pantallas de desglose para cliente y chambeador ("recibes S/ X").
- [x] Test del invariante del ledger y de saldo nunca negativo. Sigue prohibido un botón de recarga directa (`POST /finance/deposit`).

### L4 — Seguimiento por rol
- [x] Separar `JobTrackingScreen` en vista cliente y vista chambeador; eliminar "Simular Técnico".
- [x] Fases del chambeador según §7 (en camino, PIN, foto antes, foto después).

### L5 — Confirmación 24 h
- [x] Pantalla obligatoria de confirmación, cuenta regresiva, recordatorios, liberación automática a las 24 h, bloqueo de nuevas publicaciones.

### L6 — Cancelación
- [x] Reglas de §4, compensación 10 % (mín. S/ 5, máx. S/ 20), incidentes de reputación, suspensión a los 3 incidentes.

### L7 — Disputas y soporte
- [x] Flujo de §5, congelamiento de fondos, tickets, notificación a ambas partes, resolución (liberar/reembolsar/dividir), una apelación.
- [x] IA que **recomienda** veredicto (nunca ejecuta sola); registro de auditoría.

### L8 — Calificación, recibo y notificaciones
- [x] Calificación mutua + propina, recibo, notificación por cada cambio de estado.

### L9 — Perfiles y datos reales
- [x] Métricas de cliente calculadas; botones muertos (direcciones, pagos, DNI, soporte) con pantalla real.
- [x] Perfil del chambeador sin datos fijos (DNI, tarifa, verificaciones); la verificación de identidad sigue **etiquetada "DEMO"** hasta tener proveedor.
- [x] Switch de disponibilidad persistente en backend.

### L10 — Precio mínimo y alerta de IA
- [x] Mínimo duro S/ 20 en publicar y en ofertas; alerta suave si el precio es < 50 % o > 300 % del estimado por la IA.

---

### L11 — Revisión general final (única verificación completa)
- [x] `flutter analyze` sin errores y `flutter test` (suite completa) en verde; tests del backend en verde.
- [x] Compilar y ejecutar la app **una vez** en el emulador (`Medium_Phone`) con el backend encendido.
- [x] Recorrer con Mobile MCP, guardando capturas en `odd/evidence/l11/`:
  - Cambiar de rol 10 veces sin crash; conteo de solicitudes igual en Inicio y Solicitudes.
  - Cliente: publicar (mín. S/ 20) → recibir y contraofertar → aceptar → depositar (S/ P + 2) → seguimiento con PIN → confirmar → calificar → recibo.
  - Chambeador: ofertar ("recibes S/ X") → trabajo activo (en camino, PIN, foto antes, foto después) → cobro en billetera con comisión del 8 %.
  - Cancelación con técnico en camino (compensación 10 %, mín. S/ 5, máx. S/ 20) y reembolso total antes de salir.
  - Confirmación 24 h: cartel obligatorio, bloqueo de nueva publicación, liberación automática.
  - Disputa: congelamiento de fondos, declaraciones de ambas partes, ticket de soporte, resolución.
  - Botones del perfil de ambos roles sin ninguno muerto.
- [x] Revisar el invariante del ledger (`custodia = liberación + comisión + tarifa`) con datos reales del flujo.
- [x] Reporte final: loops cerrados, resultados, lo que NO se pudo verificar y todas las decisiones tomadas.

### L12 — Seguridad de disputas, auto-liberación 24 h y recorrido completo
- [x] Seguridad en disputas: rol de soporte/admin obligatorio en `POST /disputes/:id/resolve` y `POST /disputes/:id/recommendation`; prohibición estricta de auto-resolución (403 para partes involucradas); auditoría de otros endpoints financieros.
- [x] Auto-liberación periódica a las 24 h: tarea programada `@Cron` con `@nestjs/schedule` (libera con comisión, ignora `EN_DISPUTA`, idempotente sin doble cobro, notifica a ambas partes).
- [x] Recorrido final con Mobile MCP en emulador (`odd/evidence/l12/`) cubriendo los 3 flujos clave (feliz, cancelación con compensación, disputa con resolución de soporte) e inspección real de billeteras y ledger.
- [x] Reporte final distinguiendo claramente lo verificado en emulador, verificado solo con tests, y no verificado.

### L13 — Integridad contable, datos dinámicos y resolución de disputas por soporte
- [x] Eliminación de mocks y montos fijos en `DisputeDetailScreen`: montos, veredicto, operador y fórmula de invariante calculados y provistos dinámicamente desde el backend y el libro mayor inmutable.
- [x] Control de acceso en UI para resolución de disputas: el botón "Resolver Disputa (Operador de Soporte)" solo es visible para usuarios con rol `SUPPORT` o `ADMIN`; clientes y técnicos no ven el botón (`loop_l13_dispute_resolution_test.dart` en verde).
- [x] Auditoría integral de pantallas para eliminar textos monetarios escritos a mano en escrow, cancelación, confirmación y recibo.
- [x] Endpoint de auditoría financiera (`GET /api/v1/finance/audit/jobs/:jobId`) y ejecución de los 3 recorridos (feliz, cancelación con técnico en camino, disputa completa resuelta por soporte) con saldos reales capturados en `odd/evidence/l13/`.
- [x] Recorrido de disputa de punta a punta con bloqueo 403 para clientes, recomendación de IA y resolución oficial por operador de soporte humano (`soporte@chamba.pe`).
- [x] Nueva regla de negocio §5: reembolso de tarifa de servicio (S/ 2.00) solo en veredicto `REFUND_CLIENT`; en `SPLIT` y `RELEASE_WORKER` retenida en tesorería de la plataforma.
- [x] Reconciliación exacta de conteo de tests: 105 tests Flutter (100% verde) + 100 tests backend Vitest (100% verde) = 205 tests totales.

### L14 — Control de acceso y privacidad en endpoints de lectura y auditoría de recursos
- [x] Autorización y scoping de privacidad en auditoría contable (`GET /finance/audit/jobs/:jobId`): acceso restringido exclusivamente al cliente, al técnico asignado o a operadores con rol `SUPPORT`/`ADMIN`. Terceros reciben 403 Forbidden. Scoping de privacidad: cliente solo ve su saldo; técnico solo ve su saldo; la tesorería de la plataforma y el saldo total ajeno solo son visibles para soporte.
- [x] Privacidad y ofuscación de correos en disputas (`GET /disputes/jobs/:jobId` y `GET /disputes/:id`): validación de usuario llamante con bloqueo 403 a usuarios no involucrados. Los correos electrónicos se omiten para el cliente y el técnico (mostrando únicamente nombre completo); visibilidad de correo reservada para auditoría de `SUPPORT`/`ADMIN`.
- [x] Auditoría exhaustiva de endpoints con identificadores de recurso (`jobs`, `bids`, `ratings`, `disputes`, `finance`, `worker-profile`, `EventsGateway` de Socket.IO): tabla completa generada en `odd/tasks/flujo-v2-registro.md`.
- [x] Correcciones de seguridad aplicadas en endpoints con ID:
  - `GET /jobs/:id`: PIN de seguridad solo expuesto al cliente y soporte. Dirección exacta y teléfono del cliente solo expuestos al técnico asignado tras el depósito de garantía en custodia (estado post-ACEPTADA); antes solo ve distrito. Email del cliente nunca expuesto a terceros.
  - `POST /jobs/:id/bids`: bloqueo 403 Forbidden si el cliente intenta postular a su propia solicitud.
  - `POST /jobs/:id/bids/:bidId/counter`: validación de pertenencia (solo cliente o técnico dueño de la oferta; 403 a extraños).
  - `GET /jobs/:id/receipt`: 403 a terceros. Desglose disjunto: cliente ve su total pagado y tarifa de servicio (ocultando comisión y neto de técnico); técnico ve su liquidación neta y comisión (ocultando tarifa fija y total pagado por cliente); soporte ve ambos.
  - `POST /disputes/:id/appeal`: 403 a usuarios ajenos a la disputa.
  - `Socket.IO EventsGateway`: validación de usuario al unirse a salas `job:{id}` (en búsqueda solo entran cliente, técnicos registrados o soporte; en ejecución solo cliente, técnico asignado y soporte) y al contraofertar/aceptar propuestas.
- [x] Documentación de seguridad sobre credenciales de desarrollo: nota explícita en el registro ODD indicando que `soporte@chamba.pe` y contraseñas por defecto son exclusivas para pruebas locales y no deben existir en producción.
- [x] Verificación de suite de pruebas TDD e integración real: 124 tests backend Vitest (14 suites, 100% verde), 108 tests Flutter (100% verde) y 21 comprobaciones automatizadas de integración real registradas en `odd/evidence/l14/authorization_and_privacy_audit.json`.

---

## 9. Fuera de alcance (por ahora)
- Pasarela de pago real (Culqi/Niubiz/Mercado Pago) y movimiento real de dinero.
- Verificación de identidad real (RENIEC).
- Panel web de soporte (por ahora es un ticket/correo).
- Resolución automática de disputas por IA.

## 10. Bitácora
<!-- Antigravity: agregar una línea por loop cerrado: fecha · loop · resultado de tests · evidencia -->
- 2026-11-09 · L0 (Estabilidad y limpieza) · flutter analyze limpio (0 issues), flutter test 58 passed · odd/evidence/l0/ (01_client_home.png a 05_worker_after_10_switches.png)
- 2026-11-09 · L1 (Modelo y máquina de estados) · flutter analyze limpio (0 issues), flutter test 62 passed, npm test 36 passed · odd/evidence/l1/ (01_requests_screen_states.png, 02_worker_jobs_screen_states.png)
- 2026-11-09 · L2 (Persistencia backend de chambas) · flutter analyze limpio (0 issues), flutter test 69 passed, npm test 47 passed · odd/evidence/l2/ (01_client_job_created.png, 02_worker_available_jobs.png)
- 2026-11-09 · L3 (Escrow, comisión y ledger) · flutter analyze limpio (0 issues), flutter test 72 passed, npm test 51 passed · odd/evidence/l3/ (01_worker_bid_breakdown.png, 02_client_escrow_deposit_breakdown.png, 03_wallet_ledger_entries.png)
- 2026-11-09 · L4 (Seguimiento por rol) · flutter test loop_l4_tracking_test (4 passed), vitest jobs.service (18 passed) · odd/evidence/l4/ (01_client_job_tracking_pin.png, 02_worker_on_the_way.png)
- 2026-11-09 · L5 (Confirmación 24 h) · flutter test loop_l5_confirmation_test (3 passed), vitest jobs.service (20 passed) · odd/tasks/flujo-v2-registro.md
- 2026-11-09 · L6 (Cancelación) · flutter test loop_l6_cancellation_test (5 passed), vitest jobs.service (25 passed) · odd/tasks/flujo-v2-registro.md
- 2026-11-09 · L7 (Disputas y soporte) · flutter test loop_l7_disputes_test (3 passed), vitest disputes.service (7 passed) · odd/tasks/flujo-v2-registro.md
- 2026-11-09 · L8 (Calificación, recibo y notificaciones) · flutter test loop_l8_rating_test (3 passed), vitest jobs.service (29 passed) · odd/tasks/flujo-v2-registro.md
- 2026-11-09 · L9 (Perfiles y datos reales) · flutter test loop_l9_profiles_test (6 passed), vitest worker-profile.service (1 passed) · odd/tasks/flujo-v2-registro.md
- 2026-11-09 · L10 (Precio mínimo y alerta de IA) · flutter test loop_l10_price_limits_test (5 passed), vitest jobs.service (31 passed) · odd/tasks/flujo-v2-registro.md
- 2026-11-09 · L11 (Revisión general final) · flutter analyze limpio (0 issues), flutter test 101 passed, vitest 83 passed · odd/evidence/l11/ (01_initial_screen.png a 11_client_job_bids_waiting.png)
- 2026-11-10 · L12 (Seguridad disputas, cron 24h y recorrido completo) · flutter analyze limpio (0 issues), vitest auth/disputes/jobs (43 passed), 17 capturas Mobile MCP · odd/evidence/l12/ (01_client_publishing_job.png a 17_dispute_resolved_by_support.png)
- 2026-11-10 · L13 (Integridad contable, datos dinámicos y soporte) · flutter analyze limpio (0 issues), flutter test 105 passed, vitest 100 passed (205 tests totales) · odd/evidence/l13/ (flow1_happy_path_audit.json, flow2_cancellation_audit.json, flow3_dispute_resolution_audit.json)
- 2026-11-10 · L14 (Control de acceso y privacidad en endpoints y auditoría) · flutter test 108 passed, vitest 124 passed (232 tests totales), 21 pruebas de auditoría real en verde · odd/evidence/l14/authorization_and_privacy_audit.json
