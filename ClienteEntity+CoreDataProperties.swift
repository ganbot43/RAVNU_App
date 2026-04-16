//
//  ClienteEntity+CoreDataProperties.swift
//  RAVNU_Proyecto
//
//  Created by Gino Barrena on 15/04/26.
//
//

public import Foundation
public import CoreData


public typealias ClienteEntityCoreDataPropertiesSet = NSSet

extension ClienteEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ClienteEntity> {
        return NSFetchRequest<ClienteEntity>(entityName: "ClienteEntity")
    }

    @NSManaged public var activo: Bool
    @NSManaged public var creditoUsado: Double
    @NSManaged public var direccion: String?
    @NSManaged public var documento: String?
    @NSManaged public var id: UUID?
    @NSManaged public var limiteCredito: Double
    @NSManaged public var nombre: String?
    @NSManaged public var telefono: String?
    @NSManaged public var ventas: NSSet?

}

// MARK: Generated accessors for ventas
extension ClienteEntity {

    @objc(addVentasObject:)
    @NSManaged public func addToVentas(_ value: VentaEntity)

    @objc(removeVentasObject:)
    @NSManaged public func removeFromVentas(_ value: VentaEntity)

    @objc(addVentas:)
    @NSManaged public func addToVentas(_ values: NSSet)

    @objc(removeVentas:)
    @NSManaged public func removeFromVentas(_ values: NSSet)

}

extension ClienteEntity : Identifiable {

}
