# ⛽ RAVNU — Sistema de Gestión de Estaciones de Combustible

Aplicación móvil nativa iOS para la administración integral de estaciones de servicio. Centraliza operaciones, inventario, finanzas, crédito de clientes y gestión de personal en una sola plataforma, con acceso diferenciado por rol, sincronización con Firebase y una arquitectura híbrida `UIKit + SwiftUI`.

---

## Tabla de Contenidos

1. [¿Qué es RAVNU?](#qué-es-ravnu)
2. [Stack Tecnológico](#stack-tecnológico)
3. [Arquitectura de la Aplicación](#arquitectura-de-la-aplicación)
4. [Roles de Usuario](#roles-de-usuario)
5. [Matriz de Permisos](#matriz-de-permisos)
6. [Módulos del Sistema](#módulos-del-sistema)
   - [Inicio — Dashboard](#-inicio--dashboard)
   - [Ventas](#-ventas)
   - [Clientes](#-clientes)
   - [Almacén](#-almacén)
   - [Tesorería](#-tesorería)
   - [Cobros](#-cobros)
   - [Compras](#-compras)
   - [RRHH](#-rrhh)
7. [Automatizaciones — Efectos en Cascada](#automatizaciones--efectos-en-cascada)
8. [Entidades del Sistema](#entidades-del-sistema)
9. [Proveedores](#proveedores)
10. [Almacenes](#almacenes)
11. [Productos de Combustible](#productos-de-combustible)
12. [Estados del Sistema](#estados-del-sistema)
13. [Base de Datos — Firebase Firestore](#base-de-datos--firebase-firestore)
14. [Autenticación y Sesión](#autenticación-y-sesión)
15. [Solicitudes Administrativas y API Web](#solicitudes-administrativas-y-api-web)
16. [Diseño Visual](#diseño-visual)
17. [Prototipo Web de Referencia](#prototipo-web-de-referencia)
18. [Estado Real de Implementación](#estado-real-de-implementación)
19. [Deuda Técnica y Próximos Pasos](#deuda-técnica-y-próximos-pasos)

---

## ¿Qué es RAVNU?

RAVNU es una herramienta de gestión operativa diseñada para estaciones de servicio/combustible. Permite que diferentes perfiles del personal — administrador, supervisor, cajero y almacenero — trabajen sobre la misma información actualizada en tiempo real, con acceso restringido únicamente a los módulos correspondientes a su función.

El sistema resuelve tres necesidades clave de una estación:

- **Control financiero:** seguimiento de ingresos, egresos, crédito a clientes y cobro de cuotas.
- **Control de inventario:** stock de combustible por almacén, alertas de mínimos y trazabilidad de movimientos.
- **Control operativo:** registro de ventas, órdenes de compra a proveedores y gestión del personal.

Toda acción relevante genera efectos automáticos en los módulos relacionados, evitando que el usuario tenga que registrar la misma información dos veces.

---

## Stack Tecnológico

| Capa | Tecnología |
|---|---|
| Plataforma | iOS 16+ — iPhone |
| Lenguaje | Swift |
| Interfaz de usuario | UIKit + Storyboard + SwiftUI |
| Arquitectura UI | Híbrida: navegación UIKit, contenido progresivo en SwiftUI |
| Arquitectura lógica | MVC + servicios + coordinadores de sincronización |
| Base de datos local | Core Data |
| Base de datos remota | Firebase Firestore |
| Autenticación | Firebase Authentication (email + contraseña) |
| Almacenamiento de archivos | Firebase Storage |
| Lógica de servidor | Firebase Cloud Functions / API web administrativa |
| Gráficas | Swift Charts / DGCharts heredado |
| Carga de imágenes remotas | Kingfisher |

---

## Arquitectura de la Aplicación

RAVNU ya no está planteada como una app UIKit pura ni como una app SwiftUI pura. La decisión vigente del proyecto es una **arquitectura híbrida**.

### Estructura híbrida

- `UITabBarController` mantiene la navegación principal por módulos.
- `UINavigationController` mantiene la navegación jerárquica.
- Cada módulo sigue entrando por un `UIViewController`.
- Dentro del controller, el contenido visual puede renderizarse con `SwiftUI` usando `UIHostingController`.
- El controller UIKit sigue controlando:
  - permisos
  - navegación
  - segues
  - sheets
  - alerts
  - carga de datos
  - sincronización
- Las vistas SwiftUI se usan para:
  - dashboards
  - cards
  - formularios
  - tabs internas de contenido
  - layouts complejos

### Regla de migración vigente

La migración correcta del proyecto es:

1. **mantener `NavigationController`**
2. **mantener `TabBarController`**
3. reemplazar pantalla por pantalla el contenido UIKit por vistas SwiftUI embebidas
4. no romper el shell actual del storyboard

### Pantallas que ya siguen este patrón híbrido

Actualmente ya existen controllers que montan contenido SwiftUI:

- `LoginViewController` → `LoginHybridView`
- `CajeroViewController` → `CajeroDashboardView`
- `AlmaceneroViewController` → `WarehouseDashboardView`
- `VentasViewController` → `SalesDashboardView`
- `RrhhViewController` → `RrhhDashboardView`
- `MasViewController` → `MoreDashboardView`
- `ComprasViewController` → `PurchasesDashboardView`
- `TesoreriaViewController` → `TreasuryDashboardView`
- `CuotasViewController` → `CollectionsDashboardView`
- varios modales SwiftUI presentados como sheets híbridos

Esto convierte a RAVNU en una app **UIKit estructural con SwiftUI progresivo**.

---

## Roles de Usuario

El sistema tiene exactamente **4 roles**. Cada persona que inicia sesión en la app pertenece a uno de ellos. El rol determina qué módulos puede ver y qué operaciones puede realizar.

---

### 🛡 Administrador

Control total del sistema. Es el único rol que puede:
- Ver y modificar la **matriz de permisos** de todos los roles
- Dar de alta, editar y eliminar trabajadores
- Acceder a todos los módulos sin restricción: ventas, clientes, almacén, tesorería, cobros, compras y RRHH
- Configurar la estación y sus datos generales
- Aprobar o rechazar solicitudes administrativas enviadas desde la app al panel web

Es el perfil del dueño o gerente de la estación.

---

### 👁 Supervisor

Perfil de supervisión operativa y financiera. Puede:
- Registrar y revisar ventas
- Gestionar clientes y sus líneas de crédito
- Controlar el inventario del almacén
- Ver el estado de la tesorería
- Registrar cobros de cuotas
- Enviar solicitudes administrativas para cambios sensibles

No puede acceder a RRHH y no debería ejecutar cambios administrativos críticos de forma directa.

---

### 💳 Cajero

Perfil enfocado en el punto de venta y atención al cliente. Puede:
- Registrar ventas al contado y a crédito
- Consultar clientes
- Registrar cobros de cuotas pendientes
- Solicitar edición o anulación de ventas al panel administrativo

No accede a almacén, tesorería, compras ni RRHH.  
En la política actual del proyecto, **no debería agregar clientes directamente**.

---

### 📦 Almacenero

Perfil enfocado en el control de inventario y abastecimiento. Puede:
- Ver el stock de todos los almacenes
- Registrar movimientos de inventario (entradas, salidas, transferencias)
- Crear o solicitar órdenes de compra a proveedores
- Confirmar la recepción de mercadería
- Solicitar creación de productos, almacenes o cambios sensibles al panel administrativo

No accede a ventas, clientes, tesorería, cobros ni RRHH.

---

## Matriz de Permisos

La siguiente tabla muestra el acceso objetivo por defecto de cada rol. El **Administrador puede modificar esta matriz** desde el módulo de RRHH → pestaña Roles & Permisos.

| Módulo | Administrador | Supervisor | Cajero | Almacenero |
|---|:---:|:---:|:---:|:---:|
| 🏠 Inicio | ✅ | ✅ | ✅ | ✅ |
| 🛒 Ventas | ✅ | ✅ | ✅ | ❌ |
| 👥 Clientes | ✅ | ✅ | ⚠ Parcial | ❌ |
| 📦 Almacén | ✅ | ✅ | ❌ | ✅ |
| 💰 Tesorería | ✅ | ✅ | ❌ | ❌ |
| 💳 Cobros | ✅ | ✅ | ✅ | ❌ |
| 🚚 Compras | ✅ | ❌ | ❌ | ✅ |
| 👤 RRHH | ✅ | ❌ | ❌ | ❌ |

### Observación importante sobre estado actual

La política de negocio objetivo y la implementación actual no son idénticas en todos los puntos.  
Hoy ya están endurecidas estas reglas en la app:

- `RRHH` → solo admin
- `cajero` → puede crear ventas
- `cajero` → no debería agregar clientes
- `edición/anulación de ventas` → solicitud administrativa
- `alta de producto/almacén/proveedor/orden de compra` → según rol, puede ser directa o por solicitud
- `acciones sensibles` → migrando al modelo de request + aprobación

La barra de navegación inferior muestra únicamente los tabs a los que el usuario tiene acceso. El tab **Más** siempre es visible porque agrupa módulos secundarios como tesorería, cobros, compras y RRHH, pero dentro de Más cada tarjeta también se controla por permiso.

---

## Módulos del Sistema

---

### 🏠 Inicio — Dashboard

Pantalla principal que el usuario ve al abrir la app. Resume el estado más crítico de la estación en ese momento.

**Métricas del día (scroll horizontal):**
- **Vendido Hoy** — suma de todas las ventas del día en curso.
- **Cobrado Hoy** — suma de cuotas cobradas en el día.
- **Por Cobrar** — monto total pendiente en cuotas de todos los clientes.

**Gráfica de ventas de la semana:**
Barras con las ventas de los últimos 7 días, con énfasis en el día más alto.

**Alertas de stock bajo:**
Se muestra automáticamente cuando algún combustible está por debajo de su nivel mínimo configurado.

**Cliente con mayor deuda:**
Muestra el cliente con la deuda activa más alta y acceso a su detalle.

**Estado actual de implementación:**
- ya existen dashboards SwiftUI
- se corrigieron inconsistencias de “semana” entre pantallas
- se corrigieron falsos positivos de stock bajo por registros duplicados

---

### 🛒 Ventas

Módulo para registrar y consultar todas las ventas de combustible.

**Lista de ventas:**
Muestra ventas registradas con cliente, producto, cantidad, total, tipo de pago y fecha.

**Registrar una nueva venta:**
Se abre desde el botón flotante (+). El formulario solicita cliente, producto, cantidad, total y tipo de pago.

Si se selecciona **Crédito**, se habilitan:
- número de cuotas
- monto por cuota
- fecha del primer vencimiento
- disponibilidad del cliente

Al guardar la venta, el sistema debe:
1. descontar stock
2. registrar salida en almacén
3. si es contado, generar ingreso en tesorería
4. si es crédito, generar cuotas y aumentar deuda del cliente

**Estado actual de implementación:**
- existe dashboard SwiftUI de ventas
- existe creación de ventas
- `cajero` puede crear ventas
- edición y anulación se modelan como **solicitudes administrativas**
- la app ya arma payloads `edit_sale` y `cancel_sale`

---

### 👥 Clientes

Directorio completo de clientes con control de crédito y seguimiento de deuda.

**Lista de clientes:**
Muestra nombre, documento, teléfono, estado y deuda actual.

**Estados de un cliente:**

| Estado | Condición | Color |
|---|---|---|
| ✅ Activo | Sin deuda o deuda dentro del límite sin cuotas vencidas | Verde |
| ⚠ En Riesgo | La deuda supera el 50% del límite de crédito | Naranja |
| 🔴 Vencido | Tiene al menos una cuota vencida sin pagar | Rojo |
| 🚫 Bloqueado | Límite de crédito superado | Gris |

**Agregar un nuevo cliente:**
Formulario con nombre, documento, teléfono, email, dirección y límite de crédito.

**Estado actual de implementación:**
- módulo presente
- cuotas presentes
- dashboard SwiftUI presente en cobranzas
- `admin` crea directo
- `supervisor` puede quedar en flujo de solicitud según configuración
- `cajero` no debería crear clientes

---

### 📦 Almacén

Control del inventario de combustible distribuido en múltiples almacenes físicos.

**Vista de inventario:**
Tarjetas por almacén y por producto con stock, capacidad y estado.

**Vista de productos:**
Catálogo de combustibles con precio, unidad de medida, stock consolidado y alertas.

**Registrar un movimiento:**
Formulario con tipo, almacén origen, almacén destino, producto, cantidad y nota.

Tipos:
- **Entrada**
- **Salida**
- **Transferencia**

**Estado actual de implementación:**
- dashboard SwiftUI de almacén ya existe
- lectura de almacenes, productos y movimientos ya existe
- responsables ya se ajustaron mejor por rol
- se corrigieron errores de stock consolidando registros duplicados
- `almacenero` maneja movimientos
- creación de producto o almacén puede pasar por solicitud administrativa según rol

---

### 💰 Tesorería

Centro financiero de la estación. Registra todos los movimientos de dinero.

**Balance general:**
Saldo actual, margen, ingresos y egresos.

**Gráficas:**
- ingresos vs egresos
- distribución de gastos

**Filtros:** Hoy / Semana / Mes

**Lista de transacciones:**
Tipo, descripción, responsable, monto y fecha.

**Estado actual de implementación:**
- existe módulo y dashboard
- parte de los movimientos se generan desde otros módulos
- se corrigió una falla importante:
  - una compra `recibida` ya no debe contarse automáticamente como salida de caja si no está realmente pagada

---

### 💳 Cobros

Módulo de gestión y seguimiento de cuotas de ventas a crédito.

**Resumen de cobros:**
- Vencido
- Pendiente
- Cobrado Hoy

**Lista de cuotas:**
Filtrable por estado.

**Registrar un pago:**
- seleccionar cliente
- seleccionar cuota
- ingresar monto
- recalcular saldo y deuda total

Al confirmar:
- actualiza cuota
- reduce deuda del cliente
- genera ingreso en tesorería
- puede reactivar estado del cliente

**Estado actual de implementación:**
- existe módulo de cuotas
- dashboard SwiftUI presente
- integración con clientes y deuda ya modelada

---

### 🚚 Compras

Gestión de órdenes de compra de combustible a proveedores externos.

**Estados de compra:**

| Estado | Descripción | Impacto en stock |
|---|---|---|
| ⏳ Pendiente | La orden fue creada pero el combustible aún no llegó | Sin impacto |
| ✅ Recibida | El combustible ingresó físicamente al almacén | Stock aumenta |
| ❌ Cancelada | La orden fue anulada | Sin impacto |

**Gestión de proveedores:**
Directorio con datos, categoría, rating, gasto histórico y última compra.

**Flujo completo:**
1. crear orden
2. esperar recepción
3. confirmar recepción o cancelar

**Estado actual de implementación:**
- módulo compras presente
- dashboard SwiftUI presente
- alta de proveedor y orden ya pueden ir por solicitud administrativa si el rol no debe ejecutar directo
- también existe flujo de solicitud para actualización de estado de compra

---

### 👤 RRHH

Módulo de gestión del personal.

#### Pestaña Trabajadores
Lista del personal con nombre, rol, turno y teléfono.

#### Pestaña Actividad
Métricas por trabajador.

#### Pestaña Roles & Permisos
Visualización y edición de permisos por rol.

**Estado actual de implementación:**
- RRHH ya está migrado a dashboard SwiftUI híbrido
- duplicados visuales de roles/trabajadores fueron corregidos
- edición y cambio de estado ya están implementados
- **solo admin** puede acceder y operar este módulo
- ya no tiene sentido enrutar RRHH a solicitudes para roles que ni ven el módulo

---

## Automatizaciones — Efectos en Cascada

El principio central de RAVNU es que **registrar algo en un módulo actualiza automáticamente los módulos relacionados**.

### Al registrar una venta

| Módulo afectado | Qué ocurre |
|---|---|
| Almacén | Se descuenta la cantidad vendida del almacén con más stock de ese producto |
| Historial de almacén | Se crea un movimiento de tipo **Salida** vinculado a esa venta |
| Tesorería (solo contado) | Se registra un ingreso por el monto total |
| Clientes (solo crédito) | La deuda del cliente aumenta |
| Cobros (solo crédito) | Se generan cuotas automáticamente |

### Al confirmar la recepción de una compra

| Módulo afectado | Qué ocurre |
|---|---|
| Almacén | Aumenta stock del almacén destino |
| Historial de almacén | Se crea movimiento de tipo **Entrada** |
| Tesorería | Se registra egreso cuando corresponde al flujo real de pago |
| Proveedores | Se actualiza gasto total e histórico |
| Dashboard | Se registra evento reciente |

### Al registrar un cobro de cuota

| Módulo afectado | Qué ocurre |
|---|---|
| Cobros | La cuota se marca pagada o parcial |
| Clientes | La deuda se reduce |
| Clientes | Si la deuda llega a cero, puede volver a Activo |
| Tesorería | Se registra un ingreso |

---

## Entidades del Sistema

### Usuario
Persona con acceso a la app.

### Cliente
Persona o empresa que compra combustible, con o sin crédito.

### Venta
Entidad central de operación comercial.

### Producto
Combustible con precio de venta y stock mínimo.

### Almacén
Espacio físico de almacenamiento.

### Movimiento de Almacén
Registro histórico de cambios de stock.

### Cuota
Pago parcial de una venta a crédito.

### Transacción
Movimiento financiero en tesorería.

### Compra
Orden de compra a proveedor.

### Trabajador
Empleado operativo del negocio.

### Proveedor
Empresa externa que abastece combustible.

### Matriz de Permisos
Configuración por estación/rol para controlar acceso.

---

## Proveedores

Los proveedores son entidades de referencia comercial. No tienen acceso a la app.

Datos:
- razón social
- RUC
- categoría
- contacto
- rating
- gasto acumulado
- número de transacciones
- última compra

---

## Almacenes

La estación puede operar con múltiples almacenes físicos.

Acciones:
- ver stock
- registrar entradas
- registrar salidas
- transferir stock
- ver historial

---

## Productos de Combustible

Cada producto tiene:
- nombre
- unidad de medida
- precio de venta
- stock mínimo
- capacidad máxima

El precio de compra se registra por orden, no por catálogo.

---

## Estados del Sistema

### Estados de Cliente

| Estado | Color | Condición |
|---|---|---|
| Activo | 🟢 Verde | Deuda dentro de rango |
| En Riesgo | 🟠 Naranja | Deuda > 50% del límite |
| Vencido | 🔴 Rojo | Tiene cuotas vencidas |
| Bloqueado | ⚫ Gris | Superó el límite |

### Estados de Cuota

| Estado | Color | Significado |
|---|---|---|
| Pendiente | 🟠 Naranja | Cuota futura |
| Vencido | 🔴 Rojo | Cuota vencida impaga |
| Pagado | 🟢 Verde | Cuota cubierta |

### Estados de Orden de Compra

| Estado | Color | Significado |
|---|---|---|
| Pendiente | 🟠 Naranja | Aún no recibida |
| Recibida | 🟢 Verde | Ingresó mercadería |
| Cancelada | 🔴 Rojo | Orden anulada |

### Estados de Stock

| Estado | Color | Condición |
|---|---|---|
| OK | 🟢 Verde | Por encima del mínimo |
| Stock Bajo | 🔴 Rojo | Igual o menor al mínimo |

---

## Base de Datos — Firebase Firestore

Firestore es la base de datos remota principal del sistema.

### Estructura conceptual objetivo

| Colección | Contenido |
|---|---|
| `stations` | Estaciones, configuración y permisos |
| `users` | Usuarios y perfiles |
| `clients` | Clientes |
| `sales` | Ventas |
| `products` | Productos |
| `warehouses` | Almacenes |
| `warehouseMovements` | Historial de movimientos |
| `purchases` | Compras |
| `installments` | Cuotas |
| `transactions` | Tesorería |
| `workers` | Trabajadores |
| `suppliers` | Proveedores |

### Estructura real que la app ya consume hoy

Además del modelo conceptual, el código ya trabaja con colecciones como:

- `users`
- `users_lookup`
- `roles`
- `customers`
- `products`
- `warehouses`
- `warehouse_stock`
- `inventory_movements`
- `sales`
- `sale_installments`
- `suppliers`
- `purchase_orders`
- `treasury_transactions`

### Escrituras atómicas
Las operaciones con impacto múltiple deben resolverse en batch o transacciones.

### Sincronización en tiempo real
Los módulos críticos usan listeners y sincronización remota.

### Caché offline
Firestore y Core Data funcionan como base para operación tolerante a fallos de conectividad.

---

## Autenticación y Sesión

El sistema usa Firebase Authentication con email y contraseña.

### Proceso de login real actual

1. usuario ingresa correo y contraseña
2. Firebase Auth valida credenciales
3. la app consulta `users_lookup/{authUid}`
4. valida que esté activo
5. obtiene `userId`
6. carga `users/{userId}`
7. normaliza rol
8. persiste sesión en `AppSession`
9. construye experiencia según rol

### Persistencia de sesión
La app guarda:
- nombre
- rol
- `userDocumentId`
- `authUid`
- email
- flags remotos

### Alta de nuevos usuarios
La realiza admin desde RRHH usando Firebase Auth + Firestore.

### Seguridad
Se debe reforzar en:
- Firestore Rules
- backend web
- API de solicitudes
- validación por rol

---

## Solicitudes Administrativas y API Web

RAVNU ya incorpora un flujo de solicitudes para acciones sensibles que no deben ejecutarse directo desde roles operativos.

### Casos de uso actuales

Ejemplos:
- anular venta
- editar venta
- crear producto
- crear almacén
- crear proveedor
- crear orden de compra
- cambiar estado de compra
- crear cliente según rol y política

### Servicio actual en app

La app ya tiene `AdminRequestService`.

Soporta:
- `POST` a endpoint configurable
- modo auth:
  - `none`
  - `bearer_token`
  - `firebase_id_token`
- payload JSON estructurado
- caché local de solicitudes
- consulta básica de solicitudes propias

### Keys de `Info.plist`

- `AdminRequestsAPIBaseURL`
- `AdminRequestsAPIRequestsPath`
- `AdminRequestsAuthMode`

### Estructura general del payload

```json
{
  "requestId": "uuid",
  "type": "cancel_sale",
  "module": "ventas",
  "status": "pending",
  "requestedBy": {
    "userId": "docId",
    "authUid": "firebaseUid",
    "fullName": "Nombre Usuario",
    "roleId": "cajero",
    "email": "correo@empresa.com"
  },
  "target": {
    "entity": "sale",
    "entityId": "saleId"
  },
  "payload": {},
  "reason": "Texto del motivo",
  "createdAt": "2026-04-27T03:20:00Z",
  "reviewedAt": null,
  "reviewedBy": null,
  "rejectionReason": null
}
