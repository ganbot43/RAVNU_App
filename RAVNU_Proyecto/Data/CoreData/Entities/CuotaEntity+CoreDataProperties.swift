//
//  CuotaEntity+CoreDataProperties.swift
//  RAVNU_Proyecto
//
//  Created by Gino Barrena on 15/04/26.
//
//

public import Foundation
public import CoreData


public typealias CuotaEntityCoreDataPropertiesSet = NSSet

extension CuotaEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CuotaEntity> {
        return NSFetchRequest<CuotaEntity>(entityName: "CuotaEntity")
    }

    @NSManaged public var fechaPago: Date?
    @NSManaged public var fechaVencimiento: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var monto: Double
    @NSManaged public var numero: Int32
    @NSManaged public var pagada: Bool
    @NSManaged public var venta: VentaEntity?

}

extension CuotaEntity : Identifiable {

}
