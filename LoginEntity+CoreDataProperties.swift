//
//  LoginEntity+CoreDataProperties.swift
//  RAVNU_Proyecto
//
//  Created by Gino Barrena on 11/04/26.
//
//

public import Foundation
public import CoreData


public typealias LoginEntityCoreDataPropertiesSet = NSSet

extension LoginEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<LoginEntity> {
        return NSFetchRequest<LoginEntity>(entityName: "LoginEntity")
    }

    @NSManaged public var usuario: String?
    @NSManaged public var contrasena: String?
    @NSManaged public var id: UUID?
    @NSManaged public var rol: String?

}

extension LoginEntity : Identifiable {

}
