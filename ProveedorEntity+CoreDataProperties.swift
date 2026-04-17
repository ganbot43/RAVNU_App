public import Foundation
public import CoreData

public typealias ProveedorEntityCoreDataPropertiesSet = NSSet

extension ProveedorEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ProveedorEntity> {
        return NSFetchRequest<ProveedorEntity>(entityName: "ProveedorEntity")
    }

    @NSManaged public var activo: Bool
    @NSManaged public var documento: String?
    @NSManaged public var id: UUID?
    @NSManaged public var nombre: String?
    @NSManaged public var telefono: String?
    @NSManaged public var ordenesCompra: NSSet?
}

extension ProveedorEntity {

    @objc(addOrdenesCompraObject:)
    @NSManaged public func addToOrdenesCompra(_ value: OrdenCompraEntity)

    @objc(removeOrdenesCompraObject:)
    @NSManaged public func removeFromOrdenesCompra(_ value: OrdenCompraEntity)

    @objc(addOrdenesCompra:)
    @NSManaged public func addToOrdenesCompra(_ values: NSSet)

    @objc(removeOrdenesCompra:)
    @NSManaged public func removeFromOrdenesCompra(_ values: NSSet)
}

extension ProveedorEntity: Identifiable {

}
