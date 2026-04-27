import Foundation

#if canImport(FirebaseFirestore)
import FirebaseFirestore

enum TreasuryRemoteSync {
    private static var firestore: Firestore {
        Firestore.firestore()
    }

    static func syncSaleIfNeeded(
        venta: VentaEntity,
        cliente: ClienteEntity,
        productName: String,
        paymentMethod: String
    ) {
        guard FirebaseBootstrap.shared.isConfigured, AppSession.shared.remoteDataEnabled else { return }
        guard
            let saleID = venta.id?.uuidString,
            paymentMethod.lowercased() == "efectivo"
        else {
            return
        }

        let documentID = "sale_\(saleID)"
        let payload = basePayload(
            id: documentID,
            sourceType: "sale",
            sourceID: saleID,
            kind: "income",
            category: "sale",
            amount: venta.total,
            title: "Venta \(productName)",
            subtitle: cliente.nombre ?? "Cliente",
            date: venta.fechaVenta ?? Date()
        )

        firestore.collection("treasury_transactions").document(documentID).setData(payload, merge: true)
    }

    static func syncInstallmentPayment(
        cuota: CuotaEntity,
        cliente: ClienteEntity?,
        amount: Double
    ) {
        guard FirebaseBootstrap.shared.isConfigured, AppSession.shared.remoteDataEnabled else { return }
        guard let installmentID = cuota.id?.uuidString else { return }

        let productName = cuota.venta?.producto?.nombre ?? "Cuota"
        let clientName = cliente?.nombre ?? cuota.venta?.cliente?.nombre ?? "Cliente"
        let payload = basePayload(
            id: "installment_\(installmentID)",
            sourceType: "installment",
            sourceID: installmentID,
            kind: "income",
            category: "collection",
            amount: amount,
            title: "Cobro cuota \(productName)",
            subtitle: clientName,
            date: cuota.fechaPago ?? Date()
        )

        firestore.collection("treasury_transactions").document("installment_\(installmentID)").setData(payload, merge: true)
    }

    static func syncPurchaseExpenseIfNeeded(orden: OrdenCompraEntity, status: String) {
        guard FirebaseBootstrap.shared.isConfigured, AppSession.shared.remoteDataEnabled else { return }
        guard let orderID = orden.id?.uuidString else { return }

        let normalizedStatus = status.lowercased()
        guard normalizedStatus == "pagada" || normalizedStatus == "recibida" else { return }

        let payload = basePayload(
            id: "purchase_order_\(orderID)",
            sourceType: "purchase_order",
            sourceID: orderID,
            kind: "expense",
            category: "purchase",
            amount: orden.total,
            title: "Compra \(orden.producto?.nombre ?? "Producto")",
            subtitle: orden.proveedor?.nombre ?? orden.almacen?.nombre ?? "Proveedor",
            date: orden.fecha ?? Date()
        ).merging([
            "status": normalizedStatus
        ]) { _, new in new }

        firestore.collection("treasury_transactions").document("purchase_order_\(orderID)").setData(payload, merge: true)
    }

    private static func basePayload(
        id: String,
        sourceType: String,
        sourceID: String,
        kind: String,
        category: String,
        amount: Double,
        title: String,
        subtitle: String,
        date: Date
    ) -> [String: Any] {
        [
            "id": id,
            "sourceType": sourceType,
            "sourceId": sourceID,
            "kind": kind,
            "category": category,
            "amount": amount,
            "title": title,
            "subtitle": subtitle,
            "date": Timestamp(date: date),
            "createdAt": Timestamp(date: Date()),
            "createdBy": AppSession.shared.usuarioLogueado ?? "system"
        ]
    }
}
#else
enum TreasuryRemoteSync {
    static func syncSaleIfNeeded(
        venta: VentaEntity,
        cliente: ClienteEntity,
        productName: String,
        paymentMethod: String
    ) {}

    static func syncInstallmentPayment(
        cuota: CuotaEntity,
        cliente: ClienteEntity?,
        amount: Double
    ) {}

    static func syncPurchaseExpenseIfNeeded(orden: OrdenCompraEntity, status: String) {}
}
#endif
