# RAVNU Firebase Backend Spec

## Objetivo

Migrar el sistema desde persistencia local en Core Data a una arquitectura centralizada en Firebase.

Firebase no es solo base de datos. En este caso debe cubrir:

- autenticacion
- base de datos operativa
- backend de reglas
- permisos
- auditoria

La recomendacion correcta para este proyecto es:

- `Firebase Auth` para login
- `Cloud Firestore` para datos
- `Cloud Functions` para logica de negocio critica
- `Firebase Storage` solo si luego guardas archivos o documentos

---

## Estado actual del app

Hoy la app iOS:

- usa `Core Data`
- hace consultas directas desde los `ViewController`
- guarda usuarios localmente
- guarda contrasenas en texto plano
- mezcla administracion y operacion

Eso significa que **no existe una capa de backend real todavia**.

---

## Que seria "el backend" en Firebase

En este proyecto, el backend no debe ser solo Firestore.

Debe ser:

## 1. Firebase Auth

Para:

- login de trabajadores
- manejo de sesiones
- recuperacion de acceso
- control de usuarios activos/inactivos

## 2. Cloud Firestore

Para:

- trabajadores
- roles
- permisos
- clientes
- productos
- almacenes
- stock por almacen
- proveedores
- ordenes de compra
- ventas
- cuotas
- movimientos de inventario
- transacciones de tesoreria

## 3. Cloud Functions

Para:

- validar permisos
- validar credito disponible
- validar stock disponible
- generar cuotas al crear una venta a credito
- actualizar `creditoUsado`
- actualizar stock consolidado
- registrar movimientos automáticos
- registrar gastos / ingresos en tesoreria
- registrar auditoria

Sin `Cloud Functions`, terminarias metiendo logica critica en la app y en la web, duplicada.

---

## Colecciones recomendadas

## `stations`

Representa la estacion o sede.

Campos:

- `id`
- `name`
- `code`
- `address`
- `phone`
- `active`
- `createdAt`
- `updatedAt`

## `employees`

Perfil del trabajador.

Campos:

- `id`
- `firstName`
- `lastName`
- `fullName`
- `documentType`
- `documentNumber`
- `phone`
- `email`
- `address`
- `position`
- `stationId`
- `roleId`
- `active`
- `createdAt`
- `updatedAt`
- `createdBy`
- `updatedBy`

## `users`

Cuenta de acceso. Debe estar enlazada a Firebase Auth.

Campos:

- `id`
- `authUid`
- `employeeId`
- `username`
- `email`
- `roleId`
- `active`
- `mustChangePassword`
- `lastLoginAt`
- `createdAt`
- `updatedAt`

## `roles`

Campos:

- `id`
- `code`
- `name`
- `description`
- `active`

Valores iniciales:

- `Admin`
- `Super`
- `Cajero`
- `Almacen`

## `role_permissions`

Campos:

- `id`
- `roleId`
- `module`
- `canView`
- `canCreate`
- `canEdit`
- `canDelete`
- `canChangeStatus`
- `canApprove`

Modulos:

- `inicio`
- `ventas`
- `clientes`
- `almacen`
- `tesoreria`
- `cobros`
- `compras`
- `rrhh`

## `clients`

Campos:

- `id`
- `name`
- `documentType`
- `documentNumber`
- `phone`
- `address`
- `creditLimit`
- `creditUsed`
- `active`
- `createdAt`
- `updatedAt`
- `createdBy`
- `updatedBy`

## `products`

Campos:

- `id`
- `name`
- `type`
- `unitMeasure`
- `pricePerUnit`
- `minimumStock`
- `totalStock`
- `capacityTotal`
- `active`
- `createdAt`
- `updatedAt`
- `createdBy`
- `updatedBy`

## `warehouses`

Campos:

- `id`
- `name`
- `address`
- `managerName`
- `stationId`
- `active`
- `createdAt`
- `updatedAt`

## `warehouse_stock`

Campos:

- `id`
- `warehouseId`
- `productId`
- `currentStock`
- `minimumStock`
- `capacityTotal`
- `unitMeasure`
- `updatedAt`

## `suppliers`

Campos:

- `id`
- `name`
- `documentNumber`
- `phone`
- `email`
- `contactName`
- `active`
- `createdAt`
- `updatedAt`

## `purchase_orders`

Campos:

- `id`
- `supplierId`
- `warehouseId`
- `productId`
- `quantity`
- `unitPrice`
- `total`
- `status`
- `notes`
- `createdAt`
- `updatedAt`
- `createdBy`
- `updatedBy`
- `receivedAt`
- `receivedBy`

Estados sugeridos:

- `draft`
- `pending`
- `approved`
- `received`
- `cancelled`

## `sales`

Campos:

- `id`
- `clientId`
- `productId`
- `warehouseId`
- `quantity`
- `unitPrice`
- `total`
- `paymentMethod`
- `status`
- `createdAt`
- `updatedAt`
- `createdBy`
- `updatedBy`

Estados sugeridos:

- `paid`
- `pending`
- `cancelled`

Metodos:

- `cash`
- `credit`

## `sale_installments`

Campos:

- `id`
- `saleId`
- `clientId`
- `number`
- `amount`
- `dueDate`
- `paid`
- `paidAt`
- `status`
- `createdAt`
- `updatedAt`

Estados:

- `pending`
- `overdue`
- `paid`

## `inventory_movements`

Campos:

- `id`
- `type`
- `warehouseId`
- `targetWarehouseId`
- `productId`
- `quantity`
- `source`
- `destination`
- `notes`
- `referenceType`
- `referenceId`
- `createdAt`
- `createdBy`

Tipos:

- `entry`
- `exit`
- `transfer`

## `treasury_transactions`

Campos:

- `id`
- `type`
- `category`
- `amount`
- `referenceType`
- `referenceId`
- `description`
- `createdAt`
- `createdBy`

Tipos:

- `income`
- `expense`

## `audit_logs`

Campos:

- `id`
- `userId`
- `employeeId`
- `module`
- `action`
- `entityType`
- `entityId`
- `summary`
- `previousData`
- `newData`
- `createdAt`

---

## Reglas criticas que deben ir en Cloud Functions

## Crear venta

Debe:

- validar usuario y permiso
- validar que cliente exista y este activo
- validar que producto exista y este activo
- validar stock suficiente
- validar credito si es venta a credito
- crear venta
- generar cuotas si aplica
- descontar stock
- registrar movimiento inventario
- registrar ingreso en tesoreria si corresponde
- registrar auditoria

## Registrar cobro

Debe:

- validar permiso
- validar que cuota este pendiente
- marcar cuota pagada
- actualizar credito del cliente
- cerrar venta si todas las cuotas estan pagadas
- registrar ingreso en tesoreria
- registrar auditoria

## Recibir orden de compra

Debe:

- validar permiso
- cambiar estado de orden
- sumar stock al almacen
- actualizar stock consolidado
- registrar movimiento tipo entrada
- registrar gasto en tesoreria
- registrar auditoria

## Crear o editar trabajador

Debe:

- validar rol del actor
- crear empleado
- crear usuario Auth si aplica
- asignar rol
- registrar auditoria

---

## Reglas de seguridad sugeridas

En Firestore Rules:

- el usuario solo lee lo que su rol permite
- solo `Admin` administra trabajadores, roles y permisos
- solo `Admin` y `Super` ven tesoreria
- solo `Admin` y `Almacen` gestionan compras
- solo `Admin`, `Super`, `Cajero` gestionan cobros

Las reglas complejas no deben vivir solo en Firestore Rules. La parte pesada debe ir en Cloud Functions.

---

## Migracion del app iOS

La migracion correcta del app no es reemplazar Core Data por Firebase en una sola pasada.

Hazlo en este orden:

## Fase 1

- configurar Firebase en iOS
- integrar Auth
- mantener Core Data intacto
- crear capa `Repository` para desacoplar la UI

## Fase 2

- migrar login
- migrar lectura de clientes
- migrar lectura de productos
- migrar lectura de almacenes

## Fase 3

- migrar ventas
- migrar cuotas
- migrar compras
- migrar inventario

## Fase 4

- dejar Core Data solo como cache offline si quieres
- quitar logica de persistencia local directa de los controladores

---

## Bloqueos reales para completar la migracion ya

No se puede terminar una migracion completa de forma segura dentro del proyecto actual sin:

1. un proyecto Firebase creado
2. `GoogleService-Info.plist`
3. decidir si usaras solo Firebase o Firebase + Cloud Functions
4. decidir si Core Data quedara como cache offline
5. mover la logica fuera de los ViewController

---

## Decision recomendada

Si quieres hacerlo bien:

- la web admin crea y administra todo
- la app movil opera y consulta
- Firebase Auth + Firestore + Functions es tu backend
- Core Data puede quedar luego como cache, no como fuente de verdad
