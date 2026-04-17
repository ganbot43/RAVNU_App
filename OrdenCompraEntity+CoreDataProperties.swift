public import Foundation
public import CoreData

public typealias OrdenCompraEntityCoreDataPropertiesSet = NSSet

extension OrdenCompraEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<OrdenCompraEntity> {
        return NSFetchRequest<OrdenCompraEntity>(entityName: "OrdenCompraEntity")
    }

    @NSManaged public var cantidadLitros: Double
    @NSManaged public var estado: String?
    @NSManaged public var fecha: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var total: Double
    @NSManaged public var almacen: AlmacenEntity?
    @NSManaged public var producto: ProductoEntity?
    @NSManaged public var proveedor: ProveedorEntity?
}

extension OrdenCompraEntity: Identifiable {

}
