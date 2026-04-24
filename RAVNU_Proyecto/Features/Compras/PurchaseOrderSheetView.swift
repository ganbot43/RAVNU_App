import SwiftUI

struct PurchaseOrderDraft {
    let providerIndex: Int
    let productIndex: Int
    let warehouseIndex: Int
    let quantity: Double
    let unitPrice: Double
    let notes: String
}

struct PurchaseOrderSheetView: View {
    struct ProviderOption: Identifiable {
        let id: String
        let name: String
    }

    struct ProductOption: Identifiable {
        let id: String
        let name: String
        let availableStock: Double
        let pricePerLiter: Double
    }

    struct WarehouseOption: Identifiable {
        let id: String
        let name: String
        let managerName: String
    }

    let providers: [ProviderOption]
    let products: [ProductOption]
    let warehouses: [WarehouseOption]
    let onCancel: () -> Void
    let onSave: (PurchaseOrderDraft) -> Void

    @State private var providerIndex = 0
    @State private var productIndex = 0
    @State private var warehouseIndex = 0
    @State private var quantityText = "500"
    @State private var unitPriceText = "4.20"
    @State private var notes = ""
    @State private var activePicker: PickerTarget?

    private enum PickerTarget {
        case provider
        case product
    }

    private var selectedProvider: ProviderOption? {
        providers.indices.contains(providerIndex) ? providers[providerIndex] : nil
    }

    private var selectedProduct: ProductOption? {
        products.indices.contains(productIndex) ? products[productIndex] : nil
    }

    private var selectedWarehouse: WarehouseOption? {
        warehouses.indices.contains(warehouseIndex) ? warehouses[warehouseIndex] : nil
    }

    private var quantity: Double {
        Double(quantityText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var unitPrice: Double {
        Double(unitPriceText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var total: Double {
        quantity * unitPrice
    }

    private var currentStock: Double {
        selectedProduct?.availableStock ?? 0
    }

    private var projectedStock: Double {
        currentStock + quantity
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                Capsule()
                    .fill(Color(hex: "D6DCE5"))
                    .frame(width: 46, height: 5)
                    .padding(.top, 8)
                    .padding(.bottom, 10)

                header
                Divider()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        fieldSection(title: "Proveedor") {
                            selectionField(text: selectedProvider?.name ?? "Seleccionar proveedor") {
                                activePicker = .provider
                            }
                        }

                        fieldSection(title: "Producto") {
                            selectionField(text: selectedProduct?.name ?? "Seleccionar producto") {
                                activePicker = .product
                            }
                        }

                        fieldSection(title: "Almacén destino") {
                            HStack(spacing: 10) {
                                ForEach(Array(warehouses.enumerated()), id: \.offset) { index, warehouse in
                                    Button {
                                        warehouseIndex = index
                                    } label: {
                                        Text(shortWarehouseName(warehouse.name))
                                            .font(.system(size: 16, weight: .bold, design: .rounded))
                                            .foregroundStyle(warehouseIndex == index ? .white : Color(hex: "6F7B8D"))
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 42)
                                            .background(warehouseIndex == index ? Color(hex: "4F7CF7") : Color.white)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                    .stroke(warehouseIndex == index ? Color.clear : Color(hex: "E6EBF2"), lineWidth: 1)
                                            )
                                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        HStack(spacing: 12) {
                            fieldSection(title: "Cantidad (L)") {
                                numericField(text: $quantityText)
                            }
                            fieldSection(title: "Precio/L (S/)") {
                                numericField(text: $unitPriceText)
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Total de la orden")
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color(hex: "A1ADBD"))
                                Spacer()
                                Text(String(format: "S/ %.2f", total))
                                    .font(.system(size: 20, weight: .black, design: .rounded))
                                    .foregroundStyle(Color(hex: "4F7CF7"))
                            }
                            .padding(18)
                            .background(Color(hex: "F3F7FF"))
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                            VStack(alignment: .leading, spacing: 10) {
                                Text("\(selectedWarehouse?.name.uppercased() ?? "ALMACÉN") — AL RECIBIR")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color(hex: "6F7B8D"))

                                HStack {
                                    Text("\(Int(currentStock.rounded()).formatted())")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundStyle(Color(hex: "6F7B8D"))
                                    Spacer()
                                    Text("\(Int(projectedStock.rounded()).formatted()) L")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundStyle(Color(hex: "22C55E"))
                                }

                                GeometryReader { proxy in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Color(hex: "DCE7F8"))
                                        Capsule()
                                            .fill(Color(hex: "4F7CF7"))
                                            .frame(width: proxy.size.width * projectedRatio)
                                    }
                                }
                                .frame(height: 8)
                            }
                            .padding(14)
                            .background(Color(hex: "F3FFF5"))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }

                        fieldSection(title: "Responsable") {
                            Text(selectedWarehouse?.managerName ?? "Sin responsable")
                                .font(.system(size: 18, weight: .medium, design: .rounded))
                                .foregroundStyle(Color(hex: "172033"))
                                .padding(.horizontal, 14)
                                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                                .background(Color(hex: "F2F5F9"))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }

                        fieldSection(title: "Notas (opcional)") {
                            TextField("Observaciones, condiciones de entrega...", text: $notes, axis: .vertical)
                                .lineLimit(3, reservesSpace: true)
                                .font(.system(size: 17, weight: .medium, design: .rounded))
                                .padding(14)
                                .background(Color(hex: "F2F5F9"))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("AL MARCAR COMO RECIBIDO")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(hex: "A1ADBD"))
                            HStack(spacing: 10) {
                                impactPill(text: "\(shortWarehouseName(selectedWarehouse?.name ?? "Main")) +\(Int(quantity.rounded()))L", accent: "22C55E", background: "F0FDF4")
                                impactPill(text: "Tesorería -S/\(Int(total.rounded()))", accent: "EF4444", background: "FEF2F2")
                            }
                        }

                        Button {
                            onSave(
                                PurchaseOrderDraft(
                                    providerIndex: providerIndex,
                                    productIndex: productIndex,
                                    warehouseIndex: warehouseIndex,
                                    quantity: quantity,
                                    unitPrice: unitPrice,
                                    notes: notes
                                )
                            )
                        } label: {
                            Text("Registrar Orden")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 58)
                                .background(Color(hex: "F59E0B"))
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 24)
                }
            }
        }
        .onAppear {
            if let selectedProduct {
                unitPriceText = String(format: "%.2f", selectedProduct.pricePerLiter)
            }
        }
        .confirmationDialog("Seleccionar", isPresented: Binding(
            get: { activePicker != nil },
            set: { if !$0 { activePicker = nil } }
        )) {
            switch activePicker {
            case .provider:
                ForEach(Array(providers.enumerated()), id: \.offset) { index, provider in
                    Button(provider.name) { providerIndex = index }
                }
            case .product:
                ForEach(Array(products.enumerated()), id: \.offset) { index, product in
                    Button(product.name) {
                        productIndex = index
                        unitPriceText = String(format: "%.2f", product.pricePerLiter)
                    }
                }
            case .none:
                EmptyView()
            }
        }
    }

    private var header: some View {
        HStack {
            Button("Cancel", action: onCancel)
                .font(.system(size: 18, weight: .regular, design: .rounded))
                .foregroundStyle(Color(hex: "7A8699"))
            Spacer()
            Text("Nueva Orden de Compra")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(Color(hex: "172033"))
            Spacer()
            Color.clear.frame(width: 56, height: 1)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 14)
    }

    private func fieldSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: "6F7B8D"))
            content()
        }
    }

    private func selectionField(text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(text)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(hex: "172033"))
                Spacer()
                Image(systemName: "chevron.down")
                    .foregroundStyle(Color(hex: "A1ADBD"))
            }
            .padding(.horizontal, 14)
            .frame(height: 52)
            .background(Color(hex: "F2F5F9"))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func numericField(text: Binding<String>) -> some View {
        TextField("0", text: text)
            .keyboardType(.decimalPad)
            .font(.system(size: 20, weight: .medium, design: .rounded))
            .padding(.horizontal, 14)
            .frame(height: 52)
            .background(Color(hex: "F2F5F9"))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func impactPill(text: String, accent: String, background: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(Color(hex: accent))
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(Color(hex: background))
            .clipShape(Capsule())
    }

    private var projectedRatio: CGFloat {
        let base = max(projectedStock, 1)
        let current = max(currentStock, 0)
        let projected = current + quantity
        return CGFloat(min(max(projected / base, 0), 1))
    }

    private func shortWarehouseName(_ name: String) -> String {
        if name.lowercased().contains("main") { return "Main" }
        if name.lowercased().contains("north") { return "North" }
        if name.lowercased().contains("south") { return "South" }
        return name
    }
}

private extension Color {
    init(hex: String) {
        var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitized = sanitized.replacingOccurrences(of: "#", with: "")
        var int: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&int)
        let r = Double((int & 0xFF0000) >> 16) / 255.0
        let g = Double((int & 0x00FF00) >> 8) / 255.0
        let b = Double(int & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
