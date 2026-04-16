//
//  ProductoEntity+CoreDataProperties.swift
//  RAVNU_Proyecto
//
//  Created by Gino Barrena on 15/04/26.
//
//

public import Foundation
public import CoreData


public typealias ProductoEntityCoreDataPropertiesSet = NSSet

extension ProductoEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ProductoEntity> {
        return NSFetchRequest<ProductoEntity>(entityName: "ProductoEntity")
    }

    @NSManaged public var activo: Bool
    @NSManaged public var id: UUID?
    @NSManaged public var nombre: String?
    @NSManaged public var precioPorLitro: Double
    @NSManaged public var stockLitros: Double
    @NSManaged public var tipo: String?
    @NSManaged public var ventas: NSSet?

}

// MARK: Generated accessors for ventas
extension ProductoEntity {

    @objc(addVentasObject:)
    @NSManaged public func addToVentas(_ value: VentaEntity)

    @objc(removeVentasObject:)
    @NSManaged public func removeFromVentas(_ value: VentaEntity)

    @objc(addVentas:)
    @NSManaged public func addToVentas(_ values: NSSet)

    @objc(removeVentas:)
    @NSManaged public func removeFromVentas(_ values: NSSet)

}

extension ProductoEntity : Identifiable {

}
