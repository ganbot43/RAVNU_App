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
    @NSManaged public var capacidadTotal: Double
    @NSManaged public var id: UUID?
    @NSManaged public var nombre: String?
    @NSManaged public var precioPorLitro: Double
    @NSManaged public var stockMinimo: Double
    @NSManaged public var stockLitros: Double
    @NSManaged public var tipo: String?
    @NSManaged public var unidadMedida: String?
    @NSManaged public var movimientos: NSSet?
    @NSManaged public var ordenesCompra: NSSet?
    @NSManaged public var stocks: NSSet?
    @NSManaged public var ventas: NSSet?

}

extension ProductoEntity {

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
