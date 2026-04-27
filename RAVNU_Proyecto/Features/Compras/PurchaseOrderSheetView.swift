import SwiftUI

struct BorradorOrdenCompra {
    let indiceProveedor: Int
    let indiceProducto: Int
    let indiceAlmacen: Int
    let cantidad: Double
    let precioUnitario: Double
    let notas: String
}

struct PurchaseOrderSheetView: View {
    struct OpcionProveedor: Identifiable {
        let id: String
        let name: String
    }

    struct OpcionProducto: Identifiable {
        let id: String
        let name: String
        let availableStock: Double
        let pricePerLiter: Double
    }

    struct OpcionAlmacen: Identifiable {
        let id: String
        let name: String
        let managerName: String
    }

    let providers: [OpcionProveedor]
    let products: [OpcionProducto]
    let warehouses: [OpcionAlmacen]
    let onCancel: () -> Void
    let onSave: (BorradorOrdenCompra) -> Void

    @State private var indiceProveedor = 0
    @State private var indiceProducto = 0
    @State private var indiceAlmacen = 0
    @State private var textoCantidad = "500"
    @State private var textoPrecioUnitario = "4.20"
    @State private var notas = ""
    @State private var selectorActivo: PickerTarget?

    private enum PickerTarget {
        case provider
        case product
    }

    private var proveedorSeleccionado: OpcionProveedor? {
        providers.indices.contains(indiceProveedor) ? providers[indiceProveedor] : nil
    }

    private var productoSeleccionado: OpcionProducto? {
        products.indices.contains(indiceProducto) ? products[indiceProducto] : nil
    }

    private var almacenSeleccionado: OpcionAlmacen? {
        warehouses.indices.contains(indiceAlmacen) ? warehouses[indiceAlmacen] : nil
    }

    private var cantidad: Double {
        Double(textoCantidad.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var precioUnitario: Double {
        Double(textoPrecioUnitario.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var total: Double {
        cantidad * precioUnitario
    }

    private var stockActual: Double {
        productoSeleccionado?.availableStock ?? 0
    }

    private var stockProyectado: Double {
        stockActual + cantidad
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
                            selectionField(text: proveedorSeleccionado?.name ?? "Seleccionar proveedor") {
                                selectorActivo = .provider
                            }
                        }

                        fieldSection(title: "Producto") {
                            selectionField(text: productoSeleccionado?.name ?? "Seleccionar producto") {
                                selectorActivo = .product
                            }
                        }

                        fieldSection(title: "Almacén destino") {
                            HStack(spacing: 10) {
                                ForEach(Array(warehouses.enumerated()), id: \.offset) { index, warehouse in
                                    Button {
                                        indiceAlmacen = index
                                    } label: {
                                        Text(shortWarehouseName(warehouse.name))
                                            .font(.system(size: 16, weight: .bold, design: .rounded))
                                            .foregroundStyle(indiceAlmacen == index ? .white : Color(hex: "6F7B8D"))
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 42)
                                            .background(indiceAlmacen == index ? Color(hex: "4F7CF7") : Color.white)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                    .stroke(indiceAlmacen == index ? Color.clear : Color(hex: "E6EBF2"), lineWidth: 1)
                                            )
                                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        HStack(spacing: 12) {
                            fieldSection(title: "Cantidad (L)") {
                                numericField(text: $textoCantidad)
                            }
                            fieldSection(title: "Precio/L (S/)") {
                                numericField(text: $textoPrecioUnitario)
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
                                Text("\(almacenSeleccionado?.name.uppercased() ?? "ALMACÉN") — AL RECIBIR")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color(hex: "6F7B8D"))

                                HStack {
                                    Text("\(Int(stockActual.rounded()).formatted())")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundStyle(Color(hex: "6F7B8D"))
                                    Spacer()
                                    Text("\(Int(stockProyectado.rounded()).formatted()) L")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundStyle(Color(hex: "22C55E"))
                                }

                                GeometryReader { proxy in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Color(hex: "DCE7F8"))
                                        Capsule()
                                            .fill(Color(hex: "4F7CF7"))
                                            .frame(width: proxy.size.width * ratioProyectado)
                                    }
                                }
                                .frame(height: 8)
                            }
                            .padding(14)
                            .background(Color(hex: "F3FFF5"))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }

                        fieldSection(title: "Responsable") {
                            Text(almacenSeleccionado?.managerName ?? "Sin responsable")
                                .font(.system(size: 18, weight: .medium, design: .rounded))
                                .foregroundStyle(Color(hex: "172033"))
                                .padding(.horizontal, 14)
                                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                                .background(Color(hex: "F2F5F9"))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }

                        fieldSection(title: "Notas (opcional)") {
                            TextField("Observaciones, condiciones de entrega...", text: $notas, axis: .vertical)
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
                                impactPill(text: "\(shortWarehouseName(almacenSeleccionado?.name ?? "Main")) +\(Int(cantidad.rounded()))L", accent: "22C55E", background: "F0FDF4")
                                impactPill(text: "Tesorería -S/\(Int(total.rounded()))", accent: "EF4444", background: "FEF2F2")
                            }
                        }

                        Button {
                            onSave(
                                BorradorOrdenCompra(
                                    indiceProveedor: indiceProveedor,
                                    indiceProducto: indiceProducto,
                                    indiceAlmacen: indiceAlmacen,
                                    cantidad: cantidad,
                                    precioUnitario: precioUnitario,
                                    notas: notas
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
            if let productoSeleccionado {
                textoPrecioUnitario = String(format: "%.2f", productoSeleccionado.pricePerLiter)
            }
        }
        .confirmationDialog("Seleccionar", isPresented: Binding(
            get: { selectorActivo != nil },
            set: { if !$0 { selectorActivo = nil } }
        )) {
            switch selectorActivo {
            case .provider:
                ForEach(Array(providers.enumerated()), id: \.offset) { index, provider in
                    Button(provider.name) { indiceProveedor = index }
                }
            case .product:
                ForEach(Array(products.enumerated()), id: \.offset) { index, product in
                    Button(product.name) {
                        indiceProducto = index
                        textoPrecioUnitario = String(format: "%.2f", product.pricePerLiter)
                    }
                }
            case .none:
                EmptyView()
            }
        }
    }

    private var header: some View {
        HStack {
            Button("Cancelar", action: onCancel)
                .font(.system(size: 18, weight: .regular, design: .rounded))
                .foregroundStyle(Color(hex: "3B82F6"))
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

    private var ratioProyectado: CGFloat {
        let base = max(stockProyectado, 1)
        let current = max(stockActual, 0)
        let projected = current + cantidad
        return CGFloat(min(max(projected / base, 0), 1))
    }

    private func shortWarehouseName(_ name: String) -> String {
        name
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
