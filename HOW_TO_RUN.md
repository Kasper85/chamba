# Guía Completa de Instalación y Ejecución — CHAMBA Perú 🇵🇪

Esta guía describe paso a paso cómo cualquier integrante del equipo de desarrollo puede clonar el repositorio de **CHAMBA** en **Windows**, configurar PostgreSQL, compilar y ejecutar el backend NestJS con Prisma ORM, y correr el frontend Flutter en el emulador Android o en un celular físico sin depender de la máquina del desarrollador principal.

---

## 📌 Tabla de Contenidos

1. [Herramientas y Requisitos Previos](#1-herramientas-y-requisitos-previos)
2. [Clonado del Repositorio y Apertura del Proyecto](#2-clonado-del-repositorio-y-apertura-del-proyecto)
3. [Instalación y Configuración de PostgreSQL](#3-instalación-y-configuración-de-postgresql)
4. [Configuración de Variables de Entorno (`.env`)](#4-configuración-de-variables-de-entorno-env)
5. [Configuración y Puesta a Punto del Backend (NestJS + Prisma)](#5-configuración-y-puesta-a-punto-del-backend-nestjs--prisma)
6. [Configuración y Ejecución del Frontend (Emulador y Celular Físico)](#6-configuración-y-ejecución-del-frontend-flutter)
7. [Direcciones de Red y Endpoints Clave](#7-direcciones-de-red-y-endpoints-clave)
8. [Pruebas de la API REST con Swagger y Postman](#8-pruebas-de-la-api-rest-con-swagger-y-postman)
9. [Ejecución de Pruebas Automatizadas y Calidad](#9-ejecución-de-pruebas-automatizadas-y-calidad)
10. [Compilación e Instalación de APK para Pruebas](#10-compilación-e-instalación-de-apk-para-pruebas)
11. [Compatibilidad y Responsive en Dispositivos Android](#11-compatibilidad-y-responsive-en-dispositivos-android)
12. [Solución de Errores Frecuentes (Troubleshooting)](#12-solución-de-errores-frecuentes-troubleshooting)

---

## 1. Herramientas y Requisitos Previos

Antes de comenzar, valida que tu computadora con **Windows 10 u 11** cuente con las siguientes herramientas instaladas:

| Herramienta | Versión Recomendada | Comando de Verificación |
|---|---|---|
| **Git** | v2.30+ | `git --version` |
| **Node.js** | v20.x o v24.x LTS | `node -v` |
| **npm** | v10.x+ | `npm -v` |
| **PostgreSQL** | v15, v16 o v18 | `psql --version` |
| **Flutter SDK** | v3.24+ (Dart 3.5+) | `flutter --version` y `flutter doctor` |
| **Android Studio** | Hedgehog o superior | SDK Android y emulador configurado |
| **Editor de Código** | Antigravity IDE o VS Code | Extensiones: Flutter, Dart, Prisma |

> 💡 **Tip Flutter Doctor:** Ejecuta `flutter doctor` en tu terminal de PowerShell. Asegúrate de tener los checks verdes en **Android toolchain**, **Flutter SDK** y **Android Studio**.

---

## 2. Clonado del Repositorio y Apertura del Proyecto

### 2.1 Clonar el repositorio
Abre una terminal de PowerShell en la carpeta donde guardas tus proyectos:
```powershell
git clone https://github.com/Kasper85/chamba.git
cd chamba
```

### 2.2 Abrir con tu editor preferido
- **Antigravity IDE:** Selecciona la carpeta raíz `chamba`.
- **Visual Studio Code:**
  ```powershell
  code .
  ```
  *Extensiones recomendadas:* `Dart-Code.flutter`, `Dart-Code.dart-code`, `Prisma.prisma`.

---

## 3. Instalación y Configuración de PostgreSQL

CHAMBA utiliza **PostgreSQL** para la persistencia del backend. Recomendamos crear una base de datos exclusiva (`chamba_db`) y un usuario de aplicación dedicado (`chamba_app`) siguiendo las mejores prácticas de seguridad.

### 3.1 Abrir la consola interactiva `psql`
Ejecuta en tu terminal PowerShell (o usa la aplicación *SQL Shell (psql)* incluida con PostgreSQL):
```powershell
psql -U postgres -h localhost -p 5432
```
*(Ingresa la contraseña maestra que definiste al instalar PostgreSQL).*

### 3.2 Crear la base de datos y el usuario dedicado
Ejecuta las siguientes instrucciones SQL una por una:

```sql
-- 1. Crear la base de datos exclusiva del proyecto
CREATE DATABASE chamba_db;

-- 2. Conectarse a la nueva base de datos
\c chamba_db;

-- 3. Crear el usuario de aplicación dedicado (reemplaza 'MiPasswordSeguro123!' por tu contraseña local)
CREATE ROLE chamba_app WITH LOGIN PASSWORD 'MiPasswordSeguro123!';

-- 4. Otorgar permisos sobre la base de datos y el esquema público
GRANT CONNECT ON DATABASE chamba_db TO chamba_app;
GRANT USAGE, CREATE ON SCHEMA public TO chamba_app;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO chamba_app;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO chamba_app;

-- 5. Asegurar permisos automáticos para futuras tablas creadas por Prisma
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO chamba_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO chamba_app;

-- 6. Salir de psql
\q
```

---

## 4. Configuración de Variables de Entorno (`.env`)

Por estrictas normas de seguridad, los archivos `.env` que contienen contraseñas **nunca se suben a Git** (están bloqueados por `.gitignore`).

### 4.1 Crear el archivo `backend/.env`
Copia la plantilla `.env.example` en la carpeta `backend/`:
```powershell
# En Windows (PowerShell):
Copy-Item .env.example backend\.env
```

### 4.2 Configurar credenciales en `backend/.env`
Abre `backend/.env` con tu editor y ajusta los valores:
```env
# Configuración del Servidor Backend (NestJS)
PORT=3000
NODE_ENV=development

# Conexión PostgreSQL con el usuario dedicado chamba_app
DATABASE_URL="postgresql://chamba_app:MiPasswordSeguro123!@localhost:5432/chamba_db?schema=public"

# Clave secreta para firma criptográfica de tokens JWT
# Genera una clave aleatoria ejecutando en PowerShell: node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"
JWT_SECRET="genera_tu_clave_aleatoria_aqui"
JWT_EXPIRES_IN="7d"

# URLs base de referencia
# Web / Postman: http://localhost:3000
# Emulador Android: http://10.0.2.2:3000
```

> ⚠️ **Importante:** Nunca compartas tu contraseña ni publiques tu archivo `.env` en repositorios públicos.

---

## 5. Configuración y Puesta a Punto del Backend (NestJS + Prisma)

### 5.1 Instalar dependencias de Node.js
Entra en la carpeta `backend/` e instala los paquetes:
```powershell
cd backend
npm install
```

### 5.2 Validar el esquema de base de datos
Comprueba que el archivo `prisma/schema.prisma` sea sintácticamente correcto:
```powershell
npx prisma validate
```

### 5.3 Aplicar las migraciones versionadas
Aplica las migraciones en tu base de datos local para crear las tablas `users` y `worker_profiles`:
```powershell
# En desarrollo colaborativo (aplica el historial existente sin generar discrepancias):
npx prisma migrate deploy
```

*(Si eres quien está agregando una nueva columna o modelo, consulta [CONTRIBUTING.md](CONTRIBUTING.md) para el uso de `npx prisma migrate dev`).*

### 5.4 Generar el cliente de Prisma
Genera los tipos de TypeScript actualizados para interactuar con la base de datos:
```powershell
npx prisma generate
```

### 5.5 Insertar datos de prueba iniciales (Seed)
Ejecuta el script de semilla para poblar tu base de datos con cuentas demo:
```powershell
npx prisma db seed
```

**Cuentas creadas por el seed:**
| Nombre | Correo Electrónico | Rol Principal | Contraseña de Prueba |
|---|---|---|---|
| **Ana García** | `ana@chamba.pe` | Cliente y Trabajadora (Electricidad) | `Password123!` |
| **José Torres** | `jose@chamba.pe` | Cliente | `Password123!` |
| **Carlos Ramírez** | `carlos@chamba.pe` | Cliente y Trabajador (Gasfitería) | `Password123!` |

### 5.6 Iniciar el servidor backend en modo desarrollo
```powershell
npm run start:dev
```
Verás en consola:
```text
🚀 CHAMBA Backend ejecutándose en: http://localhost:3000/api/v1
📚 Documentación Swagger disponible en: http://localhost:3000/api/docs
```
*(Deja esta terminal abierta ejecutando el backend).*

---

## 6. Configuración y Ejecución del Frontend (Flutter)

Abre una **segunda terminal** en la raíz del repositorio (`chamba/`).

### 6.1 Instalar dependencias de Flutter
```powershell
flutter pub get
```

### 6.2 Iniciar el Emulador Android
Comprueba tus emuladores disponibles y enciende el de tu preferencia:
```powershell
# Listar emuladores
flutter emulators

# Iniciar emulador (por ejemplo, Medium_Phone)
flutter emulators --launch Medium_Phone
```
Espera unos segundos hasta que el emulador Android termine de encender en tu pantalla.

### 6.3 Ejecutar la aplicación en el emulador
```powershell
flutter run
```
*Atajos útiles durante la ejecución:*
- Presiona `r` para **Hot Reload** (cambios instantáneos de interfaz).
- Presiona `R` para **Hot Restart** (reinicio de estado).
- Presiona `q` para detener la app.

### 6.4 Despliegue e Instalación en Celular Android Físico (Cable USB)

Si deseas probar la experiencia táctil real, el rendimiento y las animaciones en un smartphone Android conectado a tu PC por cable USB:

#### Paso 1: Habilitar las Opciones de Desarrollador en el celular
1. Abre **Ajustes** (Configuración) en tu teléfono.
2. Ve a **Acerca del teléfono** o **Información del software**.
3. Busca el campo **Número de compilación** (en Xiaomi/Redmi/Poco pulsa sobre *Versión de MIUI / HyperOS*).
4. Toca repetidamente **7 veces** seguidas sobre ese texto hasta que aparezca el mensaje en pantalla: *"¡Ya eres desarrollador!"*.

#### Paso 2: Activar la Depuración por USB
1. Regresa a **Ajustes** y entra en **Sistema** ➔ **Opciones para desarrolladores** (o *Ajustes adicionales* ➔ *Opciones de desarrollador*).
2. Activa el interruptor **Depuración por USB** (*USB Debugging*).
3. *(Opcional para marcas como Xiaomi/Redmi)*: Activa también **Instalar vía USB** y **Depuración USB (ajustes de seguridad)**.

#### Paso 3: Conectar el teléfono a la PC y autorizar la conexión
1. Conecta tu celular a un puerto USB de la computadora usando un **cable de datos** de buena calidad (evita cables que solo cargan batería).
2. En la pantalla del celular aparecerá un cuadro de diálogo: *"¿Permitir depuración por USB?"*.
3. Marca la casilla **"Permitir siempre desde esta computadora"** y pulsa **Permitir** o **Aceptar**.

#### Paso 4: Reconocer el dispositivo con Flutter
En tu terminal de PowerShell en la raíz del proyecto, ejecuta:
```powershell
flutter devices
```
Verás la lista de dispositivos conectados con su identificador único (`device_id`). Por ejemplo:
```text
2 connected devices:

Redmi Note 12 (mobile) • 19283746a5b6 • android-arm64 • Android 14 (API 34)
Windows (desktop)      • windows      • windows-x64   • Microsoft Windows [Versión 10.0...]
```
*(En este ejemplo, el `device_id` es `19283746a5b6` o el nombre del dispositivo).*

#### Paso 5: Redirección de red para consumir el Backend NestJS (`adb reverse`)
Para que tu celular físico pueda conectarse a la API de NestJS que corre en tu PC (`localhost:3000`) sin problemas de firewall de Windows ni configuraciones complejas de Wi-Fi, ejecuta:
```powershell
adb reverse tcp:3000 tcp:3000
```
> 💡 **¿Qué hace `adb reverse`?**  
> Enruta automáticamente cualquier petición que haga la app en el teléfono a `http://localhost:3000` directamente hacia tu computadora mediante el cable USB. Así, la app móvil se comunica con tu servidor NestJS local de forma instantánea y segura.

#### Paso 6: Compilar y ejecutar en el celular físico
Ejecuta el comando especificando el identificador de tu equipo:
```powershell
flutter run -d <device_id>
```
*Ejemplo real:*
```powershell
flutter run -d 19283746a5b6
```
Flutter compilará la APK en modo Debug, la transferirá al celular y la iniciará automáticamente en la pantalla de tu teléfono con soporte para **Hot Reload (`r`)**.

---

## 7. Direcciones de Red y Endpoints Clave

Para evitar confusiones al conectar la aplicación según el dispositivo que uses, consulta la siguiente tabla:

| Entorno de Prueba | URL Base de la API REST | Swagger / OpenAPI |
|---|---|---|
| **Navegador Web / Postman en tu PC** | `http://localhost:3000/api/v1` | `http://localhost:3000/api/docs` |
| **Emulador Android Oficial (AVD)** | `http://10.0.2.2:3000/api/v1` | `http://10.0.2.2:3000/api/docs` |
| **Celular Android Físico (vía WiFi)** | `http://<IP_LOCAL_DE_TU_PC>:3000/api/v1` | `http://<IP_LOCAL_DE_TU_PC>:3000/api/docs` |

> 📌 **¿Por qué `10.0.2.2` en el emulador Android?**
> En Android, `localhost` se refiere al propio teléfono simulado. La dirección IP mágica `10.0.2.2` es el alias que asigna el motor de virtualización de Google para acceder al `localhost` de tu computadora Windows.

> 📌 **¿Cómo saber la IP local de tu PC para probar en celular físico?**
> Ejecuta `ipconfig` en PowerShell y busca la **Dirección IPv4** de tu adaptador Wi-Fi (ejemplo: `192.168.1.35`). Ambos dispositivos deben estar conectados a la misma red WiFi.

---

## 8. Pruebas de la API REST con Swagger y Postman

### 8.1 Exploración con Swagger OpenAPI
Con el backend corriendo, abre tu navegador y visita:
👉 **[http://localhost:3000/api/docs](http://localhost:3000/api/docs)**

Podrás inspeccionar los esquemas DTO, los códigos de respuesta HTTP y probar directamente los endpoints:
- `POST /api/v1/auth/register`: Registro de nuevo usuario.
- `POST /api/v1/auth/login`: Autenticación y obtención de token JWT.
- `GET /api/v1/users/me`: Perfil del usuario autenticado (requiere Bearer Token).
- `PATCH /api/v1/users/me`: Actualización de datos de perfil.
- `GET /api/v1/worker-profile/me`: Consulta de perfil técnico.
- `PUT /api/v1/worker-profile/me`: Configuración de especialidad y biografía.

### 8.2 Pruebas con la Colección Postman
El proyecto incluye una colección oficial preconfigurada en la carpeta `postman/`:
1. Abre Postman y pulsa **Import**.
2. Selecciona ambos archivos:
   - `postman/CHAMBA_API.postman_collection.json`
   - `postman/CHAMBA_Environment.postman_environment.json`
3. En la esquina superior derecha de Postman, selecciona el entorno **CHAMBA Local Environment**.
4. Ejecuta la petición `1. Autenticación -> Iniciar Sesión (Exitoso)`.
5. El script de pruebas automático de Postman capturará el `accessToken` generado y lo asignará dinámicamente a las peticiones protegidas.

---

## 9. Ejecución de Pruebas Automatizadas y Calidad

Para asegurar que los cambios no rompen ninguna funcionalidad existente, ejecuta los comandos de verificación:

### 9.1 Pruebas del Frontend (Flutter)
```powershell
# Análisis estático de lints y tipado Dart (debe reportar 0 issues)
flutter analyze

# Suite completa de tests unitarios, estado y widgets responsive (37 tests)
flutter test
```

### 9.2 Pruebas del Backend (NestJS + Vitest)
```powershell
cd backend

# Compilación de TypeScript con Nest CLI (debe terminar sin errores)
npm run build

# Prueba unitaria base de controladores
npm run test

# Pruebas de integración E2E completas (11 tests que validan Auth y Users)
npm run test:e2e
```

---

## 10. Compilación e Instalación de APK para Pruebas

Si necesitas generar un paquete `.apk` instalable para probar en dispositivos físicos o compartir con el equipo:

### 10.1 Compilar la APK en modo Debug
En la raíz del proyecto:
```powershell
flutter build apk --debug
```
*Binario generado:* `build\app\outputs\flutter-apk\app-debug.apk`

### 10.2 Compilar la APK en modo Release
```powershell
flutter build apk --release
```
*Binario generado:* `build\app\outputs\flutter-apk\app-release.apk`

---

## 11. Compatibilidad y Responsive en Dispositivos Android

La aplicación ha sido auditada exhaustivamente para garantizar un diseño adaptativo sin errores de desbordamiento (`RenderFlex overflow`) en todo el ecosistema de pantallas Android:

### 11.1 Resoluciones Comprobadas al 100%
- **Compacto (320 × 568 dp):** Dispositivos de pantalla angosta y baja altura.
- **Pequeño (360 × 640 dp):** Gama de entrada clásica (Moto E, Galaxy A0x).
- **Mediano (393 × 852 dp):** Resolución estándar moderna (Pixel 7, Galaxy S23, emulador `Medium_Phone`).
- **Grande (412 × 915 dp):** Terminales de gama alta (Pixel 8 Pro, Galaxy S24 Ultra).
- **Grande Ancho (430 × 932 dp):** Phablets con mayor relación de aspecto horizontal.

### 11.2 Accesibilidad y Teclado
- **Fuentes aumentadas (1.3x y 1.5x):** Los textos largos y badges utilizan `Wrap`, `Flexible` y `ConstrainedBox(minHeight)` para redistribuirse sin cortarse.
- **Teclado en pantalla:** Las pantallas de login, registro y formularios gestionan el espacio ocupado por el teclado (`viewInsets.bottom: 280dp`) mediante scroll fluido.

### 11.3 Cómo Instalar la APK en un Celular Físico
1. Activa **Opciones de desarrollador** en tu teléfono:
   - Ve a `Ajustes` -> `Acerca del teléfono`.
   - Pulsa 7 veces sobre `Número de compilación`.
   - Entra en `Opciones de desarrollador` y activa **Depuración por USB**.
2. Conecta tu celular a la PC con cable USB y confirma la autorización en la pantalla del celular.
3. Verifica que la PC lo reconozca:
   ```powershell
   adb devices
   ```
4. Instala la APK compilada:
   ```powershell
   adb install -r build\app\outputs\flutter-apk\app-debug.apk
   ```

---

## 12. Solución de Errores Frecuentes (Troubleshooting)

### 🔴 Error: `Authentication failed against database server` (Prisma P1000)
- **Causa:** El usuario o la contraseña configurados en `backend/.env` no coinciden con los de tu PostgreSQL local.
- **Solución:** Revisa tu línea `DATABASE_URL`. Prueba iniciar sesión en consola con `psql -U chamba_app -h localhost -p 5432 -d chamba_db` para confirmar tus credenciales.

### 🔴 Error: `No se pudo conectar con el servidor backend CHAMBA` en Flutter
- **Causa:** El backend NestJS no está iniciado o el emulador no puede alcanzar `10.0.2.2:3000`.
- **Solución:**
  1. Verifica que la terminal del backend siga abierta y mostrando `🚀 CHAMBA Backend ejecutándose en: http://localhost:3000/api/v1`.
  2. Abre Chrome dentro del emulador Android y navega a `http://10.0.2.2:3000/api/docs`. Si abre Swagger, el túnel de red está funcionando.

### 🔴 Error: `Puerto 3000 o 5432 ya en uso` (EADDRINUSE)
- **Causa:** Hay otra instancia de Node.js o PostgreSQL ocupando el puerto.
- **Solución:**
  ```powershell
  # Identificar el proceso ocupando el puerto 3000 en Windows:
  Get-Process -Id (Get-NetTCPConnection -LocalPort 3000).OwningProcess | Stop-Process -Force
  ```

### 🔴 Error: `PrismaClientInitializationError: Target database not found`
- **Causa:** No creaste la base de datos `chamba_db` antes de correr las migraciones.
- **Solución:** Entra a `psql -U postgres` y ejecuta `CREATE DATABASE chamba_db;`.

### 🔴 Error: `RenderFlex overflowed by X pixels`
- **Causa:** Se introdujo un widget con ancho o altura fija dentro de una fila o columna sin envoltura flexible.
- **Solución:** Consulta la suite de pruebas `test/presentation/responsive_layout_test.dart` y utiliza `Expanded`, `Flexible`, `Wrap` o `LayoutBuilder`.
