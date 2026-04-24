//
//  AppDelegate.swift
//  RAVNU_Proyecto
//
//  Created by XCODE on 8/04/26.
//

import UIKit
import CoreData
#if canImport(CryptoKit)
import CryptoKit
#endif
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@main
class AppDelegate: UIResponder, UIApplicationDelegate {



    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        AppRuntime.shared.configure()
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }

    // MARK: - Core Data stack

    lazy var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
        */
        let container = NSPersistentContainer(name: "RAVNU_Proyecto")
        if let storeDescription = container.persistentStoreDescriptions.first {
            storeDescription.shouldMigrateStoreAutomatically = true
            storeDescription.shouldInferMappingModelAutomatically = true
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                 
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return container
    }()

    // MARK: - Core Data Saving support

    func saveContext () {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }

}

final class AppRuntime {
    static let shared = AppRuntime()

    let session = AppSession.shared
    let firebase = FirebaseBootstrap.shared
    let syncCoordinator = RemoteSyncCoordinator.shared

    private init() {}

    func configure() {
        firebase.configureIfAvailable()
        syncCoordinator.configure(firebase: firebase)
        NotificationCenter.default.post(name: .backendModeDidChange, object: backendMode)
    }

    var backendMode: BackendMode {
        if syncCoordinator.isRemoteReady {
            return .firebaseRemote
        }
        if firebase.isAvailable {
            return .firebasePendingConfiguration
        }
        return .localFallback
    }
}

final class AppSession {
    static let shared = AppSession()

    private enum Keys {
        static let usuario = "usuarioLogueado"
        static let rol = "rolLogueado"
        static let remoteEnabled = "remoteDataEnabled"
        static let lastSync = "remoteLastSyncDate"
    }

    private let defaults = UserDefaults.standard

    private init() {}

    var usuarioLogueado: String? {
        get { defaults.string(forKey: Keys.usuario) }
        set { defaults.set(newValue, forKey: Keys.usuario) }
    }

    var rolLogueado: String? {
        get { defaults.string(forKey: Keys.rol) }
        set { defaults.set(newValue, forKey: Keys.rol) }
    }

    var remoteDataEnabled: Bool {
        get { defaults.object(forKey: Keys.remoteEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.remoteEnabled) }
    }

    var lastRemoteSyncAt: Date? {
        get { defaults.object(forKey: Keys.lastSync) as? Date }
        set { defaults.set(newValue, forKey: Keys.lastSync) }
    }

    func clear() {
        defaults.removeObject(forKey: Keys.usuario)
        defaults.removeObject(forKey: Keys.rol)
    }
}

final class FirebaseBootstrap {
    static let shared = FirebaseBootstrap()

    private(set) var isConfigured = false
    private(set) var isAvailable = false
    private(set) var configurationMessage = "Firebase SDK no integrado en el proyecto."

    private init() {}

    func configureIfAvailable() {
        #if canImport(FirebaseCore)
        isAvailable = true
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        isConfigured = FirebaseApp.app() != nil
        configurationMessage = isConfigured
            ? "Firebase configurado correctamente."
            : "Firebase SDK presente, pero la app aun no pudo configurarse."
        #else
        isAvailable = false
        isConfigured = false
        configurationMessage = "Agrega FirebaseCore y GoogleService-Info.plist para activar modo remoto."
        #endif
    }
}

final class RemoteSyncCoordinator {
    static let shared = RemoteSyncCoordinator()

    enum SyncState: String {
        case idle
        case waitingForFirebase
        case ready
        case syncing
        case failed
    }

    private(set) var firebase: FirebaseBootstrap?
    private(set) var state: SyncState = .idle
    private(set) var lastErrorMessage: String?

    private init() {}

    func configure(firebase: FirebaseBootstrap) {
        self.firebase = firebase
        state = firebase.isConfigured ? .ready : .waitingForFirebase
        NotificationCenter.default.post(name: .remoteSyncStateDidChange, object: state)
    }

    var isRemoteReady: Bool {
        guard let firebase else { return false }
        return AppSession.shared.remoteDataEnabled && firebase.isConfigured
    }

    func startInitialSyncIfPossible() {
        guard let firebase else {
            state = .failed
            lastErrorMessage = "FirebaseBootstrap no fue configurado."
            NotificationCenter.default.post(name: .remoteSyncStateDidChange, object: state)
            return
        }

        guard AppSession.shared.remoteDataEnabled else {
            state = .idle
            lastErrorMessage = nil
            NotificationCenter.default.post(name: .remoteSyncStateDidChange, object: state)
            return
        }

        guard firebase.isConfigured else {
            state = .waitingForFirebase
            lastErrorMessage = firebase.configurationMessage
            NotificationCenter.default.post(name: .remoteSyncStateDidChange, object: state)
            return
        }

        #if canImport(FirebaseFirestore)
        state = .syncing
        lastErrorMessage = nil
        NotificationCenter.default.post(name: .remoteSyncStateDidChange, object: state)

        syncFirestoreToCoreData { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success:
                    self.state = .ready
                    self.lastErrorMessage = nil
                    AppSession.shared.lastRemoteSyncAt = Date()
                case .failure(let error):
                    self.state = .failed
                    self.lastErrorMessage = error.localizedDescription
                }
                NotificationCenter.default.post(name: .remoteSyncStateDidChange, object: self.state)
            }
        }
        #else
        state = .ready
        lastErrorMessage = nil
        AppSession.shared.lastRemoteSyncAt = Date()
        NotificationCenter.default.post(name: .remoteSyncStateDidChange, object: state)
        #endif
    }

    #if canImport(FirebaseFirestore)
    private func syncFirestoreToCoreData(completion: @escaping (Result<Void, Error>) -> Void) {
        let context = AppCoreData.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        let database = Firestore.firestore()
        let collections = FirestoreCollection.allCases
        let group = DispatchGroup()
        var collectionPayloads: [FirestoreCollection: [QueryDocumentSnapshot]] = [:]
        var collectionErrors: [FirestoreCollection: Error] = [:]
        let resultQueue = DispatchQueue(label: "RemoteSyncCoordinator.firestore-results")

        for collection in collections {
            group.enter()
            database.collection(collection.rawValue).getDocuments { snapshot, error in
                defer { group.leave() }
                resultQueue.sync {
                    if let error {
                        collectionErrors[collection] = error
                    }
                    collectionPayloads[collection] = snapshot?.documents ?? []
                }
            }
        }

        group.notify(queue: .global(qos: .userInitiated)) {
            if collectionErrors.count == collections.count,
               let syncError = collectionErrors.values.first {
                completion(.failure(syncError))
                return
            }

            context.perform {
                do {
                    let resolver = SyncResolver(context: context)
                    try self.importClientes(collectionPayloads[.customers] ?? [], resolver: resolver)
                    try self.importProductos(collectionPayloads[.products] ?? [], resolver: resolver)
                    try self.importAlmacenes(collectionPayloads[.warehouses] ?? [], resolver: resolver)
                    try self.importProveedores(collectionPayloads[.suppliers] ?? [], resolver: resolver)
                    try self.importVentas(collectionPayloads[.sales] ?? [], resolver: resolver)
                    try self.importCuotas(collectionPayloads[.saleInstallments] ?? [], resolver: resolver)
                    try self.importOrdenesCompra(collectionPayloads[.purchaseOrders] ?? [], resolver: resolver)
                    try self.importMovimientos(collectionPayloads[.inventoryMovements] ?? [], resolver: resolver)
                    try self.importStock(collectionPayloads[.warehouseStock] ?? [], resolver: resolver)

                    if context.hasChanges {
                        try context.save()
                    }
                    if let firstError = collectionErrors.first {
                        print("Remote sync parcial: \(firstError.key.rawValue) no se pudo descargar: \(firstError.value.localizedDescription)")
                    }
                    completion(.success(()))
                } catch {
                    context.rollback()
                    completion(.failure(error))
                }
            }
        }
    }

    private func importClientes(_ documents: [QueryDocumentSnapshot], resolver: SyncResolver) throws {
        for document in documents {
            let data = document.data()
            let cliente = try resolver.cliente(for: document.documentID, data: data)
            cliente.nombre = stringValue(data, keys: ["nombre", "name", "fullName"])
            cliente.documento = stringValue(data, keys: ["documento", "documentNumber", "dni", "ruc"])
            cliente.telefono = stringValue(data, keys: ["telefono", "phone"])
            cliente.direccion = stringValue(data, keys: ["direccion", "address"])
            cliente.limiteCredito = doubleValue(data, keys: ["limiteCredito", "creditLimit"])
            cliente.creditoUsado = doubleValue(data, keys: ["creditoUsado", "creditUsed"])
            cliente.activo = boolValue(data, keys: ["activo", "active"], default: true)
        }
    }

    private func importProductos(_ documents: [QueryDocumentSnapshot], resolver: SyncResolver) throws {
        for document in documents {
            let data = document.data()
            let producto = try resolver.producto(for: document.documentID, data: data)
            producto.nombre = stringValue(data, keys: ["nombre", "name"])
            producto.tipo = stringValue(data, keys: ["tipo", "type", "category"])
            producto.unidadMedida = stringValue(data, keys: ["unidadMedida", "unitMeasure", "unit"])
            producto.precioPorLitro = doubleValue(data, keys: ["precioPorLitro", "pricePerLiter", "pricePerUnit"])
            producto.stockMinimo = doubleValue(data, keys: ["stockMinimo", "minimumStock"])
            producto.stockLitros = doubleValue(data, keys: ["stockLitros", "totalStock", "stock"])
            producto.capacidadTotal = doubleValue(data, keys: ["capacidadTotal", "capacityTotal"])
            producto.activo = boolValue(data, keys: ["activo", "active"], default: true)
        }
    }

    private func importAlmacenes(_ documents: [QueryDocumentSnapshot], resolver: SyncResolver) throws {
        for document in documents {
            let data = document.data()
            let almacen = try resolver.almacen(for: document.documentID, data: data)
            almacen.nombre = stringValue(data, keys: ["nombre", "name"])
            almacen.direccion = stringValue(data, keys: ["direccion", "address"])
            almacen.responsable = stringValue(data, keys: ["responsable", "managerName", "responsible"])
            almacen.activo = boolValue(data, keys: ["activo", "active"], default: true)
        }
    }

    private func importProveedores(_ documents: [QueryDocumentSnapshot], resolver: SyncResolver) throws {
        for document in documents {
            let data = document.data()
            let proveedor = try resolver.proveedor(for: document.documentID, data: data)
            proveedor.nombre = stringValue(data, keys: ["nombre", "name"])
            proveedor.documento = stringValue(data, keys: ["documento", "documentNumber", "ruc"])
            proveedor.telefono = stringValue(data, keys: ["telefono", "phone"])
            proveedor.categoria = stringValue(data, keys: ["categoria", "category"])
            proveedor.email = stringValue(data, keys: ["email"])
            proveedor.direccion = stringValue(data, keys: ["direccion", "address"])
            proveedor.calificacion = doubleValue(data, keys: ["calificacion", "rating"])
            proveedor.preferido = boolValue(data, keys: ["preferido", "preferred"], default: false)
            proveedor.verificado = boolValue(data, keys: ["verificado", "verified"], default: false)
            proveedor.activo = boolValue(data, keys: ["activo", "active"], default: true)
        }
    }

    private func importVentas(_ documents: [QueryDocumentSnapshot], resolver: SyncResolver) throws {
        for document in documents {
            let data = document.data()
            let venta = try resolver.venta(for: document.documentID, data: data)
            venta.cantidadLitros = doubleValue(data, keys: ["cantidadLitros", "quantityLiters", "quantity"])
            venta.precioUnitario = doubleValue(data, keys: ["precioUnitario", "unitPrice"])
            venta.total = doubleValue(data, keys: ["total", "amount"])
            venta.metodoPago = stringValue(data, keys: ["metodoPago", "paymentMethod"])
            venta.estado = stringValue(data, keys: ["estado", "status"])
            venta.fechaVenta = dateValue(data, keys: ["fechaVenta", "createdAt", "date"])

            if let clienteId = referenceIdentifier(data, keys: ["clienteId", "clientId"]) {
                venta.cliente = try resolver.cliente(for: clienteId)
            }
            if let productoId = referenceIdentifier(data, keys: ["productoId", "productId"]) {
                venta.producto = try resolver.producto(for: productoId)
            }
        }
    }

    private func importCuotas(_ documents: [QueryDocumentSnapshot], resolver: SyncResolver) throws {
        for document in documents {
            let data = document.data()
            let cuota = try resolver.cuota(for: document.documentID, data: data)
            cuota.numero = int32Value(data, keys: ["numero", "number"])
            cuota.monto = doubleValue(data, keys: ["monto", "amount"])
            cuota.pagada = boolValue(data, keys: ["pagada", "paid"], default: false)
            cuota.fechaVencimiento = dateValue(data, keys: ["fechaVencimiento", "dueDate"])
            cuota.fechaPago = dateValue(data, keys: ["fechaPago", "paidAt"])

            if let ventaId = referenceIdentifier(data, keys: ["ventaId", "saleId"]) {
                cuota.venta = try resolver.venta(for: ventaId)
            }
        }
    }

    private func importOrdenesCompra(_ documents: [QueryDocumentSnapshot], resolver: SyncResolver) throws {
        for document in documents {
            let data = document.data()
            let orden = try resolver.ordenCompra(for: document.documentID, data: data)
            orden.cantidadLitros = doubleValue(data, keys: ["cantidadLitros", "quantityLiters", "quantity"])
            orden.precioUnitarioCompra = doubleValue(data, keys: ["precioUnitarioCompra", "unitPurchasePrice", "unitPrice"])
            orden.total = doubleValue(data, keys: ["total", "amount"])
            orden.estado = stringValue(data, keys: ["estado", "status"])
            orden.fecha = dateValue(data, keys: ["fecha", "createdAt", "date"])
            orden.nota = stringValue(data, keys: ["nota", "note", "notes"])

            if let productoId = referenceIdentifier(data, keys: ["productoId", "productId"]) {
                orden.producto = try resolver.producto(for: productoId)
            }
            if let almacenId = referenceIdentifier(data, keys: ["almacenId", "warehouseId"]) {
                orden.almacen = try resolver.almacen(for: almacenId)
            }
            if let proveedorId = referenceIdentifier(data, keys: ["proveedorId", "supplierId"]) {
                orden.proveedor = try resolver.proveedor(for: proveedorId)
            }
        }
    }

    private func importMovimientos(_ documents: [QueryDocumentSnapshot], resolver: SyncResolver) throws {
        for document in documents {
            let data = document.data()
            let movimiento = try resolver.movimiento(for: document.documentID, data: data)
            movimiento.tipo = stringValue(data, keys: ["tipo", "type"])
            movimiento.cantidadLitros = doubleValue(data, keys: ["cantidadLitros", "quantityLiters", "quantity"])
            movimiento.origen = stringValue(data, keys: ["origen", "source"])
            movimiento.destino = stringValue(data, keys: ["destino", "destination"])
            movimiento.nota = stringValue(data, keys: ["nota", "note", "notes"])
            movimiento.fecha = dateValue(data, keys: ["fecha", "createdAt", "date"])

            if let productoId = referenceIdentifier(data, keys: ["productoId", "productId"]) {
                movimiento.producto = try resolver.producto(for: productoId)
            }
            if let almacenId = referenceIdentifier(data, keys: ["almacenId", "warehouseId"]) {
                movimiento.almacen = try resolver.almacen(for: almacenId)
            }
        }
    }

    private func importStock(_ documents: [QueryDocumentSnapshot], resolver: SyncResolver) throws {
        for document in documents {
            let data = document.data()
            guard
                let almacenId = referenceIdentifier(data, keys: ["almacenId", "warehouseId"]),
                let productoId = referenceIdentifier(data, keys: ["productoId", "productId"])
            else {
                continue
            }

            let stock = try resolver.stock(for: document.documentID, data: data, almacenId: almacenId, productoId: productoId)
            stock.stockActual = doubleValue(data, keys: ["stockActual", "stock", "currentStock"])
            stock.stockMinimo = doubleValue(data, keys: ["stockMinimo", "minimumStock"])
            stock.capacidadTotal = doubleValue(data, keys: ["capacidadTotal", "capacityTotal"])
            stock.unidadMedida = stringValue(data, keys: ["unidadMedida", "unitMeasure", "unit"])
            stock.almacen = try resolver.almacen(for: almacenId)
            stock.producto = try resolver.producto(for: productoId)
        }
    }

    private func stringValue(_ data: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = data[key] as? String, value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                return value
            }
        }
        return nil
    }

    private func doubleValue(_ data: [String: Any], keys: [String], default defaultValue: Double = 0) -> Double {
        for key in keys {
            if let value = data[key] as? Double {
                return value
            }
            if let value = data[key] as? Int {
                return Double(value)
            }
            if let value = data[key] as? Int64 {
                return Double(value)
            }
            if let value = data[key] as? NSNumber {
                return value.doubleValue
            }
            if let value = data[key] as? String, let parsed = Double(value) {
                return parsed
            }
        }
        return defaultValue
    }

    private func boolValue(_ data: [String: Any], keys: [String], default defaultValue: Bool) -> Bool {
        for key in keys {
            if let value = data[key] as? Bool {
                return value
            }
            if let value = data[key] as? NSNumber {
                return value.boolValue
            }
            if let value = data[key] as? String {
                switch value.lowercased() {
                case "true", "1", "si", "sí":
                    return true
                case "false", "0", "no":
                    return false
                default:
                    break
                }
            }
        }
        return defaultValue
    }

    private func int32Value(_ data: [String: Any], keys: [String], default defaultValue: Int32 = 0) -> Int32 {
        for key in keys {
            if let value = data[key] as? Int {
                return Int32(value)
            }
            if let value = data[key] as? Int64 {
                return Int32(value)
            }
            if let value = data[key] as? NSNumber {
                return value.int32Value
            }
            if let value = data[key] as? String, let parsed = Int32(value) {
                return parsed
            }
        }
        return defaultValue
    }

    private func dateValue(_ data: [String: Any], keys: [String]) -> Date? {
        for key in keys {
            if let timestamp = data[key] as? Timestamp {
                return timestamp.dateValue()
            }
            if let date = data[key] as? Date {
                return date
            }
            if let string = data[key] as? String {
                let formatter = ISO8601DateFormatter()
                if let date = formatter.date(from: string) {
                    return date
                }
            }
        }
        return nil
    }

    private func referenceIdentifier(_ data: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let reference = data[key] as? DocumentReference {
                return reference.documentID
            }
            if let value = data[key] as? String, value.isEmpty == false {
                return value
            }
        }
        return nil
    }
    #endif
}

#if canImport(FirebaseFirestore)
private enum FirestoreCollection: String, CaseIterable {
    case customers
    case products
    case warehouses
    case warehouseStock = "warehouse_stock"
    case suppliers
    case purchaseOrders = "purchase_orders"
    case sales
    case saleInstallments = "sale_installments"
    case inventoryMovements = "inventory_movements"
}

private enum SyncError: LocalizedError {
    case coreDataUnavailable
    case entityCreationFailed(String)

    var errorDescription: String? {
        switch self {
        case .coreDataUnavailable:
            return "No se pudo acceder al contenedor Core Data."
        case .entityCreationFailed(let entity):
            return "No se pudo crear o cargar la entidad \(entity)."
        }
    }
}

private final class SyncResolver {
    private let context: NSManagedObjectContext

    private var clientes: [String: ClienteEntity] = [:]
    private var productos: [String: ProductoEntity] = [:]
    private var almacenes: [String: AlmacenEntity] = [:]
    private var proveedores: [String: ProveedorEntity] = [:]
    private var ventas: [String: VentaEntity] = [:]
    private var cuotas: [String: CuotaEntity] = [:]
    private var ordenes: [String: OrdenCompraEntity] = [:]
    private var movimientos: [String: MovimientoInventarioEntity] = [:]
    private var stocks: [String: StockAlmacenEntity] = [:]

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func cliente(for externalId: String, data: [String: Any]? = nil) throws -> ClienteEntity {
        if let cached = clientes[externalId] { return cached }
        let entity: ClienteEntity = try fetchOrCreate(entityName: "ClienteEntity", type: ClienteEntity.self, externalId: externalId)
        applyId(entity: entity, externalId: externalId, data: data)
        clientes[externalId] = entity
        return entity
    }

    func producto(for externalId: String, data: [String: Any]? = nil) throws -> ProductoEntity {
        if let cached = productos[externalId] { return cached }
        let entity: ProductoEntity = try fetchOrCreate(entityName: "ProductoEntity", type: ProductoEntity.self, externalId: externalId)
        applyId(entity: entity, externalId: externalId, data: data)
        productos[externalId] = entity
        return entity
    }

    func almacen(for externalId: String, data: [String: Any]? = nil) throws -> AlmacenEntity {
        if let cached = almacenes[externalId] { return cached }
        let entity: AlmacenEntity = try fetchOrCreate(entityName: "AlmacenEntity", type: AlmacenEntity.self, externalId: externalId)
        applyId(entity: entity, externalId: externalId, data: data)
        almacenes[externalId] = entity
        return entity
    }

    func proveedor(for externalId: String, data: [String: Any]? = nil) throws -> ProveedorEntity {
        if let cached = proveedores[externalId] { return cached }
        let entity: ProveedorEntity = try fetchOrCreate(entityName: "ProveedorEntity", type: ProveedorEntity.self, externalId: externalId)
        applyId(entity: entity, externalId: externalId, data: data)
        proveedores[externalId] = entity
        return entity
    }

    func venta(for externalId: String, data: [String: Any]? = nil) throws -> VentaEntity {
        if let cached = ventas[externalId] { return cached }
        let entity: VentaEntity = try fetchOrCreate(entityName: "VentaEntity", type: VentaEntity.self, externalId: externalId)
        applyId(entity: entity, externalId: externalId, data: data)
        ventas[externalId] = entity
        return entity
    }

    func cuota(for externalId: String, data: [String: Any]? = nil) throws -> CuotaEntity {
        if let cached = cuotas[externalId] { return cached }
        let entity: CuotaEntity = try fetchOrCreate(entityName: "CuotaEntity", type: CuotaEntity.self, externalId: externalId)
        applyId(entity: entity, externalId: externalId, data: data)
        cuotas[externalId] = entity
        return entity
    }

    func ordenCompra(for externalId: String, data: [String: Any]? = nil) throws -> OrdenCompraEntity {
        if let cached = ordenes[externalId] { return cached }
        let entity: OrdenCompraEntity = try fetchOrCreate(entityName: "OrdenCompraEntity", type: OrdenCompraEntity.self, externalId: externalId)
        applyId(entity: entity, externalId: externalId, data: data)
        ordenes[externalId] = entity
        return entity
    }

    func movimiento(for externalId: String, data: [String: Any]? = nil) throws -> MovimientoInventarioEntity {
        if let cached = movimientos[externalId] { return cached }
        let entity: MovimientoInventarioEntity = try fetchOrCreate(entityName: "MovimientoInventarioEntity", type: MovimientoInventarioEntity.self, externalId: externalId)
        applyId(entity: entity, externalId: externalId, data: data)
        movimientos[externalId] = entity
        return entity
    }

    func stock(for externalId: String, data: [String: Any]? = nil, almacenId: String, productoId: String) throws -> StockAlmacenEntity {
        let cacheKey = "\(almacenId)|\(productoId)|\(externalId)"
        if let cached = stocks[cacheKey] { return cached }

        let request: NSFetchRequest<StockAlmacenEntity> = StockAlmacenEntity.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", stableUUID(for: externalId) as CVarArg)

        let entity: StockAlmacenEntity
        if let existing = try context.fetch(request).first {
            entity = existing
        } else {
            guard let created = NSEntityDescription.insertNewObject(forEntityName: "StockAlmacenEntity", into: context) as? StockAlmacenEntity else {
                throw SyncError.entityCreationFailed("StockAlmacenEntity")
            }
            entity = created
        }

        applyId(entity: entity, externalId: externalId, data: data)
        stocks[cacheKey] = entity
        return entity
    }

    private func fetchOrCreate<T: NSManagedObject>(entityName: String, type: T.Type, externalId: String) throws -> T {
        let request = NSFetchRequest<T>(entityName: entityName)
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", stableUUID(for: externalId) as CVarArg)

        if let existing = try context.fetch(request).first {
            return existing
        }

        guard let created = NSEntityDescription.insertNewObject(forEntityName: entityName, into: context) as? T else {
            throw SyncError.entityCreationFailed(entityName)
        }
        return created
    }

    private func applyId(entity: NSManagedObject, externalId: String, data: [String: Any]?) {
        let uuid = explicitUUID(from: data) ?? stableUUID(for: externalId)
        entity.setValue(uuid, forKey: "id")
    }

    private func explicitUUID(from data: [String: Any]?) -> UUID? {
        guard let data else { return nil }
        let possibleKeys = ["id", "uuid", "coreDataId"]
        for key in possibleKeys {
            if let value = data[key] as? String, let uuid = UUID(uuidString: value) {
                return uuid
            }
        }
        return nil
    }

    private func stableUUID(for identifier: String) -> UUID {
        if let uuid = UUID(uuidString: identifier) {
            return uuid
        }

        #if canImport(CryptoKit)
        let digest = SHA256.hash(data: Data(identifier.utf8))
        let bytes = Array(digest.prefix(16))
        let tuple = (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5],
            bytes[6], bytes[7],
            bytes[8], bytes[9],
            bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        )
        return UUID(uuid: tuple)
        #else
        return UUID()
        #endif
    }
}
#endif

enum BackendMode: String {
    case localFallback
    case firebasePendingConfiguration
    case firebaseRemote
}

extension Notification.Name {
    static let remoteSyncStateDidChange = Notification.Name("remoteSyncStateDidChange")
    static let backendModeDidChange = Notification.Name("backendModeDidChange")
}

enum AppRole: String {
    case admin
    case cajero
    case supervisor
    case almacen
    case unknown

    init(sessionValue: String?) {
        switch (sessionValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "admin", "administrador":
            self = .admin
        case "cajero":
            self = .cajero
        case "super", "supervisor":
            self = .supervisor
        case "almacen", "almacenero":
            self = .almacen
        default:
            self = .unknown
        }
    }
}

enum AppPermission {
    case createSales
    case manageCollections
    case manageCustomers
    case manageWarehouse
    case managePurchases
    case viewTreasury
    case addTreasuryAdjustments
}

enum RoleAccessControl {
    static var currentRole: AppRole {
        AppRole(sessionValue: AppSession.shared.rolLogueado)
    }

    static var isAdmin: Bool {
        currentRole == .admin
    }

    static var canCreateSales: Bool { can(.createSales) }
    static var canManageCollections: Bool { can(.manageCollections) }
    static var canManageCustomers: Bool { can(.manageCustomers) }
    static var canManageWarehouse: Bool { can(.manageWarehouse) }
    static var canManagePurchases: Bool { can(.managePurchases) }
    static var canViewTreasury: Bool { can(.viewTreasury) }
    static var canAddTreasuryAdjustments: Bool { can(.addTreasuryAdjustments) }

    static func can(_ permission: AppPermission) -> Bool {
        switch (currentRole, permission) {
        case (.admin, _):
            return true
        case (.cajero, .createSales), (.cajero, .manageCollections), (.cajero, .manageCustomers):
            return true
        case (.supervisor, .createSales), (.supervisor, .manageCollections), (.supervisor, .manageCustomers), (.supervisor, .viewTreasury):
            return true
        case (.almacen, .manageWarehouse), (.almacen, .managePurchases):
            return true
        default:
            return false
        }
    }

    static func denialMessage(for permission: AppPermission) -> String {
        switch permission {
        case .createSales:
            return "Tu rol no tiene permiso para registrar ventas."
        case .manageCollections:
            return "Tu rol no tiene permiso para registrar pagos de cuotas."
        case .manageCustomers:
            return "Tu rol no tiene permiso para crear o editar clientes."
        case .manageWarehouse:
            return "Tu rol no tiene permiso para registrar almacenes, productos o movimientos."
        case .managePurchases:
            return "Tu rol no tiene permiso para crear órdenes de compra o proveedores."
        case .viewTreasury:
            return "Tu rol no tiene permiso para acceder a Tesorería."
        case .addTreasuryAdjustments:
            return "Tu rol no tiene permiso para registrar movimientos manuales en Tesorería."
        }
    }

    static func configureButtons(
        in view: UIView,
        target: AnyObject,
        selectors: [Selector],
        hidden: Bool
    ) {
        let expectedActions = Set(selectors.map(NSStringFromSelector))
        let buttons = allSubviews(in: view).compactMap { $0 as? UIButton }

        for button in buttons {
            let actions = Set(button.actions(forTarget: target, forControlEvent: .touchUpInside) ?? [])
            if actions.isDisjoint(with: expectedActions) == false {
                button.isHidden = hidden
                button.isEnabled = !hidden
            }
        }
    }

    private static func allSubviews(in view: UIView) -> [UIView] {
        view.subviews + view.subviews.flatMap { allSubviews(in: $0) }
    }
}
