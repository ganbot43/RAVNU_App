# ⛽ RAVNU — Sistema de Gestión de Estaciones de Combustible

Aplicación móvil nativa iOS para la administración integral de estaciones de servicio. Centraliza operaciones, inventario, finanzas, crédito de clientes y gestión de personal en una sola plataforma, con acceso diferenciado por rol y sincronización en tiempo real con Firebase.

---

## Tabla de Contenidos

1. [¿Qué es RAVNU?](#qué-es-ravnu)
2. [Stack Tecnológico](#stack-tecnológico)
3. [Roles de Usuario](#roles-de-usuario)
4. [Matriz de Permisos](#matriz-de-permisos)
5. [Módulos del Sistema](#módulos-del-sistema)
   - [Inicio — Dashboard](#-inicio--dashboard)
   - [Ventas](#-ventas)
   - [Clientes](#-clientes)
   - [Almacén](#-almacén)
   - [Tesorería](#-tesorería)
   - [Cobros](#-cobros)
   - [Compras](#-compras)
   - [RRHH](#-rrhh)
6. [Automatizaciones — Efectos en Cascada](#automatizaciones--efectos-en-cascada)
7. [Entidades del Sistema](#entidades-del-sistema)
8. [Proveedores](#proveedores)
9. [Almacenes](#almacenes)
10. [Productos de Combustible](#productos-de-combustible)
11. [Estados del Sistema](#estados-del-sistema)
12. [Base de Datos — Firebase Firestore](#base-de-datos--firebase-firestore)
13. [Autenticación y Sesión](#autenticación-y-sesión)
14. [Diseño Visual](#diseño-visual)
15. [Prototipo Web de Referencia](#prototipo-web-de-referencia)
16. [Estado del Proyecto](#estado-del-proyecto)

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
| Interfaz de usuario | UIKit + Storyboard (Interface Builder) |
| Arquitectura | MVC con capa de servicios |
| Base de datos | Firebase Firestore (NoSQL en tiempo real) |
| Autenticación | Firebase Authentication (email + contraseña) |
| Almacenamiento de archivos | Firebase Storage (fotos de trabajadores) |
| Lógica de servidor | Firebase Cloud Functions |
| Gráficas | DGCharts |
| Carga de imágenes remotas | Kingfisher |

---

## Roles de Usuario

El sistema tiene exactamente **4 roles**. Cada persona que inicia sesión en la app pertenece a uno de ellos. El rol determina qué módulos puede ver y qué operaciones puede realizar.

---

### 🛡️ Administrador

Control total del sistema. Es el único rol que puede:
- Ver y modificar la **matriz de permisos** de todos los roles
- Dar de alta, editar y eliminar trabajadores
- Acceder a todos los módulos sin restricción: ventas, clientes, almacén, tesorería, cobros, compras y RRHH
- Configurar la estación y sus datos generales

Es el perfil del dueño o gerente de la estación.

---

### 👁️ Supervisor

Perfil de supervisión operativa y financiera. Puede:
- Registrar y revisar ventas
- Gestionar clientes y sus líneas de crédito
- Controlar el inventario del almacén
- Ver el estado de la tesorería
- Registrar cobros de cuotas

No puede acceder a compras ni a RRHH.

---

### 💳 Cajero

Perfil enfocado en el punto de venta y atención al cliente. Puede:
- Registrar ventas al contado y a crédito
- Consultar y agregar clientes
- Registrar cobros de cuotas pendientes

No accede a almacén, tesorería, compras ni RRHH.

---

### 📦 Almacenero

Perfil enfocado en el control de inventario y abastecimiento. Puede:
- Ver el stock de todos los almacenes
- Registrar movimientos de inventario (entradas, salidas, transferencias)
- Crear y gestionar órdenes de compra a proveedores
- Confirmar la recepción de mercadería

No accede a ventas, clientes, tesorería, cobros ni RRHH.

---

## Matriz de Permisos

La siguiente tabla muestra el acceso por defecto de cada rol. El **Administrador puede modificar esta matriz** desde el módulo de RRHH → pestaña Roles & Permisos.

| Módulo | Administrador | Supervisor | Cajero | Almacenero |
|---|:---:|:---:|:---:|:---:|
| 🏠 Inicio | ✅ | ✅ | ✅ | ✅ |
| 🛒 Ventas | ✅ | ✅ | ✅ | ❌ |
| 👥 Clientes | ✅ | ✅ | ✅ | ❌ |
| 📦 Almacén | ✅ | ✅ | ❌ | ✅ |
| 💰 Tesorería | ✅ | ✅ | ❌ | ❌ |
| 💳 Cobros | ✅ | ✅ | ✅ | ❌ |
| 🚚 Compras | ✅ | ❌ | ❌ | ✅ |
| 👤 RRHH | ✅ | ❌ | ❌ | ❌ |

La barra de navegación inferior muestra únicamente los tabs a los que el usuario tiene acceso. El tab **Más** siempre es visible porque agrupa módulos secundarios como tesorería, cobros, compras y RRHH — pero dentro de Más, cada tarjeta de módulo también se oculta si el rol no tiene permiso.

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
Barras con las ventas de los últimos 7 días (Lun–Dom), con la barra del día más alto destacada. Permite identificar de un vistazo los días de mayor actividad.

**Alertas de stock bajo:**
Se muestra automáticamente cuando algún combustible está por debajo de su nivel mínimo configurado. La alerta incluye el nombre del producto y el stock restante.

**Cliente con mayor deuda:**
Muestra el cliente con la deuda activa más alta, su estado (Vencido, En Riesgo) y un botón de acceso directo a su detalle.

**Feed de actividad reciente:**
Registro de las últimas acciones realizadas en el sistema (ventas registradas, pagos cobrados, stock recibido, etc.) con el módulo afectado y el impacto de cada acción.

---

### 🛒 Ventas

Módulo para registrar y consultar todas las ventas de combustible.

**Lista de ventas:**
Muestra todas las ventas registradas con nombre del cliente, producto, cantidad en litros/balones, total en soles, tipo de pago (contado o crédito) y fecha. Incluye búsqueda por nombre de cliente o producto.

**Resumen estadístico:**
Encima de la lista se muestran indicadores rápidos: total vendido, cantidad de ventas al contado vs crédito, y gráficas de tendencia por producto y por período.

**Registrar una nueva venta:**
Se abre desde el botón flotante (+). El formulario solicita:

| Campo | Descripción |
|---|---|
| Cliente | Selección de la lista de clientes registrados |
| Producto | Selección del catálogo de combustibles |
| Cantidad | Litros o balones a despachar |
| Total | Se calcula automáticamente (cantidad × precio del producto) |
| Tipo de pago | Contado o Crédito |

Si se selecciona **Crédito**, se habilita una sección adicional:

| Campo | Descripción |
|---|---|
| Número de cuotas | Cantidad de pagos en los que se dividirá la deuda |
| Monto por cuota | Se calcula automáticamente (total ÷ cuotas) |
| Fecha del primer vencimiento | Fecha desde la que se genera el calendario de cuotas |
| Disponibilidad del cliente | Muestra el crédito disponible y el estado actual del cliente |

Al guardar la venta, el sistema ejecuta automáticamente:
1. Descuenta el stock del almacén correspondiente.
2. Registra un movimiento de salida en el historial del almacén.
3. Si es **contado**: registra un ingreso en Tesorería.
4. Si es **crédito**: genera las cuotas en Cobros y actualiza la deuda del cliente.

---

### 👥 Clientes

Directorio completo de clientes con control de crédito y seguimiento de deuda.

**Lista de clientes:**
Muestra nombre, tipo de documento (DNI o RUC), número de documento, teléfono, estado y deuda actual. Tiene filtros por estado: Todos / Activo / En Riesgo / Vencido / Bloqueado.

**Estados de un cliente:**

| Estado | Condición | Color |
|---|---|---|
| ✅ Activo | Sin deuda o deuda dentro del límite sin cuotas vencidas | Verde |
| ⚠️ En Riesgo | La deuda supera el 50% del límite de crédito | Naranja |
| 🔴 Vencido | Tiene al menos una cuota vencida sin pagar | Rojo |
| 🚫 Bloqueado | Límite de crédito superado | Gris |

**Agregar un nuevo cliente:**
Formulario con: nombre o razón social, tipo de documento (DNI/RUC), número de documento, teléfono, email, dirección y límite de crédito asignado.

**Detalle del cliente:**
Al tocar un cliente se accede a su ficha completa:

- **3 indicadores**: Deuda actual / Crédito disponible / Límite asignado.
- **Barra de uso de crédito**: muestra visualmente el porcentaje utilizado del límite.
- **Historial de compras a crédito**: lista de todas las ventas en modalidad crédito del cliente.
- **Cuotas**: lista de todas las cuotas generadas para ese cliente con su estado (pendiente, vencida, pagada).

---

### 📦 Almacén

Control del inventario de combustible distribuido en múltiples almacenes físicos.

**El sistema maneja 3 almacenes:**

| Almacén | Dirección | Responsable |
|---|---|---|
| Main Station | Av. La Marina 245, Lima | Luis Torres |
| North Depot | Av. Túpac Amaru 890, Lima | Ana Flores |
| South Point | Carretera Central Km 12, Lima | Jorge Salinas |

**Vista de inventario:**
Grid con una tarjeta por producto en cada almacén. Cada tarjeta muestra:
- Nombre del combustible y ícono de tipo
- Stock actual en litros o balones
- Barra de progreso proporcional a la capacidad total del tanque
- Badge de estado: **OK** (verde) o **Stock Bajo** (rojo)

El estado **Stock Bajo** se activa automáticamente cuando el nivel cae por debajo del mínimo configurado para ese producto.

**Vista de Productos:**
Lista completa del catálogo de combustibles con precio por unidad, unidad de medida, stock total consolidado y estado de cada producto.

**Registrar un movimiento:**
El formulario de movimiento solicita:

| Campo | Descripción |
|---|---|
| Tipo | Entrada / Salida / Transferencia |
| Almacén origen | Desde dónde sale el combustible |
| Almacén destino | Solo para Transferencia — a dónde va el combustible |
| Producto | Qué combustible se mueve |
| Cantidad | Litros o balones |
| Nota | Descripción opcional del movimiento |

Los tres tipos de movimiento:
- **Entrada** — combustible que ingresa (compra recibida, ajuste de inventario).
- **Salida** — combustible que sale (despacho manual, merma).
- **Transferencia** — movimiento de stock entre dos almacenes de la misma estación. El stock baja en el origen y sube en el destino simultáneamente.

Todos los movimientos quedan registrados en el historial con fecha, responsable y nota.

---

### 💰 Tesorería

Centro financiero de la estación. Registra todos los movimientos de dinero: entradas y salidas.

**Balance general:**
Banner prominente con el **saldo actual** (ingresos totales − egresos totales), el margen neto del mes en porcentaje, y los montos de ingresos y egresos separados.

**Gráficas:**
- Evolución mensual de ingresos vs egresos (últimos 7 meses).
- Distribución de gastos por categoría: Compras de combustible, Salarios, Mantenimiento, Suministros.

**Filtros de período:** Hoy / Semana / Mes — para ver solo las transacciones del período seleccionado.

**Lista de transacciones:**
Cada transacción muestra: tipo (ingreso ↓ verde / egreso ↑ rojo), descripción, trabajador responsable, monto y fecha.

La mayoría de las transacciones se generan **automáticamente** desde otros módulos:
- Venta al contado → ingreso automático
- Pago de cuota → ingreso automático
- Compra recibida → egreso automático

También se pueden registrar transacciones **manuales** (gastos de mantenimiento, sueldos, ingresos varios) usando el botón flotante (+).

**Formulario de nueva transacción manual:**
Tipo (Ingreso/Egreso), descripción, monto, trabajador responsable y fecha.

---

### 💳 Cobros

Módulo dedicado a la gestión y seguimiento de cuotas de ventas a crédito.

**Resumen de cobros:**

| Indicador | Descripción |
|---|---|
| Vencido | Monto total de cuotas con fecha de vencimiento pasada |
| Pendiente | Monto total de cuotas próximas a vencer |
| Cobrado Hoy | Suma de cuotas cobradas en el día en curso |

**Gráfica de distribución:**
Pastel con la proporción de montos vencidos, pendientes y cobrados hoy.

**Lista de cuotas:**
Filtrable por: Todas / Pendientes / Vencidas / Pagadas. Cada cuota muestra:
- Nombre del cliente
- Número de cuota y total de cuotas de esa venta (ej: "Cuota 2 de 3")
- Monto a cobrar
- Fecha de vencimiento (en rojo si ya venció)
- Estado con badge de color

**Registrar un pago:**
El formulario de cobro permite:
1. Seleccionar al cliente — se muestran automáticamente sus cuotas pendientes y vencidas.
2. Ver el detalle de la cuota seleccionada (monto, fecha de vencimiento, estado).
3. Ingresar el **monto a pagar** — puede ser parcial o total.
4. El sistema calcula en tiempo real: saldo restante de esa cuota y deuda total del cliente después del pago.

Al confirmar el pago:
- La cuota se marca como **Pagada** (o se actualiza su monto restante si es pago parcial).
- La deuda del cliente se reduce automáticamente.
- Se genera un ingreso automático en Tesorería.
- Si la deuda queda en cero, el estado del cliente vuelve a **Activo**.

---

### 🚚 Compras

Gestión de órdenes de compra de combustible a proveedores externos.

**Lista de órdenes:**
Muestra todas las compras con proveedor, producto, cantidad, total, trabajador responsable, fecha y estado actual.

**Estados de una orden de compra:**

| Estado | Descripción | Impacto en stock |
|---|---|---|
| ⏳ Pendiente | La orden fue creada pero el combustible aún no llegó | Sin impacto |
| ✅ Recibida | El combustible ingresó físicamente al almacén | Stock aumenta |
| ❌ Cancelada | La orden fue anulada | Sin impacto |

**Gestión de proveedores:**
Directorio de proveedores con información de contacto, categoría, calificación (1–5 estrellas), total histórico de gasto y última compra. Los proveedores no tienen acceso a la app — son entidades gestionadas internamente.

Los proveedores registrados en el sistema son:

| Proveedor | Categoría | Calificación |
|---|---|---|
| PetroPerú | Estatal | ⭐ 4.5 |
| Repsol | Internacional | ⭐ 4.8 |
| PRIMAX | Cadena nacional | ⭐ 4.2 |
| Pecsa | Nacional | ⭐ 3.9 |

**Registrar una nueva compra:**
Formulario con: producto a comprar, cantidad (litros o balones), precio de compra por unidad (diferente al precio de venta), total auto-calculado, proveedor, almacén de destino y trabajador responsable.

**Flujo completo de una compra:**
1. El almacenero **crea la orden** → queda en estado Pendiente. El stock no cambia.
2. Cuando llega el combustible, el almacenero **confirma la recepción** → el stock del almacén aumenta, se registra un egreso en Tesorería y se actualizan las estadísticas del proveedor.
3. Si la entrega no se realiza, se **cancela la orden** → sin ningún impacto en inventario ni finanzas.

---

### 👤 RRHH

Módulo de gestión del personal de la estación. Organizado en tres pestañas.

---

#### Pestaña Trabajadores

Lista completa del personal con avatar de iniciales, nombre, badge de rol (Cajero / Almacenero / Supervisor), turno y teléfono de contacto.

**Turnos disponibles:**

| Turno | Descripción |
|---|---|
| Turno mañana | Primera parte del día |
| Turno tarde | Segunda parte del día |
| Día completo | Jornada completa |

**Acciones disponibles:**
- **Agregar trabajador** — nombre, teléfono, email, rol y turno.
- **Editar trabajador** — modificar cualquier dato del perfil.
- **Eliminar trabajador** — con confirmación previa. Solo el Administrador puede hacerlo.

El personal actual de la estación en el sistema demo:

| Nombre | Rol | Turno |
|---|---|---|
| Luis Torres | Cajero | Turno mañana |
| Ana Flores | Almacenero | Turno tarde |
| Jorge Salinas | Supervisor | Día completo |

---

#### Pestaña Actividad

Vista del rendimiento del equipo en el período. Muestra para cada trabajador:
- Número de ventas registradas
- Número de cobros realizados
- Estado actual (activo / inactivo)

Incluye un gráfico de barras comparativo entre los trabajadores.

---

#### Pestaña Roles & Permisos

Matriz visual interactiva con los permisos de cada rol sobre cada módulo del sistema.

Funcionamiento:
- Se selecciona el rol a visualizar (Administrador / Supervisor / Cajero / Almacenero).
- Se muestra una lista de los 8 módulos con un toggle ON/OFF para cada uno.
- Si el usuario actual es **Administrador**, puede modificar los toggles y guardar los cambios. Los cambios se aplican en tiempo real.
- Si el usuario es cualquier otro rol, ve la matriz en modo **solo lectura** con un mensaje indicando que solo el Administrador puede modificar permisos.

---

## Automatizaciones — Efectos en Cascada

El principio central de RAVNU es que **registrar algo en un módulo actualiza automáticamente todos los módulos relacionados**. El usuario no necesita ir a varios lugares para reflejar una misma operación.

---

### Al registrar una venta

| Módulo afectado | Qué ocurre |
|---|---|
| Almacén | Se descuenta la cantidad vendida del almacén con más stock de ese producto |
| Historial de almacén | Se crea un movimiento de tipo **Salida** vinculado a esa venta |
| Tesorería (solo contado) | Se registra un ingreso por el monto total de la venta |
| Clientes (solo crédito) | La deuda del cliente aumenta por el total de la venta |
| Cobros (solo crédito) | Se generan automáticamente las cuotas según la cantidad indicada en el formulario |

---

### Al confirmar la recepción de una compra

| Módulo afectado | Qué ocurre |
|---|---|
| Almacén | El stock del almacén de destino aumenta con la cantidad recibida |
| Historial de almacén | Se crea un movimiento de tipo **Entrada** vinculado a esa compra |
| Tesorería | Se registra un egreso por el monto total de la compra |
| Proveedores | Se suma 1 transacción al contador y se actualiza el gasto total del proveedor |
| Feed de actividad | Se registra el evento en el dashboard |

---

### Al registrar un cobro de cuota

| Módulo afectado | Qué ocurre |
|---|---|
| Cobros | La cuota cambia a estado **Pagada** (o se actualiza el monto si fue pago parcial) |
| Clientes | La deuda del cliente se reduce por el monto cobrado |
| Clientes | Si la deuda llega a cero, el estado del cliente cambia automáticamente a **Activo** |
| Tesorería | Se registra un ingreso por el monto cobrado |

---

## Entidades del Sistema

Las entidades son los objetos de datos que estructuran toda la información de RAVNU.

---

### Usuario
Persona con acceso a la aplicación. Tiene credenciales de Firebase Authentication, un rol que determina su acceso, y está asignado a una estación específica. Sus datos se almacenan sincronizados con su cuenta de autenticación.

**Atributos clave:** nombre, email, rol, estación asignada, color de avatar, iniciales, estado activo/inactivo.

---

### Cliente
Persona natural (con DNI) o empresa (con RUC) que compra combustible en la estación, con posibilidad de operar a crédito.

**Atributos clave:** nombre, tipo y número de documento, teléfono, email, dirección, límite de crédito, deuda actual, estado.

La deuda actual se actualiza automáticamente con cada venta a crédito y cada cobro de cuota. El estado se recalcula automáticamente según la relación entre la deuda y el límite, y la existencia de cuotas vencidas.

---

### Venta
Registro de un despacho de combustible a un cliente. Es la entidad central del sistema porque genera efectos en almacén, tesorería y cobros.

**Atributos clave:** cliente, producto, cantidad, precio unitario, total, tipo de pago (contado/crédito), número de cuotas si aplica, trabajador responsable, almacén origen, fecha.

---

### Producto
Combustible disponible en la estación con su precio de venta y límite de stock mínimo para alertas.

**Productos del sistema:**

| Producto | Unidad | Precio venta | Stock mínimo |
|---|---|---|---|
| Gasoline 90 | Litro | S/ 6.20 | 500 L |
| Gasoline 95 | Litro | S/ 7.10 | 400 L |
| Diesel B5 | Litro | S/ 5.90 | 400 L |
| GLP | Balón | S/ 38.00 | 5 bal |

---

### Almacén
Espacio físico de almacenamiento dentro de la estación. Cada almacén tiene capacidades diferentes por producto y un responsable asignado. El stock de cada almacén es independiente y se actualiza en tiempo real.

---

### Movimiento de Almacén
Registro histórico de cada cambio de stock. Todo movimiento — sea generado automáticamente por una venta o compra, o registrado manualmente — queda en el historial con su tipo, cantidad, origen, responsable y fecha.

**Tipos de movimiento:** Entrada (IN) / Salida (OUT) / Transferencia (TRANSFER)
**Orígenes posibles:** Compra / Venta / Movimiento directo

---

### Cuota (Installment)
Pago parcial de una venta a crédito. Cuando se registra una venta a crédito con N cuotas, el sistema genera N documentos de cuota automáticamente, con montos iguales y fechas de vencimiento distribuidas desde la fecha del primer vencimiento indicada.

**Atributos clave:** cliente, venta de origen, número de cuota, total de cuotas, monto, fecha de vencimiento, fecha de pago, estado.

---

### Transacción
Movimiento financiero en tesorería. Puede ser un ingreso o un egreso. La mayoría se generan automáticamente, pero también se pueden registrar manualmente.

**Atributos clave:** tipo (ingreso/egreso), descripción, monto, trabajador responsable, origen (venta / compra / cobro / manual), fecha.

---

### Compra (Purchase Order)
Orden de compra de combustible a un proveedor externo. Tiene un ciclo de vida: se crea como pendiente, se confirma al recibir la mercadería, o se cancela si no se concreta.

**Atributos clave:** producto, cantidad, precio de compra por unidad, total, proveedor, almacén destino, trabajador responsable, estado, fechas de orden y recepción.

---

### Trabajador
Empleado de la estación con rol operativo. Distinto del Usuario: un trabajador puede existir en el sistema sin tener cuenta en la app (por ejemplo, si solo aparece como responsable de movimientos históricos).

**Atributos clave:** nombre, rol operativo (cajero/almacenero/supervisor), turno, teléfono, email, foto de perfil.

---

### Proveedor
Empresa externa que suministra combustible a la estación. **No tiene acceso a la aplicación**. Es una entidad de referencia que se asocia a las órdenes de compra y acumula estadísticas de relación comercial.

**Atributos clave:** nombre, categoría, RUC, teléfono, email, dirección, calificación (1–5 estrellas), gasto total histórico, número de transacciones, última compra.

---

### Matriz de Permisos
Configuración por estación que define qué módulos puede ver y operar cada rol. Se almacena en Firebase y se carga al iniciar sesión. El Administrador puede modificarla en tiempo real desde la app, y los cambios se aplican inmediatamente para todos los usuarios activos.

---

## Proveedores

Los proveedores son empresas externas que suministran los combustibles. Se gestionan dentro del sistema como directorio de contacto y referencia histórica de compras.

**Datos que se registran de cada proveedor:**
- Razón social y RUC
- Categoría (estatal, internacional, cadena nacional, nacional)
- Datos de contacto: teléfono, email, dirección
- Calificación de 1 a 5 estrellas (asignada por el equipo)
- Verificación del proveedor (proveedores confiables marcados como verificados)
- Gasto total histórico acumulado
- Número de transacciones realizadas
- Última compra: producto, monto y fecha

**Lo que NO pueden hacer los proveedores:**
- No tienen usuario en el sistema
- No inician sesión en la app
- No reciben notificaciones automáticas desde la app
- No ven las órdenes de compra generadas

---

## Almacenes

La estación opera con múltiples almacenes físicos. Cada almacén tiene sus propios tanques con capacidades definidas para cada combustible.

El sistema calcula automáticamente el porcentaje de ocupación de cada tanque y emite alertas cuando el stock baja del mínimo configurado para cada producto.

**Acciones disponibles sobre almacenes:**
- Ver el stock actual de cada producto en cada almacén
- Registrar entradas manuales de combustible
- Registrar salidas manuales
- Transferir stock de un almacén a otro
- Ver el historial completo de movimientos de cada almacén

---

## Productos de Combustible

El catálogo de combustibles define los productos que se pueden vender, comprar y almacenar. Cada producto tiene:

- **Nombre** — identificador del combustible
- **Unidad de medida** — Litros (para Gasoline 90, 95 y Diesel B5) o Balones (para GLP)
- **Precio de venta** — precio al cliente, usado para calcular el total de cada venta
- **Stock mínimo** — nivel de alerta. Cuando el stock cae por debajo, se activa la alerta en el Dashboard y en el Almacén
- **Capacidad máxima** — capacidad total del tanque, usada para calcular el porcentaje de ocupación

El **precio de compra** (a proveedores) es independiente del precio de venta y se registra en cada orden de compra, no en el catálogo de productos.

---

## Estados del Sistema

### Estados de Cliente

| Estado | Color | Condición |
|---|---|---|
| Activo | 🟢 Verde | Deuda en cero o dentro del límite, sin cuotas vencidas |
| En Riesgo | 🟠 Naranja | Deuda supera el 50% del límite de crédito asignado |
| Vencido | 🔴 Rojo | Tiene una o más cuotas con fecha de vencimiento superada |
| Bloqueado | ⚫ Gris | Deuda supera el límite de crédito |

### Estados de Cuota

| Estado | Color | Significado |
|---|---|---|
| Pendiente | 🟠 Naranja | Cuota generada, fecha de vencimiento futura |
| Vencido | 🔴 Rojo | Cuota no pagada y fecha de vencimiento superada |
| Pagado | 🟢 Verde | Cuota cobrada completamente |

### Estados de Orden de Compra

| Estado | Color | Significado |
|---|---|---|
| Pendiente | 🟠 Naranja | Orden creada, combustible no recibido aún |
| Recibida | 🟢 Verde | Combustible recibido, stock y tesorería actualizados |
| Cancelada | 🔴 Rojo | Orden anulada, sin impacto en stock ni finanzas |

### Estados de Stock

| Estado | Color | Condición |
|---|---|---|
| OK | 🟢 Verde | Stock por encima del nivel mínimo |
| Stock Bajo | 🔴 Rojo | Stock igual o por debajo del nivel mínimo configurado |

---

## Base de Datos — Firebase Firestore

Firestore es la base de datos principal del sistema. Es una base de datos NoSQL orientada a documentos, con sincronización en tiempo real. Los datos de la app se mantienen actualizados automáticamente en todos los dispositivos sin necesidad de recargar.

### Estructura general

Los datos se organizan en colecciones de primer nivel. Cada documento incluye el campo `stationId` que permite aislar completamente la información de una estación de otra — lo que habilita el soporte multi-estación en el futuro.

| Colección | Contenido |
|---|---|
| `stations` | Estaciones registradas, configuración general y matriz de permisos |
| `users` | Perfiles de usuario vinculados a Firebase Authentication |
| `clients` | Clientes con datos, límite de crédito, deuda y estado |
| `sales` | Ventas con todos sus atributos y referencia al almacén origen |
| `products` | Catálogo de combustibles con precio y stock mínimo |
| `warehouses` | Almacenes con snapshot del stock actual por producto |
| `warehouseMovements` | Historial completo de todos los movimientos de inventario |
| `purchases` | Órdenes de compra con estado y trazabilidad completa |
| `installments` | Cuotas generadas por ventas a crédito |
| `transactions` | Todos los movimientos financieros de tesorería |
| `workers` | Personal de la estación con datos de perfil |
| `suppliers` | Proveedores con historial de compras y estadísticas |

### Escrituras en lote (Batch Writes)

Las operaciones que afectan múltiples colecciones (como registrar una venta) se ejecutan en una **escritura atómica**: o se guardan todos los cambios juntos o no se guarda ninguno. Esto garantiza que el stock, la tesorería y el cliente siempre queden en un estado consistente, incluso si hay un error de red.

### Sincronización en tiempo real

Los módulos críticos (Dashboard, Almacén, Cobros) usan **listeners en tiempo real** de Firestore: cuando otro usuario registra una venta o un cobro, todos los demás ven los datos actualizados automáticamente sin necesidad de refrescar.

### Caché offline

Firebase Firestore tiene caché offline habilitada por defecto. Si el dispositivo pierde conexión, la app puede seguir funcionando con los datos en caché y sincronizará los cambios cuando la conexión se restablezca.

---

## Autenticación y Sesión

El sistema usa **Firebase Authentication con email y contraseña**.

### Proceso de inicio de sesión

1. El usuario ingresa su email y contraseña en la pantalla de login.
2. Firebase verifica las credenciales.
3. Si son correctas, la app carga el perfil del usuario desde Firestore (`users/{uid}`).
4. Se carga la matriz de permisos de la estación (`stations/{stationId}.permissions`).
5. La barra de navegación se construye mostrando únicamente los módulos permitidos para ese rol.
6. El usuario accede al Dashboard.

### Persistencia de sesión

La sesión persiste automáticamente en el dispositivo. Si el usuario cierra y vuelve a abrir la app, sigue autenticado sin necesidad de ingresar sus credenciales nuevamente. El cierre de sesión es explícito desde el botón de logout en el menú **Más**.

### Alta de nuevos usuarios

El Administrador crea primero al trabajador en el módulo de RRHH. Luego se genera la cuenta de Firebase Authentication con el email y una contraseña temporal. El trabajador puede cambiar su contraseña en el primer ingreso.

### Seguridad de datos

Las reglas de seguridad de Firestore validan en el servidor que:
- Solo usuarios autenticados pueden leer o escribir datos.
- Cada usuario solo accede a documentos de su propia estación.
- Las operaciones de escritura están restringidas al rol que corresponde (por ejemplo, solo el Administrador puede modificar los permisos o eliminar trabajadores).

---

## Diseño Visual

El diseño sigue las guías de Human Interface Guidelines de Apple con una paleta de colores propia que comunica semánticamente el estado de cada elemento.

### Paleta de colores

| Color | Hex | Uso en el sistema |
|---|---|---|
| Azul | `#3B82F6` | Acción primaria, tab activo, rol Administrador, Gasoline 90 |
| Verde | `#22C55E` | Pagado, activo, ingreso, stock OK, rol Cajero |
| Rojo | `#EF4444` | Deuda, vencido, stock bajo, egreso, alerta crítica |
| Naranja | `#F59E0B` | Alerta, en riesgo, pendiente, rol Almacenero, Diesel B5 |
| Violeta | `#8B5CF6` | Rol Supervisor, Gasoline 95 |
| Esmeralda | `#10B981` | GLP |

### Tipografía

**SF Pro Rounded** — tipografía del sistema iOS en su variante redondeada. Aporta legibilidad y un tono amigable que facilita la lectura rápida de cifras y estados.

### Convenciones de interfaz

- **Cards** — toda la información se presenta en tarjetas con esquinas redondeadas y sombra suave. Nunca se usan tablas.
- **Badges** — cápsulas de color con texto blanco para indicar estados (Activo, Vencido, Pendiente, Stock Bajo, etc.).
- **Bottom Sheets** — todos los formularios de alta o registro se presentan como hojas que suben desde la parte inferior de la pantalla.
- **Botón flotante (+)** — presente en todos los módulos donde se puede crear un registro nuevo.
- **Barras de progreso** — usadas en crédito de clientes y nivel de stock de almacenes para comunicar visualmente proporciones.
- **Gráficas** — barras para ventas temporales, área para tendencias de tesorería, pastel para distribuciones de gasto y ventas por producto.

---

## Prototipo Web de Referencia

Antes del desarrollo iOS nativo se construyó un **prototipo web interactivo** con React + TypeScript + Tailwind CSS que sirvió como validación del diseño, los flujos de usuario y las reglas de negocio.

El prototipo implementa las mismas pantallas, la misma lógica de automatizaciones en cascada y el mismo sistema de roles, pero con datos en memoria (sin base de datos real). Funciona como documentación viva del sistema.

**Utilidades del prototipo:**
- Validación de la experiencia de usuario antes de escribir código iOS
- Referencia visual del design system y comportamientos de cada módulo
- Demo rápida para stakeholders sin necesidad de un dispositivo iPhone
- Documentación ejecutable de todas las reglas de negocio

El prototipo incluye 4 cuentas demo — una por cada rol — y es completamente funcional para explorar todos los flujos del sistema.

---

## Estado del Proyecto

| Fase | Estado |
|---|---|
| Prototipo web — diseño y validación de UX | ✅ Completo |
| Definición de entidades y esquema Firestore | ✅ Completo |
| Documentación del sistema | ✅ Completo |
| Configuración del proyecto iOS en Xcode | 🔄 En progreso |
| Configuración Firebase y autenticación | 🔄 En progreso |
| Login y control de sesión | 🔄 En progreso |
| Módulo Inicio — Dashboard | ⬜ Pendiente |
| Módulo Ventas | ⬜ Pendiente |
| Módulo Clientes | ⬜ Pendiente |
| Módulo Almacén | ⬜ Pendiente |
| Módulo Tesorería | ⬜ Pendiente |
| Módulo Cobros | ⬜ Pendiente |
| Módulo Compras | ⬜ Pendiente |
| Módulo RRHH y Permisos | ⬜ Pendiente |
| Notificaciones locales (alertas de stock y cuotas vencidas) | ⬜ Pendiente |
| Exportación de reportes PDF | ⬜ Pendiente |
| Soporte multi-estación | ⬜ Pendiente |

---

*RAVNU · App nativa iOS · UIKit + Storyboard + SwiftUI + Firebase*

