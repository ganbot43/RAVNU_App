# RAVNU

Sistema de gestión para estaciones de combustible en iOS.  
La app combina operación comercial, inventario, compras, tesorería, cobranzas y RRHH con acceso por rol y soporte para sincronización remota.

## Estado actual del proyecto

RAVNU no está en un punto “prototipo vacío”. Ya tiene módulos operativos, control de sesión, sincronización remota con Firebase y una migración activa hacia interfaz híbrida `UIKit + SwiftUI`.

La app hoy usa esta estrategia:

- `Storyboard + UIViewController` para estructura principal
- `UINavigationController` para navegación jerárquica
- `UITabBarController` para navegación principal por módulos
- `SwiftUI` embebido dentro de controllers UIKit con `UIHostingController`
- `Core Data` como persistencia local
- `Firebase Authentication + Firestore` como backend remoto principal
- API HTTP para solicitudes administrativas hacia panel web

## Arquitectura

### Patrón híbrido de UI

La estructura de navegación **se mantiene en UIKit**.  
SwiftUI se usa para reemplazar progresivamente el contenido visual de cada pantalla sin romper storyboard, tabs ni navigation stack.

### Regla arquitectónica actual

- `UITabBarController` define tabs por rol
- cada módulo sigue entrando por su `UIViewController`
- el controller:
  - carga datos
  - valida permisos
  - orquesta navegación
  - presenta sheets / alerts / segues
- la vista SwiftUI:
  - renderiza dashboard, listas, cards y formularios
  - expone closures para acciones
- el controller actualiza la vista con:
  - `hostingController?.rootView = ...`

### Controllers híbridos ya presentes

- `LoginViewController` → `LoginHybridView`
- `CajeroViewController` → `CajeroDashboardView`
- `AlmaceneroViewController` → `WarehouseDashboardView`
- `VentasViewController` → `SalesDashboardView`
- `RrhhViewController` → `RrhhDashboardView`
- `MasViewController` → `MoreDashboardView`
- `ComprasViewController` → `PurchasesDashboardView`
- `TesoreriaViewController` → `TreasuryDashboardView`
- `CuotasViewController` → `CollectionsDashboardView`

Esto confirma que la dirección oficial del proyecto es **mantener UIKit como shell de navegación y migrar contenido a SwiftUI**.

## Stack técnico

| Capa | Tecnología |
|---|---|
| Plataforma | iOS |
| Lenguaje | Swift |
| UI Shell | UIKit + Storyboard |
| UI de contenido | SwiftUI |
| Persistencia local | Core Data |
| Backend remoto | Firebase Firestore |
| Autenticación | Firebase Authentication |
| Sincronización | Coordinador propio (`RemoteSyncCoordinator`) |
| Solicitudes admin | API HTTP (`AdminRequestService`) |

## Estructura principal

### App
- `AppDelegate.swift`
- `SceneDelegate.swift`
- `RoleTabBarController.swift`

### Infraestructura
- `AppRuntime.swift`
- `AppSession.swift`
- `AppSupport.swift`
- `FirebaseBootstrap.swift`
- `RemoteSyncCoordinator.swift`
- `TreasuryRemoteSync.swift`
- `AdminRequestService.swift`

### Módulos
- `Auth`
- `Cajero`
- `Ventas`
- `Clientes`
- `Almacén`
- `Compras`
- `Tesorería`
- `Admin / RRHH`
- `Más`

## Roles del sistema

El sistema trabaja con 4 roles canónicos:

- `admin`
- `supervisor`
- `cajero`
- `almacenero`

Normalización usada en app:
- `Admin`
- `Super`
- `Cajero`
- `Almacen`

La app convierte nombres heredados o variantes remotas hacia estos valores para mantener consistencia.

## Política funcional por rol

### Administrador
Acceso total. Puede:
- gestionar RRHH
- crear y editar trabajadores
- cambiar estados
- acceder a todos los módulos
- ejecutar acciones sensibles directas
- aprobar o rechazar solicitudes desde panel web

### Supervisor
Acceso operativo ampliado. Puede:
- ver ventas
- registrar ventas
- ver clientes
- gestionar crédito/cobros
- ver almacén
- ver tesorería
- generar algunas solicitudes administrativas

No debe acceder a RRHH ni a control total de compras.

### Cajero
Acceso comercial. Puede:
- registrar ventas
- ver clientes
- ver cobros/cuotas
- solicitar edición o anulación de ventas

No debe:
- agregar clientes
- gestionar almacén
- gestionar compras
- acceder a RRHH

### Almacenero
Acceso a inventario y compras. Puede:
- ver stock
- registrar movimientos
- crear/solicitar productos
- crear/solicitar almacenes
- crear/solicitar órdenes de compra
- gestionar recepción operativa según flujo

No debe acceder a ventas, RRHH ni tesorería operativa general.

## Navegación por tabs

`RoleTabBarController` filtra tabs visibles según rol actual.

Configuración actual:

- `admin` → `Inicio`, `Ventas`, `Clientes`, `Almacén`, `Más`
- `supervisor` → `Inicio`, `Ventas`, `Clientes`, `Almacén`, `Más`
- `cajero` → `Inicio`, `Ventas`, `Clientes`, `Más`
- `almacenero` → `Inicio`, `Almacén`, `Más`

## Módulos implementados

### Auth
- login visual en SwiftUI
- autenticación con Firebase
- búsqueda de acceso en `users_lookup`
- carga de perfil desde `users`
- persistencia de sesión en `AppSession`

### Inicio / Cajero
- dashboard en SwiftUI
- métricas de ventas y cobros
- resumen semanal
- alertas de stock bajo
- cliente con mayor deuda

### Ventas
- dashboard SwiftUI
- listado de ventas
- nueva venta
- métricas por efectivo/crédito
- solicitud de edición de venta
- solicitud de anulación de venta

### Clientes / Cobros
- clientes
- cuotas
- dashboards SwiftUI
- validaciones de permisos por rol

### Almacén
- dashboard SwiftUI
- almacenes
- productos
- movimientos
- responsables filtrados por rol cuando aplica
- consolidación de stock para evitar falsos duplicados

### Compras
- dashboard SwiftUI
- proveedores
- órdenes de compra
- estados de compra
- soporte para solicitudes admin desde roles no admin

### Tesorería
- dashboard financiero
- ingresos/egresos
- corrección de lógica para no registrar compras “recibidas” como gasto de caja si no están pagadas

### RRHH
- dashboard SwiftUI
- equipo
- analítica
- permisos
- alta/edición/cambio de estado de trabajadores
- acceso solo admin

### Más
- dashboard SwiftUI
- acceso a módulos secundarios
- logout
- visibilidad por rol

## Persistencia local

La app usa Core Data con entidades principales:

- `ClienteEntity`
- `CuotaEntity`
- `VentaEntity`
- `ProductoEntity`
- `AlmacenEntity`
- `StockAlmacenEntity`
- `MovimientoInventarioEntity`
- `OrdenCompraEntity`
- `ProveedorEntity`
- `LoginEntity`

`AppCoreData` centraliza acceso al `persistentContainer`.

## Backend remoto Firebase

### Servicios usados
- `FirebaseAuth`
- `Firestore`

### Colecciones remotas que la app ya consume o sincroniza
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

## Sesión y runtime

### `AppRuntime`
Configura:
- Firebase
- sincronización remota
- modo backend actual

### `AppSession`
Guarda:
- `usuarioLogueado`
- `rolLogueado`
- `userDocumentId`
- `authUid`
- `userEmail`
- `adminAPIAuthToken`
- flags de sincronización remota

## Sincronización

`RemoteSyncCoordinator`:
- detecta si Firebase está disponible
- inicia sincronización inicial
- sincroniza Firestore hacia Core Data
- publica cambios por `NotificationCenter`

La app puede operar con:
- modo remoto Firebase
- modo fallback local

## Solicitudes administrativas

La app ya soporta el patrón “acción sensible → solicitud al panel admin”.

### Servicio
`AdminRequestService.swift`

### Configuración desde `Info.plist`
- `AdminRequestsAPIBaseURL`
- `AdminRequestsAPIRequestsPath`
- `AdminRequestsAuthMode`

### Modos de autenticación soportados
- `none`
- `bearer_token`
- `firebase_id_token`

### Payload base
```json
{
  "requestId": "uuid",
  "type": "cancel_sale",
  "module": "ventas",
  "status": "pending",
  "requestedBy": {
    "userId": "userDocId",
    "authUid": "firebaseUid",
    "fullName": "Usuario",
    "roleId": "cajero",
    "email": "user@mail.com"
  },
  "target": {
    "entity": "sale",
    "entityId": "saleId"
  },
  "payload": {},
  "reason": "Motivo de la solicitud",
  "createdAt": "ISO8601"
}
