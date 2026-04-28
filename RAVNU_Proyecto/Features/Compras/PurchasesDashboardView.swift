import SwiftUI

struct DatosDashboardCompras {
    struct TarjetaProveedor: Identifiable {
        let id: String
        let initials: String
        let name: String
        let tags: [String]
        let subtitle: String
        let orderCountText: String
        let totalAmountText: String
        let ratingText: String
        let accentHex: String
        let progress: Double
    }

    struct TarjetaOrden: Identifiable {
        struct StockAlmacenResumen: Identifiable {
            let id = UUID()
            let warehouseName: String
            let stockText: String
            let capacityText: String
            let statusText: String
            let accentHex: String
        }

        let id: String
        let initials: String
        let providerName: String
        let productName: String
        let amountText: String
        let dateText: String
        let volumeText: String
        let warehouseText: String
        let workerText: String
        let noteText: String
        let statusText: String
        let statusAccentHex: String
        let accentHex: String
        let allocationText: String
    }

    struct ResumenProducto: Identifiable {
        let id = UUID()
        let name: String
        let totalStockText: String
        let coverageText: String
        let accentHex: String
        let warehouses: [TarjetaOrden.StockAlmacenResumen]
    }

    struct FilaRanking: Identifiable {
        let id = UUID()
        let rank: Int
        let initials: String
        let name: String
        let amountText: String
        let percentText: String
        let accentHex: String
        let progress: Double
    }

    struct SegmentoProducto: Identifiable {
        let id = UUID()
        let name: String
        let valueText: String
        let accentHex: String
        let share: Double
    }

    struct BarraProducto: Identifiable {
        let id = UUID()
        let shortName: String
        let accentHex: String
        let amountRatio: Double
        let volumeRatio: Double
    }

    let title: String
    let pendingBadgeText: String
    let canCreateOrder: Bool
    let providerCountText: String
    let tarjetasProveedor: [TarjetaProveedor]
    let totalSpendText: String
    let pendingCountText: String
    let receivedCountText: String
    let cancelledCountText: String
    let productSummaries: [ResumenProducto]
    let tarjetasOrden: [TarjetaOrden]
    let filasRanking: [FilaRanking]
    let segmentosProducto: [SegmentoProducto]
    let barrasProducto: [BarraProducto]
    let totalVolumeText: String
    let totalProvidersText: String
}

struct PurchaseOrderDetailData {
    struct Action: Identifiable {
        let id = UUID()
        let title: String
        let accentHex: String
        let isDestructive: Bool
        let handler: () -> Void
    }

    let providerName: String
    let productName: String
    let amountText: String
    let volumeText: String
    let dateText: String
    let statusText: String
    let statusAccentHex: String
    let warehouseText: String
    let workerText: String
    let noteText: String
    let allocationText: String
    let stockByWarehouse: [DatosDashboardCompras.TarjetaOrden.StockAlmacenResumen]
    let actions: [Action]
}

struct PurchasesDashboardView: View {
    enum Pestana: String, CaseIterable {
        case providers = "Proveedores"
        case orders = "Órdenes"
        case analytics = "Análisis"
    }

    enum FiltroOrden: String, CaseIterable {
        case all = "Todas"
        case pending = "Pendiente"
        case received = "Recibido"
        case cancelled = "Cancelado"
    }

    let data: DatosDashboardCompras
    let onBack: () -> Void
    let onAddProvider: () -> Void
    let onNewOrder: () -> Void
    let onSelectOrder: (String) -> Void

    @State private var pestanaSeleccionada: Pestana = .orders
    @State private var filtroOrdenSeleccionado: FiltroOrden = .all
    @State private var busquedaProveedor = ""
    @State private var modoAnalitica: ModoAnalitica = .spend

    enum ModoAnalitica: String, CaseIterable {
        case spend = "Gasto"
        case volume = "Volumen"
    }

    var body: some View {
        ZStack {
            Color(hex: "F4F6FA").ignoresSafeArea()

            VStack(spacing: 0) {
                header
                tabStrip

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        switch pestanaSeleccionada {
                        case .providers:
                            providersContent
                        case .orders:
                            ordersContent
                        case .analytics:
                            analyticsContent
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(hex: "172033"))
                    .frame(width: 40, height: 40)
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(data.title)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(Color(hex: "172033"))

            Spacer()

            Text(data.pendingBadgeText)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: "F59E0B"))
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(Color(hex: "FFF7E6"))
                .overlay(
                    Capsule()
                        .stroke(Color(hex: "F5C561"), lineWidth: 1)
                )
                .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
    }

    private var tabStrip: some View {
        HStack(spacing: 8) {
            ForEach(Pestana.allCases, id: \.rawValue) { tab in
                Button {
                    pestanaSeleccionada = tab
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: iconName(for: tab))
                            .font(.system(size: 12, weight: .semibold))
                        Text(tab.rawValue)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(pestanaSeleccionada == tab ? Color(hex: "172033") : Color(hex: "7A8699"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(pestanaSeleccionada == tab ? Color.white : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color(hex: "E9EDF3"))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 16)
    }

    private var providersContent: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color(hex: "A7B0BE"))
                    TextField("Buscar proveedor...", text: $busquedaProveedor)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                }
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)

                if data.canCreateOrder {
                    Button(action: onNewOrder) {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 48, height: 48)
                            .background(Color(hex: "F59E0B"))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(data.providerCountText)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: "8E9AAD"))
                .frame(maxWidth: .infinity, alignment: .leading)

            if data.canCreateOrder {
                Button(action: onAddProvider) {
                    Text("+ Agregar Proveedor")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: "F59E0B"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color(hex: "FFF7E6"))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            ForEach(proveedoresFiltrados) { provider in
                providerCard(provider)
            }
        }
    }

    private var ordersContent: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                metricCard(title: "GASTO TOTAL", value: data.totalSpendText, accent: "F59E0B")
                metricCard(title: "PENDIENTES", value: data.pendingCountText, accent: "F59E0B")
                metricCard(title: "RECIBIDAS", value: data.receivedCountText, accent: "22C55E")
            }

            if data.productSummaries.isEmpty == false {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Stock por producto y almacén")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: "172033"))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(data.productSummaries) { summary in
                                productSummaryCard(summary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(FiltroOrden.allCases, id: \.rawValue) { filter in
                        Button {
                            filtroOrdenSeleccionado = filter
                        } label: {
                            Text(filterTitle(filter))
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(filtroOrdenSeleccionado == filter ? .white : Color(hex: "7A8699"))
                                .padding(.horizontal, 12)
                                .frame(height: 34)
                                .background(filtroOrdenSeleccionado == filter ? Color(hex: "172033") : Color.white)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            ForEach(ordenesFiltradas) { order in
                orderCard(order)
            }

            if data.canCreateOrder {
                Button(action: onNewOrder) {
                    Text("+ Nueva Orden de Compra")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color(hex: "F59E0B"))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var analyticsContent: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                metricCard(title: "GASTO", value: data.totalSpendText, accent: "F59E0B")
                metricCard(title: "VOLUMEN", value: data.totalVolumeText, accent: "4F7CF7")
                metricCard(title: "PROVEEDORES", value: data.totalProvidersText, accent: "8B5CF6")
            }

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Ranking de Proveedores")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: "172033"))
                    Spacer()
                    Text("\(data.filasRanking.count) activos")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(hex: "8E9AAD"))
                }

                ForEach(data.filasRanking) { row in
                    rankingRow(row)
                }
            }
            .padding(18)
            .background(cardBackground)

            VStack(alignment: .leading, spacing: 16) {
                Text("Gasto por Producto")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: "172033"))

                HStack(spacing: 18) {
                    DonutChartView(slices: data.segmentosProducto)
                        .frame(width: 110, height: 110)

                    VStack(spacing: 10) {
                        ForEach(data.segmentosProducto) { slice in
                            HStack {
                                Circle()
                                    .fill(Color(hex: slice.accentHex))
                                    .frame(width: 8, height: 8)
                                Text(slice.name)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color(hex: "5E6B7E"))
                                Spacer()
                                Text(slice.valueText)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color(hex: "172033"))
                            }
                        }
                    }
                }
            }
            .padding(18)
            .background(cardBackground)

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Por Producto")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: "172033"))
                    Spacer()

                    HStack(spacing: 6) {
                        ForEach(ModoAnalitica.allCases, id: \.rawValue) { mode in
                            Button {
                                modoAnalitica = mode
                            } label: {
                                Text(mode.rawValue)
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(modoAnalitica == mode ? Color(hex: "172033") : Color(hex: "8E9AAD"))
                                    .padding(.horizontal, 12)
                                    .frame(height: 30)
                                    .background(modoAnalitica == mode ? Color.white : Color.clear)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(4)
                    .background(Color(hex: "F1F4F8"))
                    .clipShape(Capsule())
                }

                HStack(alignment: .bottom, spacing: 28) {
                    ForEach(data.barrasProducto) { bar in
                        VStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color(hex: bar.accentHex))
                                .frame(width: 34, height: max(18, 110 * (modoAnalitica == .spend ? bar.amountRatio : bar.volumeRatio)))
                            Text(bar.shortName)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(hex: "8E9AAD"))
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
            }
            .padding(18)
            .background(cardBackground)
        }
    }

    private var proveedoresFiltrados: [DatosDashboardCompras.TarjetaProveedor] {
        let query = busquedaProveedor.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return data.tarjetasProveedor }
        return data.tarjetasProveedor.filter {
            $0.name.lowercased().contains(query) || $0.subtitle.lowercased().contains(query)
        }
    }

    private var ordenesFiltradas: [DatosDashboardCompras.TarjetaOrden] {
        switch filtroOrdenSeleccionado {
        case .all:
            return data.tarjetasOrden
        case .pending:
            return data.tarjetasOrden.filter { $0.statusText.lowercased().contains("registr") || $0.statusText.lowercased().contains("aprobad") || $0.statusText.lowercased().contains("pagad") }
        case .received:
            return data.tarjetasOrden.filter { $0.statusText.lowercased().contains("recib") }
        case .cancelled:
            return data.tarjetasOrden.filter { $0.statusText.lowercased().contains("cancel") }
        }
    }

    private func filterTitle(_ filter: FiltroOrden) -> String {
        switch filter {
        case .all:
            return "Todas (\(data.tarjetasOrden.count))"
        case .pending:
            return "Pendiente (\(data.pendingCountText))"
        case .received:
            return "Recibido (\(data.receivedCountText))"
        case .cancelled:
            return "Cancelado (\(data.cancelledCountText))"
        }
    }

    private func iconName(for tab: Pestana) -> String {
        switch tab {
        case .providers: return "shippingbox"
        case .orders: return "doc.text"
        case .analytics: return "chart.bar"
        }
    }

    private func providerCard(_ provider: DatosDashboardCompras.TarjetaProveedor) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                Text(provider.initials)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(Color(hex: provider.accentHex))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(provider.name)
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(Color(hex: "172033"))
                        Spacer()
                        HStack(spacing: 2) {
                            ForEach(0..<4, id: \.self) { _ in
                                Image(systemName: "star.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color(hex: "F5A623"))
                            }
                            Text(provider.ratingText)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(hex: "5E6B7E"))
                        }
                    }

                    HStack(spacing: 6) {
                        ForEach(provider.tags, id: \.self) { tag in
                            tagPill(text: tag, accentHex: tag == "Preferido" ? "F5A623" : "4F7CF7")
                        }
                        Text(provider.subtitle)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color(hex: "8E9AAD"))
                    }

                    HStack(spacing: 10) {
                        Text(provider.orderCountText)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Color(hex: "8E9AAD"))
                        Text(provider.totalAmountText)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: "172033"))
                    }
                }
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(hex: "EEF2F6"))
                    Capsule()
                        .fill(Color(hex: provider.accentHex))
                        .frame(width: proxy.size.width * provider.progress)
                }
            }
            .frame(height: 4)
        }
        .padding(16)
        .background(cardBackground)
    }

    private func orderCard(_ order: DatosDashboardCompras.TarjetaOrden) -> some View {
        Button {
            onSelectOrder(order.id)
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color(hex: order.accentHex))
                    .frame(height: 3)

                HStack(alignment: .top) {
                    Text(order.initials)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Color(hex: order.accentHex))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(order.providerName)
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(Color(hex: "172033"))
                        Text("• \(order.productName)")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color(hex: "8E9AAD"))
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(order.amountText)
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(Color(hex: "172033"))
                        Text(order.dateText)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Color(hex: "8E9AAD"))
                    }
                }

                HStack(spacing: 18) {
                    orderMeta(text: order.volumeText, accentHex: "22C55E")
                    orderMeta(text: order.warehouseText, accentHex: "64748B")
                }

                Text(order.noteText)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(hex: "8E9AAD"))

                if order.allocationText.isEmpty == false {
                    Text(order.allocationText)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: "4F7CF7"))
                }

                Text(order.statusText)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: order.statusAccentHex))
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(Color(hex: order.statusAccentHex).opacity(0.12))
                    .clipShape(Capsule())
            }
            .padding(14)
            .background(cardBackground)
        }
        .buttonStyle(.plain)
    }

    private func productSummaryCard(_ summary: DatosDashboardCompras.ResumenProducto) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(summary.name)
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(Color(hex: "172033"))
                Spacer()
                Circle()
                    .fill(Color(hex: summary.accentHex))
                    .frame(width: 10, height: 10)
            }

            Text(summary.totalStockText)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(Color(hex: summary.accentHex))

            Text(summary.coverageText)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(hex: "8E9AAD"))

            VStack(alignment: .leading, spacing: 8) {
                ForEach(summary.warehouses) { stock in
                    stockWarehouseRow(stock)
                }
            }
        }
        .padding(16)
        .frame(width: 270, alignment: .leading)
        .background(cardBackground)
    }

    private func rankingRow(_ row: DatosDashboardCompras.FilaRanking) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text("#\(row.rank)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: "8E9AAD"))

                Text(row.initials)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Color(hex: row.accentHex))
                    .clipShape(Circle())

                Text(row.name)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: "172033"))

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(row.amountText)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(Color(hex: "172033"))
                    Text(row.percentText)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: "8E9AAD"))
                }
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(hex: "EEF2F6"))
                    Capsule()
                        .fill(Color(hex: row.accentHex))
                        .frame(width: proxy.size.width * row.progress)
                }
            }
            .frame(height: 6)
        }
    }

    private func metricCard(title: String, value: String, accent: String) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: "A1ADBD"))
            Text(value)
                .font(.system(size: 21, weight: .black, design: .rounded))
                .foregroundStyle(Color(hex: accent))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 86)
        .background(cardBackground)
    }

    private func tagPill(text: String, accentHex: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(Color(hex: accentHex))
            .padding(.horizontal, 10)
            .frame(height: 24)
            .background(Color(hex: accentHex).opacity(0.12))
            .clipShape(Capsule())
    }

    private func orderMeta(text: String, accentHex: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color(hex: accentHex))
                .frame(width: 6, height: 6)
            Text(text)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(hex: "7A8699"))
        }
    }

    private func stockWarehouseRow(_ stock: DatosDashboardCompras.TarjetaOrden.StockAlmacenResumen) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Circle()
                .fill(Color(hex: stock.accentHex))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(stock.warehouseName)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: "172033"))
                Text(stock.capacityText)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(hex: "8E9AAD"))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(stock.stockText)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: "172033"))
                Text(stock.statusText)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: stock.accentHex))
            }
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.white)
            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 3)
    }
}

struct PurchaseOrderDetailSheetView: View {
    let data: PurchaseOrderDetailData
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color(hex: "F4F6FA").ignoresSafeArea()

            VStack(spacing: 0) {
                Capsule()
                    .fill(Color(hex: "D6DCE5"))
                    .frame(width: 46, height: 5)
                    .padding(.top, 8)
                    .padding(.bottom, 10)

                HStack {
                    Button("Cerrar", action: onClose)
                        .font(.system(size: 18, weight: .regular, design: .rounded))
                        .foregroundStyle(Color(hex: "3B82F6"))
                    Spacer()
                    Text("Detalle de Orden")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(Color(hex: "172033"))
                    Spacer()
                    Color.clear.frame(width: 56, height: 1)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 14)

                Divider()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(data.providerName)
                                .font(.system(size: 24, weight: .black, design: .rounded))
                                .foregroundStyle(Color(hex: "172033"))
                            Text(data.productName)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(hex: "8E9AAD"))
                            HStack(spacing: 10) {
                                detalleBadge(data.statusText, accentHex: data.statusAccentHex)
                                detalleBadge(data.volumeText, accentHex: "22C55E")
                                detalleBadge(data.amountText, accentHex: "F59E0B")
                            }
                        }
                        .padding(18)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                        VStack(alignment: .leading, spacing: 10) {
                            detalleFila("Fecha", data.dateText)
                            detalleFila("Almacén principal", data.warehouseText)
                            detalleFila("Responsable", data.workerText)
                        }
                        .padding(18)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                        if data.noteText.isEmpty == false {
                            bloqueTexto("Notas", data.noteText)
                        }

                        if data.allocationText.isEmpty == false {
                            bloqueTexto("Distribución final", data.allocationText)
                        }

                        if data.stockByWarehouse.isEmpty == false {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Stock actual del producto")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color(hex: "172033"))
                                ForEach(data.stockByWarehouse) { stock in
                                    stockWarehouseRow(stock)
                                }
                            }
                            .padding(18)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }

                        if data.actions.isEmpty == false {
                            VStack(spacing: 10) {
                                ForEach(data.actions) { action in
                                    Button(action.title) {
                                        action.handler()
                                    }
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                                    .foregroundStyle(action.isDestructive ? Color(hex: "EF4444") : .white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .background(action.isDestructive ? Color(hex: "FEF2F2") : Color(hex: action.accentHex))
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    private func detalleFila(_ titulo: String, _ valor: String) -> some View {
        HStack {
            Text(titulo)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: "8E9AAD"))
            Spacer()
            Text(valor)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: "172033"))
        }
    }

    private func detalleBadge(_ texto: String, accentHex: String) -> some View {
        Text(texto)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(Color(hex: accentHex))
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(Color(hex: accentHex).opacity(0.12))
            .clipShape(Capsule())
    }

    private func bloqueTexto(_ titulo: String, _ valor: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(titulo)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: "172033"))
            Text(valor)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color(hex: "6F7B8D"))
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func stockWarehouseRow(_ stock: DatosDashboardCompras.TarjetaOrden.StockAlmacenResumen) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Circle()
                .fill(Color(hex: stock.accentHex))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(stock.warehouseName)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: "172033"))
                Text(stock.capacityText)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(hex: "8E9AAD"))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(stock.stockText)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: "172033"))
                Text(stock.statusText)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: stock.accentHex))
            }
        }
    }
}

private struct DonutChartView: View {
    let slices: [DatosDashboardCompras.SegmentoProducto]

    var body: some View {
        ZStack {
            ForEach(Array(slices.enumerated()), id: \.offset) { index, slice in
                DonutSliceShape(
                    start: startAngle(for: index),
                    end: endAngle(for: index)
                )
                .stroke(Color(hex: slice.accentHex), style: StrokeStyle(lineWidth: 18, lineCap: .round))
            }

            Circle()
                .fill(Color.white)
                .frame(width: 44, height: 44)
        }
    }

    private func startAngle(for index: Int) -> Angle {
        let share = slices.prefix(index).reduce(0.0) { $0 + $1.share }
        return .degrees((share * 360) - 90)
    }

    private func endAngle(for index: Int) -> Angle {
        let share = slices.prefix(index + 1).reduce(0.0) { $0 + $1.share }
        return .degrees((share * 360) - 90)
    }
}

private struct DonutSliceShape: Shape {
    let start: Angle
    let end: Angle

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: min(rect.width, rect.height) / 2,
            startAngle: start,
            endAngle: end,
            clockwise: false
        )
        return path
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
