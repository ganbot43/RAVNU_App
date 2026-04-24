public import Foundation
public import CoreData

public typealias MovimientoInventarioEntityCoreDataPropertiesSet = NSSet

extension MovimientoInventarioEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<MovimientoInventarioEntity> {
        return NSFetchRequest<MovimientoInventarioEntity>(entityName: "MovimientoInventarioEntity")
    }

    @NSManaged public var cantidadLitros: Double
    @NSManaged public var fecha: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var nota: String?
    @NSManaged public var origen: String?
    @NSManaged public var destino: String?
    @NSManaged public var tipo: String?
    @NSManaged public var almacen: AlmacenEntity?
    @NSManaged public var producto: ProductoEntity?
}

extension MovimientoInventarioEntity: Identifiable {

}
