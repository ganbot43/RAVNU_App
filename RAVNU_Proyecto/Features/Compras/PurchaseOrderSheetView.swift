import SwiftUI

struct BorradorOrdenCompra {
    let indiceProveedor: Int
    let indiceProducto: Int
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

    let providers: [OpcionProveedor]
    let products: [OpcionProducto]
    let onCancel: () -> Void
    let onSave: (BorradorOrdenCompra) -> Void

    @State private var indiceProveedor = 0
    @State private var indiceProducto = 0
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

    private var cantidad: Double {
        Double(textoCantidad.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var precioUnitario: Double {
        Double(textoPrecioUnitario.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var total: Double {
        cantidad * precioUnitario
    }

    private var stockGeneralActual: Double {
        productoSeleccionado?.availableStock ?? 0
    }

    private var stockGeneralProyectado: Double {
        stockGeneralActual + cantidad
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
                                Text("IMPACTO GENERAL AL APROBAR Y PAGAR")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color(hex: "6F7B8D"))

                                HStack {
                                    Text("\(Int(stockGeneralActual.rounded()).formatted())")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundStyle(Color(hex: "6F7B8D"))
                                    Spacer()
                                    Text("\(Int(stockGeneralProyectado.rounded()).formatted()) L")
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

                                Text("El stock no se asigna en este paso. Primero se registra la orden, luego se aprueba, se marca pagada y finalmente se distribuye a uno o varios almacenes.")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color(hex: "6F7B8D"))
                            }
                            .padding(14)
                            .background(Color(hex: "F3FFF5"))
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
                            Text("FLUJO DE LA ORDEN")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(hex: "A1ADBD"))
                            VStack(alignment: .leading, spacing: 8) {
                                impactPill(text: "1. Registrar solicitud u orden", accent: "4F7CF7", background: "F3F7FF")
                                impactPill(text: "2. Aprobar la compra", accent: "F59E0B", background: "FFF7ED")
                                impactPill(text: "3. Marcar pago por S/\(Int(total.rounded()))", accent: "EF4444", background: "FEF2F2")
                                impactPill(text: "4. Distribuir \(Int(cantidad.rounded()))L a uno o varios almacenes", accent: "22C55E", background: "F0FDF4")
                            }
                        }

                        Button {
                            onSave(
                                BorradorOrdenCompra(
                                    indiceProveedor: indiceProveedor,
                                    indiceProducto: indiceProducto,
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
        let base = max(stockGeneralProyectado, 1)
        let current = max(stockGeneralActual, 0)
        let projected = current + cantidad
        return CGFloat(min(max(projected / base, 0), 1))
    }
}

struct BorradorAsignacionOrdenCompra {
    struct Fila: Identifiable {
        let id: UUID
        let indiceAlmacen: Int
        let cantidad: Double
    }

    let filas: [Fila]
}

struct PurchaseOrderAllocationSheetView: View {
    struct OpcionAlmacen: Identifiable {
        let id: String
        let nombre: String
        let responsable: String
        let stockActual: Double
        let capacidadTotal: Double
        let stockMinimo: Double
        let espacioDisponible: Double
    }

    private struct FilaEditable: Identifiable {
        let id = UUID()
        var indiceAlmacen: Int
        var textoCantidad: String
    }

    let cantidadTotalOrden: Double
    let productName: String
    let warehouses: [OpcionAlmacen]
    let onCancel: () -> Void
    let onSave: (BorradorAsignacionOrdenCompra) -> Void

    @State private var filas: [FilaEditable] = [.init(indiceAlmacen: 0, textoCantidad: "")]

    private var totalAsignado: Double {
        filas.reduce(0) { parcial, fila in
            parcial + (Double(fila.textoCantidad.replacingOccurrences(of: ",", with: ".")) ?? 0)
        }
    }

    private var restante: Double {
        cantidadTotalOrden - totalAsignado
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

                encabezado
                Divider()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        resumenOrden

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Distribución por almacén")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(hex: "172033"))

                            ForEach($filas) { $fila in
                                tarjetaFila(fila: $fila)
                            }

                            Button {
                                filas.append(.init(indiceAlmacen: 0, textoCantidad: ""))
                            } label: {
                                Label("Agregar almacén", systemImage: "plus.circle.fill")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color(hex: "3B82F6"))
                            }
                            .buttonStyle(.plain)
                        }

                        tarjetaControl

                        Button {
                            let borrador = BorradorAsignacionOrdenCompra(
                                filas: filas.map {
                                    .init(
                                        id: $0.id,
                                        indiceAlmacen: $0.indiceAlmacen,
                                        cantidad: Double($0.textoCantidad.replacingOccurrences(of: ",", with: ".")) ?? 0
                                    )
                                }
                            )
                            onSave(borrador)
                        } label: {
                            Text("Asignar stock y recibir")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 58)
                                .background(Color(hex: "22C55E"))
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
    }

    private var encabezado: some View {
        HStack {
            Button("Cancelar", action: onCancel)
                .font(.system(size: 18, weight: .regular, design: .rounded))
                .foregroundStyle(Color(hex: "3B82F6"))
            Spacer()
            Text("Asignar Stock")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(Color(hex: "172033"))
            Spacer()
            Color.clear.frame(width: 56, height: 1)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 14)
    }

    private var resumenOrden: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(productName.uppercased())
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: "6F7B8D"))
            HStack {
                Text("Cantidad pagada")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(hex: "172033"))
                Spacer()
                Text("\(Int(cantidadTotalOrden.rounded()).formatted()) L")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(Color(hex: "22C55E"))
            }
            Text("Distribuye la recepción entre uno o varios almacenes. El total asignado debe coincidir exactamente con la cantidad pagada.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color(hex: "6F7B8D"))
        }
        .padding(18)
        .background(Color(hex: "F3F7FF"))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func tarjetaFila(fila: Binding<FilaEditable>) -> some View {
        let opcion = warehouses.indices.contains(fila.wrappedValue.indiceAlmacen) ? warehouses[fila.wrappedValue.indiceAlmacen] : nil

        return VStack(alignment: .leading, spacing: 12) {
            Picker("Almacén", selection: fila.indiceAlmacen) {
                ForEach(Array(warehouses.enumerated()), id: \.offset) { index, warehouse in
                    Text(warehouse.nombre).tag(index)
                }
            }
            .pickerStyle(.menu)
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .background(Color(hex: "F2F5F9"))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            HStack(spacing: 12) {
                TextField("Cantidad (L)", text: fila.textoCantidad)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .padding(.horizontal, 14)
                    .frame(height: 52)
                    .background(Color(hex: "F2F5F9"))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                if filas.count > 1 {
                    Button {
                        filas.removeAll { $0.id == fila.wrappedValue.id }
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color(hex: "EF4444"))
                            .frame(width: 48, height: 48)
                            .background(Color(hex: "FEF2F2"))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            if let opcion {
                VStack(alignment: .leading, spacing: 8) {
                    filaDetalle(titulo: "Responsable", valor: opcion.responsable)
                    filaDetalle(titulo: "Stock actual", valor: "\(Int(opcion.stockActual.rounded()).formatted()) L")
                    filaDetalle(titulo: "Capacidad", valor: "\(Int(opcion.capacidadTotal.rounded()).formatted()) L")
                    filaDetalle(titulo: "Espacio disponible", valor: "\(Int(opcion.espacioDisponible.rounded()).formatted()) L")
                    filaDetalle(titulo: "Mínimo", valor: "\(Int(opcion.stockMinimo.rounded()).formatted()) L")
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(hex: "E6EBF2"), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var tarjetaControl: some View {
        VStack(alignment: .leading, spacing: 10) {
            filaDetalle(titulo: "Total asignado", valor: "\(Int(totalAsignado.rounded()).formatted()) L")
            filaDetalle(titulo: "Restante", valor: "\(Int(restante.rounded()).formatted()) L")
            Text(restante == 0 ? "La asignación está lista para recibirse." : "Ajusta las cantidades hasta que el restante sea 0L.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(restante == 0 ? Color(hex: "22C55E") : Color(hex: "EF4444"))
        }
        .padding(18)
        .background(Color(hex: "FFF7ED"))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func filaDetalle(titulo: String, valor: String) -> some View {
        HStack {
            Text(titulo)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: "6F7B8D"))
            Spacer()
            Text(valor)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: "172033"))
        }
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
