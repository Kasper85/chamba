<p align="center">
  <img src="../assets/images/chamba.png" alt="CHAMBA Logo" width="100" style="border-radius: 16px;" />
</p>

<h1 align="center">CHAMBA Backend — NestJS API & Microservicios 🇵🇪</h1>

<p align="center">
  <strong>Servicios backend de alta concurrencia para CHAMBA Perú: Geolocalización PostGIS, FinTech con Libro Mayor inmutable y Custodia Escrow, WebSockets con Socket.IO, Cloudflare R2 y Diagnóstico Multimodal con Google Gemini 2.5 Flash.</strong>
</p>

<p align="center">
  <a href="https://nestjs.com"><img src="https://img.shields.io/badge/NestJS-12-E0234E?logo=nestjs&logoColor=white" alt="NestJS"></a>
  <a href="https://www.postgresql.org"><img src="https://img.shields.io/badge/PostgreSQL-PostGIS-336791?logo=postgresql&logoColor=white" alt="PostgreSQL"></a>
  <a href="https://redis.io"><img src="https://img.shields.io/badge/Redis-7%2B-DC382D?logo=redis&logoColor=white" alt="Redis"></a>
  <a href="https://socket.io"><img src="https://img.shields.io/badge/Socket.IO-v4.8-010101?logo=socketdotio&logoColor=white" alt="Socket.IO"></a>
  <a href="https://aistudio.google.com"><img src="https://img.shields.io/badge/AI-Gemini%202.5%20Flash-8E75C2?logo=google&logoColor=white" alt="Gemini"></a>
  <a href="https://www.cloudflare.com/products/r2/"><img src="https://img.shields.io/badge/Storage-Cloudflare%20R2-F38020?logo=cloudflare&logoColor=white" alt="R2"></a>
</p>

---

## 📌 Arquitectura Modular

El backend se organiza en módulos de dominio desacoplados bajo `src/`:

```text
src/
├── auth/                 # Registro, login, guards JWT, hashing bcrypt y decoradores
├── location/             # Búsqueda espacial de técnicos con PostGIS y actualización de posición
├── finance/              # FinTech: Billetera, Libro Mayor (Ledger) inmutable y custodia Escrow
├── events/               # Gateway WebSockets con Socket.IO y adaptador Redis Pub/Sub
├── storage/              # URLs prefirmadas y subida directa a Cloudflare R2 (AWS SDK v3)
├── ai/                   # Diagnóstico multimodal con Google Gemini 2.5 Flash y fallback
├── redis/                # Módulo global de conexión y utilidades Redis
└── prisma/               # Servicio de base de datos con Prisma ORM
```

---

## 🚀 Inicio y Configuración Rápida

### 1. Variables de Entorno
Copia la plantilla y configura tus credenciales locales:
```bash
cp .env.example .env
```

Variables clave en `.env`:
* `DATABASE_URL`: `postgresql://chamba_app:tu_password@localhost:5432/chamba_db?schema=public`
* `REDIS_HOST` y `REDIS_PORT`: Conexión al servidor Redis (por defecto `localhost:6379`).
* `JWT_SECRET`: Llave criptográfica para firmas de tokens de sesión.
* `GEMINI_API_KEY`: API Key de Google AI Studio para diagnóstico de averías.
* `R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET_NAME`: Credenciales Cloudflare R2.

### 2. Migraciones de Base de Datos
Asegúrate de haber habilitado PostGIS en PostgreSQL (`CREATE EXTENSION IF NOT EXISTS postgis;` en `chamba_db`), luego ejecuta:
```bash
npx prisma migrate deploy
npx prisma db seed
```

### 3. Ejecutar el Servidor
```bash
# Modo desarrollo con auto-reload (watch)
npm run start:dev

# Modo producción
npm run build
npm run start:prod
```

* **API REST:** `http://localhost:3000/api/v1`
* **Swagger Docs:** `http://localhost:3000/api/docs`

---

## 🛠️ Endpoints Principales

| Módulo | Método / Ruta | Descripción | Auth |
|---|---|---|---|
| **Auth** | `POST /api/v1/auth/register` | Registro de nuevo usuario (Cliente / Técnico) | Pública |
| **Auth** | `POST /api/v1/auth/login` | Login con credenciales, emite JWT Bearer | Pública |
| **Auth** | `GET /api/v1/auth/me` | Obtener perfil y datos de sesión activa | JWT |
| **Location** | `GET /api/v1/location/nearby` | Búsqueda geoespacial PostGIS por radio (`lat`, `lng`, `radiusKm`) | Pública |
| **Location** | `PUT /api/v1/location/worker` | Actualizar coordenadas del técnico autenticado | JWT (Técnico) |
| **Finance** | `GET /api/v1/finance/wallet` | Consulta de saldo disponible, en custodia y Libro Mayor | JWT |
| **Finance** | `POST /api/v1/finance/escrow/hold` | Retener fondos en custodia al aceptar oferta | JWT (Cliente) |
| **Finance** | `POST /api/v1/finance/escrow/release` | Liberar fondos de custodia al culminar el trabajo | JWT (Cliente) |
| **Storage** | `GET /api/v1/storage/upload-url` | Generar URL prefirmada para subida a Cloudflare R2 | Pública |
| **AI** | `POST /api/v1/ai/diagnose` | Diagnóstico técnico asistido por Gemini con imagen | Pública |

---

## ⚡ Eventos en Tiempo Real (Socket.IO Gateway)

* **Namespace:** `'/'` (Puerto 3000)
* **Autenticación:** Token JWT en handshake (`auth: { token: '...' }`).

### Eventos Emitidos por Clientes:
* `joinJobRoom`: `{ jobRequestId: string }` — Unirse a la sala de una solicitud.
* `leaveJobRoom`: `{ jobRequestId: string }` — Salir de la sala.
* `sendBid`: `{ jobRequestId, amount, message, ... }` — Técnico envía propuesta económica.
* `counterOffer`: `{ jobRequestId, counterAmount, note }` — Contraoferta de precio.
* `acceptBid`: `{ jobRequestId, bidId, agreedAmount }` — Cierre y aceptación de oferta.

### Eventos Transmitidos (Broadcast):
* `newBidReceived`: Oferta transmitida a todos los conectados a la sala `job:{jobRequestId}`.
* `counterOfferReceived`: Contraoferta emitida a la sala.
* `bidAccepted`: Confirmación de trato cerrado emitida a ambas partes.

---

## 🧪 Pruebas Automatizadas

```bash
# Pruebas unitarias
npm run test

# Pruebas de integración E2E
npm run test:e2e

# Cobertura de pruebas
npm run test:cov
```
