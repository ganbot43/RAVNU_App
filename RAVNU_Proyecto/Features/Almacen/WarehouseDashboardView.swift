import SwiftUI

struct DatosDashboardAlmacen {
    struct MetricaResumen: Identifiable {
        let id = UUID()
        let title: String
        let value: String
        let colorHex: String
    }

    struct FiltroAlmacen: Identifiable, Hashable {
        let id: String
        let title: String
        let colorHex: String
    }

    struct TarjetaAlmacen: Identifiable {
        let id: String
        let name: String
        let shortName: String
        let address: String
        let colorHex: String
        let totalStockText: String
        let totalCapacityText: String
        let fillRatio: Double
        let levelText: String
        let productsText: String
        let lowStockText: String?
        let valueText: String
    }

    struct StockProductoPorAlmacen: Identifiable {
        let id = UUID()
        let warehouseName: String
        let colorHex: String
        let stockText: String
        let detailText: String
        let fillRatio: Double
        let isLow: Bool
    }

    struct TarjetaProducto: Identifiable {
        let id: String
        let name: String
        let priceText: String
        let minimumText: String
        let totalStockText: String
        let capacityText: String
        let healthText: String
        let totalValueText: String
        let fillRatio: Double
        let colorHex: String
        let bgHex: String
        let symbolName: String
        let isLow: Bool
        let stocks: [StockProductoPorAlmacen]
    }

    struct TarjetaMovimiento: Identifiable {
        let id: String
        let warehouseId: String
        let destinationWarehouseId: String?
        let productName: String
        let type: TipoMovimiento
        let quantityText: String
        let note: String
        let actorText: String
        let dateText: String
        let sourceChipText: String?
        let sourceChipIcon: String?
        let destinationChipText: String?
        let destinationChipIcon: String?
        let colorHex: String
        let bgHex: String
        let accentHex: String
        let symbolName: String
    }

    enum TipoMovimiento: String, CaseIterable {
        case entrada
        case salida
        case transfer

        var title: String {
            switch self {
            case .entrada: return "Entrada"
            case .salida: return "Salida"
            case .transfer: return "Transferencia"
            }
        }

        var shortTitle: String {
            switch self {
            case .entrada: return "ENTRADA"
            case .salida: return "SALIDA"
            case .transfer: return "TRANSFER"
            }
        }
    }

    let title: String
    let subtitle: String
    let canRegister: Bool
    let inventoryValueText: String
    let totalWarehousesText: String
    let summaryMetrics: [MetricaResumen]
    let lowStockBannerText: String?
    let warehouseFilters: [FiltroAlmacen]
    let warehouseCards: [TarjetaAlmacen]
    let productCards: [TarjetaProducto]
    let movementCards: [TarjetaMovimiento]
}

struct WarehouseDashboardView: View {
    enum Tab: String, CaseIterable {
        case general = "General"
        case products = "Productos"
        case movements = "Movimientos"
    }

    let data: DatosDashboardAlmacen
    let onRegister: () -> Void
    let onSelectWarehouse: (String) -> Void

    @State private var pestanaActual: Tab = .general
    @State private var filtroAlmacenMovimiento = "all"
    @State private var filtroTipoMovimiento: DatosDashboardAlmacen.TipoMovimiento?

    private var movimientosFiltrados: [DatosDashboardAlmacen.TarjetaMovimiento] {
        data.movementCards.filter { item in
            let warehouseMatches = filtroAlmacenMovimiento == "all"
                || item.warehouseId == filtroAlmacenMovimiento
                || item.destinationWarehouseId == filtroAlmacenMovimiento
            let typeMatches = filtroTipoMovimiento == nil || item.type == filtroTipoMovimiento
            return warehouseMatches && typeMatches
        }
    }

    private var metricasResumenMovimiento: [DatosDashboardAlmacen.MetricaResumen] {
        let entries = movimientosFiltrados.filter { $0.type == .entrada }.count
        let exits = movimientosFiltrados.filter { $0.type == .salida }.count
        let transfers = movimientosFiltrados.filter { $0.type == .transfer }.count
        return [
            .init(title: "ENTRADA", value: "\(entries)", colorHex: "22C55E"),
            .init(title: "SALIDA", value: "\(exits)", colorHex: "EF4444"),
            .init(title: "TRANSF.", value: "\(transfers)", colorHex: "8B5CF6"),
            .init(title: "EVENTOS", value: "\(movimientosFiltrados.count)", colorHex: "3B82F6")
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            tabBar

            Group {
                switch pestanaActual {
                case .general:
                    generalContent
                case .products:
                    productsContent
                case .movements:
                    movementsContent
                }
            }
        }
        .background(PaletaAlmacen.background.ignoresSafeArea())
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(data.title)
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(Color.black)
                Text(data.subtitle)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Color(uiColor: .systemGray))
            }

            Spacer()

            if data.canRegister {
                Button(action: onRegister) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                        Text("Registrar")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(PaletaAlmacen.blue)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            tabButton(title: Tab.general.rawValue, tab: .general, icon: "building.2")
            tabButton(title: Tab.products.rawValue, tab: .products, icon: "shippingbox")
            tabButton(title: Tab.movements.rawValue, tab: .movements, icon: "arrow.left.arrow.right")
        }
        .padding(4)
        .background(Color(hex: "E5E7EB"))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private func tabButton(title: String, tab: Tab, icon: String) -> some View {
        Button(action: { pestanaActual = tab }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundStyle(pestanaActual == tab ? Color.black : Color(uiColor: .systemGray))
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(pestanaActual == tab ? Color.white : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .shadow(color: pestanaActual == tab ? Color.black.opacity(0.08) : .clear, radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }

    private var generalContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 12) {
                overviewCard
                if let lowStockBannerText = data.lowStockBannerText {
                    lowStockBanner(text: lowStockBannerText)
                }
                sectionLabel("ALMACENES")
                ForEach(data.warehouseCards) { warehouse in
                    warehouseCard(warehouse)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
    }

    private var productsContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 12) {
                ForEach(data.productCards) { product in
                    productCard(product)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
    }

    private var movementsContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 12) {
                filterRow
                movementTypeRow
                movementSummaryRow
                ForEach(movimientosFiltrados) { movement in
                    movementCard(movement)
                }
                if movimientosFiltrados.isEmpty {
                    Text("Sin movimientos registrados")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Color(uiColor: .systemGray))
                        .frame(maxWidth: .infinity, minHeight: 220)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("VISTA GENERAL")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.72))
                    Text(data.inventoryValueText)
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(Color.white)
                    Text("Valor total del stock")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.72))
                }
                Spacer()
                Text(data.totalWarehousesText)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.16))
                    .clipShape(Capsule())
            }

            HStack(spacing: 6) {
                ForEach(data.summaryMetrics) { metric in
                    VStack(spacing: 2) {
                        Text(metric.title)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.7))
                        Text(metric.value)
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(Color.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color(hex: "2563EB"), Color(hex: "4338CA")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 3)
    }

    private func lowStockBanner(text: String) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(hex: "D97706"))
            VStack(alignment: .leading, spacing: 2) {
                Text(text)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(hex: "92400E"))
                Text("Toca un almacén para registrar un movimiento.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(PaletaAlmacen.orange)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color(hex: "FFFBEB"))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(hex: "FDE68A"), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func warehouseCard(_ warehouse: DatosDashboardAlmacen.TarjetaAlmacen) -> some View {
        Button(action: { onSelectWarehouse(warehouse.id) }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: warehouse.colorHex))
                            .frame(width: 44, height: 44)
                        Image(systemName: "building.2")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(warehouse.name)
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(Color.black)
                        Text(warehouse.address)
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(Color(uiColor: .systemGray))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(uiColor: .tertiaryLabel))
                }

                HStack {
                    Text(warehouse.levelText)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(uiColor: .systemGray))
                    Spacer()
                    Text("\(warehouse.totalStockText) / \(warehouse.totalCapacityText)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.black)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(hex: "F3F4F6"))
                        Capsule()
                            .fill(Color(hex: warehouse.colorHex))
                            .frame(width: geometry.size.width * max(0, min(1, warehouse.fillRatio)))
                    }
                }
                .frame(height: 8)

                HStack(spacing: 8) {
                    chip(text: warehouse.productsText, bgHex: "F9FAFB", fgHex: "6B7280", icon: "shippingbox")
                    if let lowStockText = warehouse.lowStockText {
                        chip(text: lowStockText, bgHex: "FEF2F2", fgHex: "EF4444", icon: "exclamationmark.triangle")
                    }
                    Spacer()
                    Text(warehouse.valueText)
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(Color.black)
                }
            }
            .padding(16)
            .warehouseCardStyle()
        }
        .buttonStyle(.plain)
    }

    private func productCard(_ product: DatosDashboardAlmacen.TarjetaProducto) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Rectangle()
                .fill(Color(hex: product.colorHex))
                .frame(height: 3)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(hex: product.bgHex))
                        .frame(width: 36, height: 36)
                    Image(systemName: product.symbolName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(hex: product.colorHex))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(product.name)
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(Color.black)
                    Text("\(product.priceText) · Min: \(product.minimumText) · Cap: \(product.capacityText)")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(Color(uiColor: .systemGray))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.totalStockText)
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(product.isLow ? PaletaAlmacen.red : Color.black)
                    Text(product.healthText.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(product.isLow ? PaletaAlmacen.red : PaletaAlmacen.green)
                }
            }

            HStack {
                Text("Llenado en red — \(Int((product.fillRatio * 100).rounded()))%")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(Color(uiColor: .systemGray))
                Spacer()
                Text(product.totalValueText)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(uiColor: .systemGray))
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(hex: "F3F4F6"))
                    Capsule()
                        .fill(product.isLow ? PaletaAlmacen.red : Color(hex: product.colorHex))
                        .frame(width: geometry.size.width * max(0, min(1, product.fillRatio)))
                }
            }
            .frame(height: 8)

            VStack(spacing: 8) {
                ForEach(product.stocks) { stock in
                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(hex: stock.colorHex))
                                .frame(width: 8, height: 8)
                            Text(stock.warehouseName)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color(uiColor: .systemGray))
                        }
                        .frame(width: 78, alignment: .leading)

                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color(hex: "F3F4F6"))
                                Capsule()
                                    .fill(stock.isLow ? PaletaAlmacen.red : Color(hex: stock.colorHex))
                                    .frame(width: geometry.size.width * max(0, min(1, stock.fillRatio)))
                            }
                        }
                        .frame(height: 6)

                        Text(stock.stockText)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(stock.isLow ? PaletaAlmacen.red : Color.black)
                            .frame(width: 64, alignment: .trailing)
                    }

                    Text(stock.detailText)
                        .font(.system(size: 9, weight: .regular))
                        .foregroundStyle(Color(uiColor: .tertiaryLabel))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(16)
        .warehouseCardStyle()
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button(action: { filtroAlmacenMovimiento = "all" }) {
                    Text("Todos")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(filtroAlmacenMovimiento == "all" ? Color.white : Color(uiColor: .secondaryLabel))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(filtroAlmacenMovimiento == "all" ? Color(hex: "1F2937") : Color.white)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(filtroAlmacenMovimiento == "all" ? Color.clear : Color(uiColor: .separator), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                ForEach(data.warehouseFilters) { warehouse in
                    Button(action: { filtroAlmacenMovimiento = warehouse.id }) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color(hex: warehouse.colorHex))
                                .frame(width: 8, height: 8)
                            Text(warehouse.title)
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundStyle(filtroAlmacenMovimiento == warehouse.id ? Color.white : Color(uiColor: .secondaryLabel))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(filtroAlmacenMovimiento == warehouse.id ? Color(hex: warehouse.colorHex) : Color.white)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(filtroAlmacenMovimiento == warehouse.id ? Color.clear : Color(uiColor: .separator), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 1)
        }
    }

    private var movementTypeRow: some View {
        HStack(spacing: 8) {
            movementTypeButton(title: "Todos", type: nil, activeHex: "1F2937")
            movementTypeButton(title: "↓ Entrada", type: .entrada, activeHex: "22C55E")
            movementTypeButton(title: "↑ Salida", type: .salida, activeHex: "EF4444")
            movementTypeButton(title: "⇄ Transfer.", type: .transfer, activeHex: "8B5CF6")
        }
    }

    private func movementTypeButton(title: String, type: DatosDashboardAlmacen.TipoMovimiento?, activeHex: String) -> some View {
        Button(action: { filtroTipoMovimiento = type }) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(filtroTipoMovimiento == type ? Color.white : Color(uiColor: .secondaryLabel))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(filtroTipoMovimiento == type ? Color(hex: activeHex) : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(filtroTipoMovimiento == type ? Color.clear : Color(uiColor: .separator), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var movementSummaryRow: some View {
        HStack(spacing: 6) {
            ForEach(metricasResumenMovimiento) { metric in
                VStack(spacing: 2) {
                    Text(metric.title)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color(hex: metric.colorHex))
                    Text(metric.value)
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(Color(hex: metric.colorHex))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color(hex: metric.colorHex).opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(hex: metric.colorHex).opacity(0.15), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private func movementCard(_ movement: DatosDashboardAlmacen.TarjetaMovimiento) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Rectangle()
                .fill(Color(hex: movement.accentHex))
                .frame(height: 3)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(hex: movement.bgHex))
                        .frame(width: 32, height: 32)
                    Image(systemName: movement.symbolName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(hex: movement.colorHex))
                }

                Text(movement.productName)
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Color.black)

                Text(movement.type.shortTitle)
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(Color(hex: movement.colorHex))

                Spacer()

                Text(movement.quantityText)
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Color(hex: movement.colorHex))
            }

            HStack(spacing: 6) {
                if let sourceChipText = movement.sourceChipText, let sourceChipIcon = movement.sourceChipIcon {
                    chip(text: sourceChipText, bgHex: "F9FAFB", fgHex: "6B7280", icon: sourceChipIcon)
                }
                if movement.sourceChipText != nil && movement.destinationChipText != nil {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(uiColor: .tertiaryLabel))
                }
                if let destinationChipText = movement.destinationChipText, let destinationChipIcon = movement.destinationChipIcon {
                    chip(text: destinationChipText, bgHex: movement.bgHex, fgHex: movement.colorHex, icon: destinationChipIcon)
                }
                Spacer(minLength: 0)
            }

            Text(movement.note)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(Color(uiColor: .secondaryLabel))

            Text(movement.actorText + " · " + movement.dateText)
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(Color(uiColor: .tertiaryLabel))
        }
        .padding(16)
        .warehouseCardStyle()
    }

    private func chip(text: String, bgHex: String, fgHex: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
            Text(text)
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundStyle(Color(hex: fgHex))
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color(hex: bgHex))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func sectionLabel(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(uiColor: .secondaryLabel))
            Spacer()
        }
    }
}

private enum PaletaAlmacen {
    static let background = Color(hex: "F4F6FA")
    static let blue = Color(hex: "3B82F6")
    static let green = Color(hex: "22C55E")
    static let red = Color(hex: "EF4444")
    static let orange = Color(hex: "F59E0B")
}

private extension View {
    func warehouseCardStyle() -> some View {
        self
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

private extension Color {
    init(hex: String) {
        let hexSan = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        var int: UInt64 = 0
        Scanner(string: hexSan).scanHexInt64(&int)
        let r = Double((int & 0xFF0000) >> 16) / 255.0
        let g = Double((int & 0x00FF00) >> 8) / 255.0
        let b = Double(int & 0x0000FF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}
