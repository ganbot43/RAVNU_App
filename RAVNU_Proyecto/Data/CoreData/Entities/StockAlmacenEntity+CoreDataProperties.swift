public import Foundation
public import CoreData

public typealias StockAlmacenEntityCoreDataPropertiesSet = NSSet

extension StockAlmacenEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<StockAlmacenEntity> {
        return NSFetchRequest<StockAlmacenEntity>(entityName: "StockAlmacenEntity")
    }

    @NSManaged public var capacidadTotal: Double
    @NSManaged public var id: UUID?
    @NSManaged public var stockActual: Double
    @NSManaged public var stockMinimo: Double
    @NSManaged public var unidadMedida: String?
    @NSManaged public var almacen: AlmacenEntity?
    @NSManaged public var producto: ProductoEntity?
}

extension StockAlmacenEntity: Identifiable {

}
