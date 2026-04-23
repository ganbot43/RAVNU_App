# RAVNU Admin Web - Functional Specification

## Objetivo

Migrar la administracion del sistema desde datos locales en la app iOS a una web administrativa centralizada, idealmente sobre Firebase.

La web admin sera la fuente de verdad para:

- trabajadores
- credenciales
- roles y permisos
- clientes
- productos
- almacenes
- proveedores
- ordenes de compra
- estados de registros
- configuracion general de la estacion

La app movil quedara principalmente como cliente operativo y de contingencia.

---

## Roles actuales del sistema

Los valores reales usados hoy en la app son:

- `Admin`
- `Super`
- `Cajero`
- `Almacen`

### Acceso por tabs

- `Admin`: Inicio, Ventas, Clientes, Almacen, Mas
- `Super`: Inicio, Ventas, Clientes, Almacen, Mas
- `Cajero`: Inicio, Ventas, Clientes, Mas
- `Almacen`: Inicio, Almacen, Mas

### Acceso por modulos dentro de "Mas"

- Tesoreria: `Admin`, `Super`
- Cobros: `Admin`, `Super`, `Cajero`
- Compras: `Admin`, `Almacen`
- RRHH: `Admin`

---

## Entidades actuales del app

## 1. LoginEntity

Campos:

- `id: UUID`
- `usuario: String`
- `contrasena: String`
- `rol: String`

Uso actual:

- autenticacion local
- seleccion de rol al ingresar

## 2. ClienteEntity

Campos:

- `id: UUID`
- `nombre: String`
- `documento: String`
- `telefono: String`
- `direccion: String`
- `limiteCredito: Double`
- `creditoUsado: Double`
- `activo: Bool`

Relaciones:

- `ventas -> VentaEntity[]`

## 3. ProductoEntity

Campos:

- `id: UUID`
- `nombre: String`
- `tipo: String`
- `unidadMedida: String`
- `precioPorLitro: Double`
- `stockMinimo: Double`
- `stockLitros: Double`
- `capacidadTotal: Double`
- `activo: Bool`

Relaciones:

- `ventas -> VentaEntity[]`
- `movimientos -> MovimientoInventarioEntity[]`
- `ordenesCompra -> OrdenCompraEntity[]`
- `stocks -> StockAlmacenEntity[]`

## 4. VentaEntity

Campos:

- `id: UUID`
- `fechaVenta: Date`
- `cantidadLitros: Double`
- `precioUnitario: Double`
- `total: Double`
- `metodoPago: String`
- `estado: String`

Relaciones:

- `cliente -> ClienteEntity`
- `producto -> ProductoEntity`
- `cuotas -> CuotaEntity[]`

Estados actuales usados:

- `pagada`
- `pendiente`

Metodos de pago actuales:

- `efectivo`
- `credito`

## 5. CuotaEntity

Campos:

- `id: UUID`
- `numero: Int`
- `monto: Double`
- `fechaVencimiento: Date`
- `fechaPago: Date`
- `pagada: Bool`

Relaciones:

- `venta -> VentaEntity`

## 6. AlmacenEntity

Campos:

- `id: UUID`
- `nombre: String`
- `direccion: String`
- `responsable: String`
- `activo: Bool`

Relaciones:

- `movimientos -> MovimientoInventarioEntity[]`
- `ordenesCompra -> OrdenCompraEntity[]`
- `stocks -> StockAlmacenEntity[]`

## 7. StockAlmacenEntity

Campos:

- `id: UUID`
- `stockActual: Double`
- `stockMinimo: Double`
- `capacidadTotal: Double`
- `unidadMedida: String`

Relaciones:

- `almacen -> AlmacenEntity`
- `producto -> ProductoEntity`

## 8. MovimientoInventarioEntity

Campos:

- `id: UUID`
- `fecha: Date`
- `tipo: String`
- `cantidadLitros: Double`
- `origen: String`
- `destino: String`
- `nota: String`

Relaciones:

- `almacen -> AlmacenEntity`
- `producto -> ProductoEntity`

Tipos actuales:

- `entrada`
- `salida`
- `transfer`

## 9. ProveedorEntity

Campos:

- `id: UUID`
- `nombre: String`
- `documento: String`
- `telefono: String`
- `activo: Bool`

Relaciones:

- `ordenesCompra -> OrdenCompraEntity[]`

## 10. OrdenCompraEntity

Campos:

- `id: UUID`
- `fecha: Date`
- `cantidadLitros: Double`
- `total: Double`
- `estado: String`

Relaciones:

- `almacen -> AlmacenEntity`
- `producto -> ProductoEntity`
- `proveedor -> ProveedorEntity`

Estados actuales inferidos:

- `pendiente`
- `recibida`
- `completada`
- `cancelada`

---

## Logica de negocio actual del app

## Clientes

La app movil hoy puede:

- crear cliente
- listar clientes
- buscar clientes

Reglas actuales:

- nombre obligatorio
- documento obligatorio
- limite de credito no negativo
- se crea `activo = true`
- `creditoUsado = 0`

## Ventas

La app movil hoy puede:

- crear venta
- listar ventas
- calcular resumen

Reglas actuales:

- cliente obligatorio
- producto obligatorio
- cantidad > 0
- valida stock disponible
- si es credito valida que no exceda limite de credito
- si es efectivo la venta queda `pagada`
- si es credito la venta queda `pendiente`
- al vender se descuenta stock
- se registra movimiento inventario tipo `salida`

## Cuotas / Cobros

La app movil hoy puede:

- listar cuotas pendientes
- registrar pago de cuota

Reglas actuales:

- el pago debe cubrir la cuota completa
- al pagar:
  - `pagada = true`
  - se registra `fechaPago`
  - baja `creditoUsado`
  - si todas las cuotas estan pagadas, la venta queda `pagada`

## Almacen

La app movil hoy puede:

- crear almacen
- crear producto
- registrar movimiento inventario
- ver stock por almacen

Reglas actuales:

- al crear almacen:
  - se crean stocks iniciales en 0 para cada producto existente
- al crear producto:
  - se crean stocks iniciales en 0 para cada almacen existente
- movimientos:
  - `entrada`: suma stock
  - `salida`: resta stock
  - `transfer`: resta en origen y suma en destino

## Compras

La app movil hoy puede:

- listar proveedores
- listar ordenes
- hacer analitica basica

Pero hoy no existe un flujo admin completo para:

- crear proveedor desde interfaz robusta
- crear orden de compra completa con aprobaciones
- editar estados de orden con trazabilidad

## Tesoreria

Se construye desde:

- ingresos = ventas + cuotas pagadas
- gastos = ordenes de compra

---

## Cambio de enfoque propuesto

## Lo que debe pasar a la web admin

Todo lo administrativo debe vivir en la web:

- crear trabajadores
- editar trabajadores
- activar o desactivar trabajadores
- asignar credenciales
- cambiar contrasenas
- asignar rol
- editar permisos por rol
- crear clientes
- editar clientes
- bloquear clientes
- crear productos
- editar productos
- cambiar precios
- cambiar stock minimo
- cambiar capacidad
- activar o desactivar productos
- crear almacenes
- editar almacenes
- activar o desactivar almacenes
- crear proveedores
- editar proveedores
- activar o desactivar proveedores
- crear ordenes de compra
- editar ordenes de compra
- cambiar estado de orden
- aprobar recepcion
- administrar configuracion general

## Lo que puede quedar en app movil

- login
- ver informacion operativa
- registrar ventas
- registrar cobros
- consultar clientes
- consultar stock
- registrar movimientos operativos si el rol lo permite

Si quieres una operacion mas controlada, incluso la creacion de ventas y cobros puede validarse con reglas backend.

---

## Pantalla de Trabajadores para la web admin

Esta pantalla es clave porque en tu flujo el Administrador gestiona al personal desde la web.

## Objetivo

Permitir al Admin:

- crear trabajador
- editar trabajador
- cambiar estado
- asignar credenciales
- asignar rol
- definir acceso a modulos

## Tabla sugerida

Columnas:

- Nombre completo
- Documento
- Telefono
- Correo
- Usuario
- Rol
- Estado
- Estacion
- Ultimo acceso
- Acciones

## Formulario de trabajador

Campos minimos:

- nombres
- apellidos
- documento
- telefono
- correo
- direccion
- usuario
- password temporal o reset
- rol
- estacion asignada
- activo

Campos recomendados:

- fechaIngreso
- cargo
- observaciones
- fotoUrl

## Acciones por trabajador

- crear
- editar
- activar
- desactivar
- resetear contrasena
- cambiar rol
- ver permisos efectivos
- ver historial de cambios

## Modelo recomendado

### employees

- `id`
- `firstName`
- `lastName`
- `fullName`
- `documentNumber`
- `phone`
- `email`
- `address`
- `stationId`
- `roleId`
- `position`
- `active`
- `createdAt`
- `updatedAt`
- `createdBy`
- `updatedBy`

### users

- `id`
- `employeeId`
- `username`
- `email`
- `active`
- `roleId`
- `lastLoginAt`
- `mustChangePassword`
- `createdAt`
- `updatedAt`

La autenticacion no deberia guardar password plano. Para Firebase usa `Firebase Auth`.

---

## Pantalla de Roles y Permisos

El Admin debe poder ver una matriz editable.

### Modulos

- inicio
- ventas
- clientes
- almacen
- tesoreria
- cobros
- compras
- rrhh

### Acciones por modulo

- `view`
- `create`
- `edit`
- `delete`
- `change_status`
- `approve`

### Estructura sugerida

#### roles

- `id`
- `code`
- `name`
- `description`
- `active`

#### role_permissions

- `id`
- `roleId`
- `module`
- `canView`
- `canCreate`
- `canEdit`
- `canDelete`
- `canChangeStatus`
- `canApprove`

---

## Pantallas sugeridas para la web admin

## 1. Dashboard admin

- resumen de ventas
- cobros pendientes
- stock bajo
- compras pendientes
- trabajadores activos

## 2. Trabajadores

- tabla
- filtros
- formulario modal o pagina detalle

## 3. Roles y permisos

- matriz editable

## 4. Clientes

- listado
- alta
- edicion
- cambio de estado

## 5. Productos

- listado
- alta
- edicion
- cambio de precio
- stock minimo
- capacidad
- estado

## 6. Almacenes

- listado
- alta
- edicion
- responsables
- estado

## 7. Inventario

- stock por almacen
- movimientos
- alertas de stock bajo

## 8. Proveedores

- listado
- alta
- edicion
- estado

## 9. Ordenes de compra

- listado
- crear orden
- editar
- cambiar estado
- recepcionar

## 10. Ventas

- listado historico
- filtros
- detalle

## 11. Cobros / Cuotas

- listado de cuotas
- vencidas
- pendientes
- pagadas

## 12. Tesoreria

- ingresos
- gastos
- balance
- detalle de transacciones

## 13. Configuracion

- datos de la estacion
- parametros globales

## 14. Auditoria

- historial de cambios
- usuario
- fecha
- accion
- entidad afectada

---

## Modelo recomendado para Firebase

## Servicios

- Firebase Auth
- Cloud Firestore
- Cloud Functions
- Storage si luego necesitas archivos

## Colecciones sugeridas

- `stations`
- `employees`
- `users`
- `roles`
- `role_permissions`
- `clients`
- `products`
- `warehouses`
- `warehouse_stock`
- `sales`
- `sale_installments`
- `inventory_movements`
- `suppliers`
- `purchase_orders`
- `treasury_transactions`
- `audit_logs`

---

## Reglas de backend recomendadas

Estas reglas no deberian quedar solo en frontend:

- validar limite de credito
- validar stock disponible
- generar cuotas automaticamente
- actualizar `creditoUsado`
- actualizar stock consolidado
- registrar movimientos de inventario
- crear transacciones de tesoreria
- registrar auditoria
- validar permisos por rol

Eso conviene hacerlo con `Cloud Functions`.

---

## Observaciones importantes del estado actual

1. Hoy las credenciales estan locales y en texto plano. Eso no sirve para produccion.
2. Hoy la matriz de permisos esta hardcodeada en la app.
3. Hoy falta entidad real de trabajador/empleado.
4. Hoy la app mezcla administracion y operacion.
5. La web admin deberia separar claramente:
   - configuracion
   - administracion
   - operacion

---

## Recomendacion de migracion

## Fase 1

- crear web admin
- crear entidades en Firestore
- crear login real con Firebase Auth
- crear pantalla Trabajadores
- crear Roles y Permisos

## Fase 2

- migrar Clientes
- migrar Productos
- migrar Almacenes
- migrar Proveedores

## Fase 3

- migrar Ordenes de Compra
- migrar Ventas
- migrar Cuotas
- migrar Tesoreria

## Fase 4

- hacer que la app iOS lea desde Firebase
- dejar Core Data como cache offline si quieres

---

## Decision funcional recomendada

La web debe ser quien administre:

- altas
- ediciones
- estados
- permisos
- credenciales

La app movil debe enfocarse en:

- consulta
- venta
- cobro
- operacion de campo

Eso te va a evitar duplicar logica y te deja un flujo mucho mas limpio.
