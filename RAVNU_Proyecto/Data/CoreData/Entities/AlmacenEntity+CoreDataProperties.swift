public import Foundation
public import CoreData

public typealias AlmacenEntityCoreDataPropertiesSet = NSSet

extension AlmacenEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<AlmacenEntity> {
        return NSFetchRequest<AlmacenEntity>(entityName: "AlmacenEntity")
    }

    @NSManaged public var activo: Bool
    @NSManaged public var direccion: String?
    @NSManaged public var id: UUID?
    @NSManaged public var nombre: String?
    @NSManaged public var responsable: String?
    @NSManaged public var movimientos: NSSet?
    @NSManaged public var ordenesCompra: NSSet?
    @NSManaged public var stocks: NSSet?
}

extension AlmacenEntity {

    @objc(addMovimientosObject:)
    @NSManaged public func addToMovimientos(_ value: MovimientoInventarioEntity)

    @objc(removeMovimientosObject:)
    @NSManaged public func removeFromMovimientos(_ value: MovimientoInventarioEntity)

    @objc(addMovimientos:)
    @NSManaged public func addToMovimientos(_ values: NSSet)

    @objc(removeMovimientos:)
    @NSManaged public func removeFromMovimientos(_ values: NSSet)

    @objc(addOrdenesCompraObject:)
    @NSManaged public func addToOrdenesCompra(_ value: OrdenCompraEntity)

    @objc(removeOrdenesCompraObject:)
    @NSManaged public func removeFromOrdenesCompra(_ value: OrdenCompraEntity)

    @objc(addOrdenesCompra:)
    @NSManaged public func addToOrdenesCompra(_ values: NSSet)

    @objc(removeOrdenesCompra:)
    @NSManaged public func removeFromOrdenesCompra(_ values: NSSet)

    @objc(addStocksObject:)
    @NSManaged public func addToStocks(_ value: StockAlmacenEntity)

    @objc(removeStocksObject:)
    @NSManaged public func removeFromStocks(_ value: StockAlmacenEntity)

    @objc(addStocks:)
    @NSManaged public func addToStocks(_ values: NSSet)

    @objc(removeStocks:)
    @NSManaged public func removeFromStocks(_ values: NSSet)
}

extension AlmacenEntity: Identifiable {

}
