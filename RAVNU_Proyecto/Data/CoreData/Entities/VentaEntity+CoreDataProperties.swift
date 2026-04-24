//
//  VentaEntity+CoreDataProperties.swift
//  RAVNU_Proyecto
//
//  Created by Gino Barrena on 15/04/26.
//
//

public import Foundation
public import CoreData


public typealias VentaEntityCoreDataPropertiesSet = NSSet

extension VentaEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<VentaEntity> {
        return NSFetchRequest<VentaEntity>(entityName: "VentaEntity")
    }

    @NSManaged public var cantidadLitros: Double
    @NSManaged public var estado: String?
    @NSManaged public var fechaVenta: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var metodoPago: String?
    @NSManaged public var precioUnitario: Double
    @NSManaged public var total: Double
    @NSManaged public var cliente: ClienteEntity?
    @NSManaged public var cuotas: NSSet?
    @NSManaged public var producto: ProductoEntity?

}

// MARK: Generated accessors for cuotas
extension VentaEntity {

    @objc(addCuotasObject:)
    @NSManaged public func addToCuotas(_ value: CuotaEntity)

    @objc(removeCuotasObject:)
    @NSManaged public func removeFromCuotas(_ value: CuotaEntity)

    @objc(addCuotas:)
    @NSManaged public func addToCuotas(_ values: NSSet)

    @objc(removeCuotas:)
    @NSManaged public func removeFromCuotas(_ values: NSSet)

}

extension VentaEntity : Identifiable {

}
