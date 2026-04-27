# RAVNU

Sistema de gestion para estaciones de combustible en iOS.

Este README fusiona dos cosas:

1. la vision funcional y de negocio del producto
2. el estado real del codigo que hoy existe en este repositorio

La idea es que sirva tanto para negocio como para developers.

---

## Tabla de contenidos

1. [Que es RAVNU](#que-es-ravnu)
2. [Vision del sistema](#vision-del-sistema)
3. [Stack tecnologico real](#stack-tecnologico-real)
4. [Arquitectura actual del repositorio](#arquitectura-actual-del-repositorio)
5. [Roles de usuario](#roles-de-usuario)
6. [Matriz de permisos objetivo](#matriz-de-permisos-objetivo)
7. [Matriz operativa real implementada](#matriz-operativa-real-implementada)
8. [Modulos del sistema](#modulos-del-sistema)
9. [Automatizaciones y efectos en cascada](#automatizaciones-y-efectos-en-cascada)
10. [Entidades del sistema](#entidades-del-sistema)
11. [Base de datos y colecciones reales](#base-de-datos-y-colecciones-reales)
12. [Autenticacion y sesion](#autenticacion-y-sesion)
13. [Solicitudes administrativas por API](#solicitudes-administrativas-por-api)
14. [Navegacion por rol](#navegacion-por-rol)
15. [Estado real por modulo](#estado-real-por-modulo)
16. [Setup de desarrollo](#setup-de-desarrollo)
17. [Deudas tecnicas y limitaciones conocidas](#deudas-tecnicas-y-limitaciones-conocidas)
18. [Roadmap recomendado](#roadmap-recomendado)

---

## Que es RAVNU

RAVNU es una aplicacion movil para la administracion integral de estaciones de servicio y combustible.

Centraliza:

- ventas
- clientes y credito
- cobros
- almacen e inventario
- compras
- tesoreria
- RRHH
- control de accesos por rol

El objetivo del sistema es que una misma operacion actualice automaticamente todas las areas relacionadas, evitando duplicidad manual y reduciendo errores operativos.

---

## Vision del sistema

RAVNU fue planteado como una plataforma para resolver tres necesidades centrales de una estacion:

- control financiero
- control de inventario
- control operativo

### Necesidades que cubre

- seguimiento de ingresos y egresos
- manejo de clientes a credito y cuotas
- control de stock por almacen
- historial de movimientos
- registro de ventas
- ordenes de compra a proveedores
- gestion de personal y permisos

### Principio funcional

Cada accion importante debe tener efecto automatico en otros modulos.

Ejemplos:

- una venta contado debe impactar stock y tesoreria
- una venta credito debe impactar stock, cliente y cuotas
- una compra recibida debe impactar almacen, historial y tesoreria
- un cobro de cuota debe impactar cliente y tesoreria

---

## Stack tecnologico real

Esto es lo que el repositorio usa hoy:

| Capa | Implementacion actual |
|---|---|
| Plataforma | iOS |
| Lenguaje | Swift |
| UI legacy | UIKit + Storyboards |
| UI nueva | SwiftUI embebido via `UIHostingController` |
| Persistencia local | Core Data |
| Auth | Firebase Authentication |
| Base remota | Firebase Firestore |
| Sincronizacion | Firestore + coordinadores locales |
| API administrativa | HTTP propia |
| Graficas | `Charts` / Swift Charts |

Notas:

- la aplicacion no es SwiftUI pura
- tampoco es Firestore puro: Core Data sigue siendo central
- la API administrativa no reemplaza Firestore; se usa para workflows de aprobacion

---

## Arquitectura actual del repositorio

### App

- [AppDelegate.swift](/Users/ginobarrena/Documents/RAVNU_Proyecto/RAVNU_Proyecto/App/AppDelegate.swift)
- [SceneDelegate.swift](/Users/ginobarrena/Documents/RAVNU_Proyecto/RAVNU_Proyecto/App/SceneDelegate.swift)
- [RoleTabBarController.swift](/Users/ginobarrena/Documents/RAVNU_Proyecto/RAVNU_Proyecto/App/RoleTabBarController.swift)

### Infraestructura

- [AppSession.swift](/Users/ginobarrena/Documents/RAVNU_Proyecto/RAVNU_Proyecto/Infrastructure/AppSession.swift)
- [FirebaseBootstrap.swift](/Users/ginobarrena/Documents/RAVNU_Proyecto/RAVNU_Proyecto/Infrastructure/FirebaseBootstrap.swift)
- [RemoteSyncCoordinator.swift](/Users/ginobarrena/Documents/RAVNU_Proyecto/RAVNU_Proyecto/Infrastructure/RemoteSyncCoordinator.swift)
- [TreasuryRemoteSync.swift](/Users/ginobarrena/Documents/RAVNU_Proyecto/RAVNU_Proyecto/Infrastructure/TreasuryRemoteSync.swift)
- [AdminRequestService.swift](/Users/ginobarrena/Documents/RAVNU_Proyecto/RAVNU_Proyecto/Infrastructure/AdminRequestService.swift)

### Modulos

- Auth
- Inicio/Cajero
- Ventas
- Clientes/Cobros
- Almacen
- Compras
- Tesoreria
- RRHH
- Mas

### Observacion importante

El proyecto tiene duplicidad historica de infraestructura:

- hay clases en `Infrastructure/`
- y tambien versiones equivalentes dentro de [AppDelegate.swift](/Users/ginobarrena/Documents/RAVNU_Proyecto/RAVNU_Proyecto/App/AppDelegate.swift)

Esto afecta especialmente:

- `AppSession`
- `BackendMode`
- `RoleAccessControl`

Cualquier developer que toque sesion, permisos o bootstrap debe revisar ambas zonas y validar cual esta tomando el target al compilar.

---

## Roles de usuario

El sistema trabaja con 4 roles:

- Administrador
- Supervisor
- Cajero
- Almacenero

Normalizacion interna actual:

| Valor crudo | Valor interno |
|---|---|
| `Admin`, `admin`, `Administrador` | `admin` |
| `Super`, `supervisor` | `supervisor` |
| `Cajero` | `cajero` |
| `Almacen`, `almacenero` | `almacen` |

### Administrador

- acceso total
- crea y edita trabajadores
- configura roles y permisos
- ejecuta acciones directas sensibles

### Supervisor

- supervisa operacion
- puede vender
- puede trabajar con clientes
- puede ver tesoreria
- en varios casos debe solicitar aprobacion al admin

### Cajero

- crea ventas
- registra cobros
- trabaja con clientes existentes
- no debe ejecutar acciones sensibles directas

### Almacenero

- opera almacen
- registra movimientos
- trabaja con compras
- las altas sensibles se derivan como solicitud administrativa

---

## Matriz de permisos objetivo

Esta es la matriz de negocio que se busca mantener como referencia de producto.

| Modulo | Administrador | Supervisor | Cajero | Almacenero |
|---|:---:|:---:|:---:|:---:|
| Inicio | ✅ | ✅ | ✅ | ✅ |
| Ventas | ✅ | ✅ | ✅ | ❌ |
| Clientes | ✅ | ✅ | ✅ | ❌ |
| Almacen | ✅ | ✅ | ❌ | ✅ |
| Tesoreria | ✅ | ✅ | ❌ | ❌ |
| Cobros | ✅ | ✅ | ✅ | ❌ |
| Compras | ✅ | ❌ | ❌ | ✅ |
| RRHH | ✅ | ❌ | ❌ | ❌ |

Importante:

- esta tabla es la vision de negocio
- no todas las operaciones internas equivalen a acceso directo
- varias de ellas hoy funcionan como "solicitud al admin"

---

## Matriz operativa real implementada

Esto refleja lo que el codigo hace hoy.

| Accion | Admin | Supervisor | Cajero | Almacenero |
|---|:---:|:---:|:---:|:---:|
| Crear venta | Directo | Directo | Directo | No |
| Solicitar edicion/anulacion de venta | No aplica | Si | Si | No |
| Ver clientes | Si | Si | Si | No |
| Crear cliente | Directo | Solicitud | No | No |
| Cobrar cuotas | Si | Si | Si | No |
| Ver almacen | Si | Si | No | Si |
| Crear producto | Directo | No | No | Solicitud |
| Crear almacen | Directo | No | No | Solicitud |
| Registrar movimientos | Si | Si | No | Si |
| Crear proveedor | Directo | No | No | Solicitud |
| Crear orden de compra | Directo | No | No | Solicitud |
| Cambiar estado de orden de compra | Directo | No | No | Solicitud |
| Tesoreria | Si | Si | No | No |
| RRHH | Directo | No | No | No |

---

## Modulos del sistema

### Inicio

Conceptualmente debe mostrar:

- vendido hoy
- cobrado hoy
- por cobrar
- ventas semanales
- alertas de stock
- actividad reciente

En el codigo actual, gran parte de esa experiencia esta implementada desde el dashboard del cajero y vistas derivadas.

### Ventas

Permite:

- ver ventas
- crear venta
- manejar contado y credito
- generar cuotas

El flujo ya actualiza inventario y, segun el caso, tesoreria y cobros.

### Clientes

Permite:

- ver clientes
- analizar deuda
- ver cuotas
- cobrar cuotas

La creacion esta restringida por rol y, en el caso del supervisor, se envia como solicitud.

### Almacen

Permite:

- ver stock por almacen
- ver productos
- ver movimientos
- registrar entradas, salidas y transferencias

Tambien tiene alertas de stock bajo y consolidacion de stocks para evitar falsas alertas.

### Tesoreria

Permite:

- ver saldo
- ingresos y egresos
- transacciones
- tendencias

Ya se corrigio la logica para que compras recibidas no cuenten como salida de caja hasta que realmente esten pagadas.

### Cobros

Permite:

- ver cuotas pendientes, vencidas y pagadas
- registrar pagos
- actualizar la deuda del cliente

### Compras

Permite:

- ver proveedores
- ver ordenes
- crear ordenes
- recibir ordenes
- actualizar estados

Hoy, para almacenero, varias de esas acciones ya salen como solicitud al admin.

### RRHH

Permite:

- listar trabajadores
- crear trabajador
- editar trabajador
- activar/inactivar
- ver roles y permisos

Quedo reservado a admin.

### Mas

Agrupa:

- Tesoreria
- Cobros
- Compras
- RRHH
- Logout

La visibilidad interna tambien depende del rol.

---

## Automatizaciones y efectos en cascada

### Al registrar una venta

| Modulo afectado | Efecto |
|---|---|
| Almacen | descuento de stock |
| Movimientos | salida de inventario |
| Tesoreria | ingreso si es contado |
| Cliente | aumenta deuda si es credito |
| Cobros | se generan cuotas si es credito |

### Al registrar un cobro

| Modulo afectado | Efecto |
|---|---|
| Cuotas | cambia estado o saldo restante |
| Cliente | reduce deuda |
| Tesoreria | registra ingreso |

### Al recibir una compra

| Modulo afectado | Efecto |
|---|---|
| Almacen | aumenta stock |
| Movimientos | entrada de inventario |
| Tesoreria | egreso financiero cuando corresponde |
| Proveedor | actualiza historico |

---

## Entidades del sistema

### Usuario

Perfil autenticado con acceso a la app.

Campos relevantes usados hoy:

- nombre visible
- email
- rol
- `authUid`
- `userDocumentId`
- estado activo

### Cliente

Campos funcionales:

- nombre
- documento
- telefono
- direccion
- limite de credito
- credito usado
- estado

### Venta

Campos funcionales:

- cliente
- producto
- cantidad
- precio unitario
- total
- metodo de pago
- fecha
- estado

### Producto

Campos funcionales:

- nombre
- precio
- unidad de medida
- stock minimo
- capacidad total
- stock actual consolidado

### Almacen

Campos funcionales:

- nombre
- direccion
- responsable
- activo

### Movimiento de inventario

Campos funcionales:

- tipo
- producto
- almacen
- origen
- destino
- nota
- cantidad
- fecha

### Cuota

Campos funcionales:

- numero
- monto
- pagada
- fecha de vencimiento
- fecha de pago
- venta asociada

### Transaccion

Representada hoy principalmente desde tesoreria y sync remoto.

### Orden de compra

Campos funcionales:

- proveedor
- producto
- almacen
- cantidad
- precio unitario de compra
- total
- estado
- fecha
- nota

### Trabajador

Se modela en RRHH y en acceso remoto.

### Proveedor

Campos funcionales:

- nombre
- categoria
- telefono
- email
- direccion
- calificacion
- preferido
- verificado

---

## Base de datos y colecciones reales

La documentacion conceptual puede hablar de `clients`, `purchases` o `transactions`, pero el codigo hoy usa estas colecciones Firestore:

| Coleccion | Uso actual |
|---|---|
| `users` | perfil de usuario |
| `users_lookup` | lookup por `auth.uid` |
| `roles` | roles y permisos |
| `customers` | clientes |
| `products` | productos |
| `warehouses` | almacenes |
| `warehouse_stock` | stock por almacen |
| `inventory_movements` | movimientos de inventario |
| `sales` | ventas |
| `sale_installments` | cuotas |
| `suppliers` | proveedores |
| `purchase_orders` | ordenes de compra |
| `treasury_transactions` | transacciones de tesoreria |

### Modelo local

Core Data usa:

- `ClienteEntity`
- `ProductoEntity`
- `AlmacenEntity`
- `StockAlmacenEntity`
- `MovimientoInventarioEntity`
- `VentaEntity`
- `CuotaEntity`
- `ProveedorEntity`
- `OrdenCompraEntity`
- `LoginEntity`

---

## Autenticacion y sesion

Archivo principal:

- [LoginViewController.swift](/Users/ginobarrena/Documents/RAVNU_Proyecto/RAVNU_Proyecto/Features/Auth/LoginViewController.swift)

Flujo actual:

1. login por `Firebase Authentication`
2. lectura de `users_lookup/{authUid}`
3. lectura de `users/{userId}`
4. normalizacion de rol
5. persistencia en `AppSession`
6. construccion de tabs segun rol

Campos persistidos en sesion:

- `usuarioLogueado`
- `rolLogueado`
- `userDocumentId`
- `authUid`
- `userEmail`
- `adminAPIAuthToken`
- `remoteDataEnabled`
- `lastRemoteSyncAt`

Logout:

- se limpia `AppSession`
- se ejecuta cierre de sesion general

---

## Solicitudes administrativas por API

Servicio:

- [AdminRequestService.swift](/Users/ginobarrena/Documents/RAVNU_Proyecto/RAVNU_Proyecto/Infrastructure/AdminRequestService.swift)

La app ya esta preparada para integrarse con la web administrativa por API.

### Configuracion en Info.plist

[Info.plist](/Users/ginobarrena/Documents/RAVNU_Proyecto/RAVNU_Proyecto/Info.plist) ahora incluye:

- `AdminRequestsAPIBaseURL`
- `AdminRequestsAPIRequestsPath`
- `AdminRequestsAuthMode`

Ejemplo:

```xml
<key>AdminRequestsAPIBaseURL</key>
<string>https://tu-backend.example.com</string>
<key>AdminRequestsAPIRequestsPath</key>
<string>admin/requests</string>
<key>AdminRequestsAuthMode</key>
<string>firebase_id_token</string>
```

### Modos de autenticacion soportados

- `none`
- `bearer_token`
- `firebase_id_token`

### Payload base

Todas las solicitudes siguen esta estructura:

```json
{
  "requestId": "uuid",
  "type": "cancel_sale",
  "module": "ventas",
  "status": "pending",
  "requestedBy": {
    "userId": "user-id",
    "authUid": "firebase-auth-uid",
    "fullName": "Usuario",
    "roleId": "cajero",
    "email": "usuario@ravnu.com"
  },
  "target": {
    "entity": "sale",
    "entityId": "sale-id"
  },
  "payload": {},
  "reason": "Motivo",
  "createdAt": "2025-01-01T00:00:00Z",
  "reviewedAt": null,
  "reviewedBy": null,
  "rejectionReason": null
}
```

### Tipos ya implementados

- `create_customer`
- `create_product`
- `create_warehouse`
- `create_supplier`
- `create_purchase_order`
- `update_purchase_order_status`
- `edit_sale`
- `cancel_sale`

### Respuesta esperada

```json
{
  "success": true,
  "requestId": "uuid",
  "status": "pending",
  "message": "Solicitud registrada"
}
```

### Lo que ya hace la app

- envia la solicitud
- maneja header `Authorization` si corresponde
- interpreta respuesta tipada
- guarda cache local de solicitudes
- expone base para `fetchMyRequests(status:)`

### Lo que aun falta

- pantalla `Mis solicitudes`
- aprobacion/rechazo desde la web
- feedback de estado devuelto al usuario en la app

---

## Navegacion por rol

Archivo:

- [RoleTabBarController.swift](/Users/ginobarrena/Documents/RAVNU_Proyecto/RAVNU_Proyecto/App/RoleTabBarController.swift)

### Tabs visibles

| Rol | Tabs visibles |
|---|---|
| Admin | Inicio, Ventas, Clientes, Almacen, Mas |
| Supervisor | Inicio, Ventas, Clientes, Almacen, Mas |
| Cajero | Inicio, Ventas, Clientes, Mas |
| Almacenero | Inicio, Almacen, Mas |

### Tarjetas visibles dentro de Mas

Controladas desde:

- [MasViewController.swift](/Users/ginobarrena/Documents/RAVNU_Proyecto/RAVNU_Proyecto/Features/Mas/MasViewController.swift)
- [MoreDashboardView.swift](/Users/ginobarrena/Documents/RAVNU_Proyecto/RAVNU_Proyecto/Features/Mas/MoreDashboardView.swift)

Visibilidad:

- Tesoreria: `canViewTreasury`
- Cobros: `canManageCollections`
- Compras: `canManagePurchases`
- RRHH: `isAdmin`

---

## Estado real por modulo

### Auth

Estado:

- funcional con Firebase
- depende de `users_lookup` y `users`
- ya persiste sesion y rol

### Inicio / Cajero

Archivo clave:

- [CajeroViewController.swift](/Users/ginobarrena/Documents/RAVNU_Proyecto/RAVNU_Proyecto/Features/Cajero/CajeroViewController.swift)

Estado:

- dashboard implementado
- ventas del dia
- cobrado del dia
- pendientes
- ventas ultimos 7 dias
- alertas de stock bajo consolidadas

### Ventas

Estado:

- nueva venta directa
- contado / credito
- cuotas
- impacto en inventario
- solicitud de edicion/anulacion

### Clientes

Estado:

- lista y analitica
- creacion directa por admin
- solicitud para supervisor
- cajero no puede agregar
- cobros funcionales

### Almacen

Estado:

- dashboard
- productos
- movimientos
- creacion de producto y almacen por solicitud para almacenero
- responsable de almacen ligado a usuarios reales

### Compras

Estado:

- dashboard
- proveedores
- ordenes
- solicitudes para almacenero
- acciones directas para admin

### Tesoreria

Estado:

- dashboard y transacciones funcionales
- corregida logica de compras pagadas vs recibidas

### RRHH

Estado:

- solo admin
- alta
- edicion
- activar/inactivar
- consolidacion de duplicados

---

## Setup de desarrollo

### Requisitos

- Xcode
- proyecto iOS compilando con target actual
- `GoogleService-Info.plist` valido
- Firebase Authentication
- Firestore configurado

### Requisitos para login remoto

Debe existir:

1. usuario en Firebase Authentication
2. documento en `users`
3. documento en `users_lookup`
4. roles remotos coherentes

### Requisitos para solicitudes administrativas

1. `AdminRequestsAPIBaseURL` configurado
2. backend escuchando `POST /admin/requests`
3. modo de auth definido
4. si se usa `bearer_token`, setear `adminAPIAuthToken`
5. si se usa `firebase_id_token`, usuario autenticado con Firebase

---

## Deudas tecnicas y limitaciones conocidas

- duplicidad de infraestructura entre `AppDelegate.swift` e `Infrastructure/`
- falta pantalla de seguimiento de solicitudes
- faltan tests automatizados
- backend administrativo aun no implementado en este repo
- seguridad final no puede depender solo de la UI
- no todos los flujos sensibles estan modelados todavia como solicitud
- existe al menos un warning viejo en `ModalAlmacenViewController` por API deprecated de `UIBarButtonItem`

---

## Roadmap recomendado

Orden sugerido para seguir:

1. backend/web administrativa real
2. bandeja `Mis solicitudes` en la app
3. aprobacion/rechazo con refresco de estado
4. endurecimiento de permisos en backend y Firestore Rules
5. terminar ediciones sensibles:
   - cliente
   - producto
   - proveedor
   - orden de compra
6. limpieza de duplicidad de infraestructura
7. tests end-to-end de negocio

