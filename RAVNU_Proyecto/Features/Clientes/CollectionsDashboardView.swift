import SwiftUI

struct CollectionsDashboardData {
    struct Metric {
        let title: String
        let value: String
        let detail: String
        let accentHex: String
    }

    struct ProgressSlice: Identifiable {
        let id = UUID()
        let label: String
        let valueText: String
        let accentHex: String
        let share: Double
    }

    struct DebtRow: Identifiable {
        enum Status {
            case vencido
            case enRiesgo

            var title: String {
                switch self {
                case .vencido: return "Vencido"
                case .enRiesgo: return "En Riesgo"
                }
            }

            var accentHex: String {
                switch self {
                case .vencido: return "EF4444"
                case .enRiesgo: return "F59E0B"
                }
            }
        }

        let id: String
        let name: String
        let amountText: String
        let detailText: String
        let status: Status
        let progressValue: Double
    }

    struct CuotaRow: Identifiable {
        enum Status {
            case pendiente
            case vencido
            case pagado

            var title: String {
                switch self {
                case .pendiente: return "Pendiente"
                case .vencido: return "Vencido"
                case .pagado: return "Pagado"
                }
            }

            var accentHex: String {
                switch self {
                case .pendiente: return "F59E0B"
                case .vencido: return "EF4444"
                case .pagado: return "4CCB63"
                }
            }
        }

        let id: String
        let clientName: String
        let installmentText: String
        let amountText: String
        let dueText: String
        let progressText: String
        let progressValue: Double
        let status: Status
    }

    let overdueMetric: Metric
    let pendingMetric: Metric
    let todayMetric: Metric
    let progressText: String
    let progressSlices: [ProgressSlice]
    let alertText: String?
    let debtRows: [DebtRow]
    let cuotaRows: [CuotaRow]
    let selectedFilter: CuotasViewController.Filter
    let canPay: Bool
}

struct CollectionsDashboardView: View {
    let data: CollectionsDashboardData
    let onBack: () -> Void
    let onOpenPayment: (UUID?) -> Void
    let onOpenGenericPayment: () -> Void
    let onSelectFilter: (CuotasViewController.Filter) -> Void

    @State private var selectedTab: Tab = .analitica

    enum Tab {
        case analitica
        case cuotas
    }

    var body: some View {
        ZStack {
            Color(hex: "F4F6FA").ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    header
                    tabBar

                    if selectedTab == .analitica {
                        analyticsTab
                    } else {
                        cuotasTab
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 32)
            }
        }
    }

    private var header: some View {
        HStack {
            CircleIconButton(symbol: "chevron.left", action: onBack)
            Spacer()
            Text("Cobros")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: "1F2937"))
            Spacer()
            if data.canPay {
                Button(action: onOpenGenericPayment) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text("Pagar")
                    }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 34)
                    .background(Color(hex: "4F83F6"))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 70, height: 34)
            }
        }
    }

    private var tabBar: some View {
        HStack(spacing: 8) {
            collectionsTabButton(title: "Analítica", isActive: selectedTab == .analitica) {
                selectedTab = .analitica
            }
            collectionsTabButton(title: "Cuotas", isActive: selectedTab == .cuotas) {
                selectedTab = .cuotas
            }
        }
        .padding(6)
        .background(Color(hex: "E5E7EB"))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func collectionsTabButton(title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(isActive ? Color(hex: "1F2937") : Color(hex: "64748B"))
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(isActive ? .white : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var analyticsTab: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                metricCard(data.overdueMetric)
                metricCard(data.pendingMetric)
                metricCard(data.todayMetric)
            }

            DashboardCard {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Progreso de Cobranza")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(hex: "1F2937"))
                            Text(currentMonthLabel())
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(Color(hex: "94A3B8"))
                        }
                        Spacer()
                        Text("↘︎ \(data.progressText)")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: "4CCB63"))
                    }

                    HStack(spacing: 20) {
                        CollectionsDonutChart(items: data.progressSlices)
                            .frame(width: 120, height: 120)
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(data.progressSlices) { slice in
                                CollectionsLegendRow(slice: slice)
                            }
                        }
                    }

                    if let alertText = data.alertText {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "exclamationmark.circle")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color(hex: "EF4444"))
                            Text(alertText)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color(hex: "EF4444"))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(hex: "FEF2F2"))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            }

            DashboardCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Clientes con Deuda Activa")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: "1F2937"))
                    ForEach(data.debtRows) { row in
                        DebtRowView(row: row)
                    }
                }
            }
        }
    }

    private var cuotasTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(CuotasViewController.Filter.allCases, id: \.rawValue) { filter in
                        Button(action: { onSelectFilter(filter) }) {
                            Text(filter.rawValue)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(data.selectedFilter == filter ? .white : Color(hex: "64748B"))
                                .padding(.horizontal, 14)
                                .frame(height: 32)
                                .background(data.selectedFilter == filter ? Color(hex: "4F83F6") : .white)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            ForEach(data.cuotaRows) { cuota in
                CuotaCardView(cuota: cuota, canPay: data.canPay) {
                    onOpenPayment(UUID(uuidString: cuota.id))
                }
            }
        }
    }

    private func metricCard(_ metric: CollectionsDashboardData.Metric) -> some View {
        VStack(spacing: 8) {
            Circle()
                .fill(Color(hex: metric.accentHex).opacity(0.12))
                .frame(width: 40, height: 40)
                .overlay {
                    Circle()
                        .stroke(Color(hex: metric.accentHex), lineWidth: 1.5)
                        .frame(width: 14, height: 14)
                }

            Text(metric.title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: "94A3B8"))
            Text(metric.value)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(Color(hex: metric.accentHex))
            Text(metric.detail)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color(hex: "94A3B8"))
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.06), radius: 8, y: 4)
    }

    private func currentMonthLabel() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_PE")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: Date()).capitalized
    }
}

private struct DashboardCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .shadow(color: Color.black.opacity(0.07), radius: 10, y: 4)
    }
}

private struct CollectionsLegendRow: View {
    let slice: CollectionsDashboardData.ProgressSlice

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 8) {
                    Circle().fill(Color(hex: slice.accentHex)).frame(width: 10, height: 10)
                    Text(slice.label)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(hex: "64748B"))
                }
                Spacer()
                Text(slice.valueText)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: "334155"))
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(hex: "E5E7EB"))
                    Capsule().fill(Color(hex: slice.accentHex))
                        .frame(width: proxy.size.width * slice.share)
                }
            }
            .frame(height: 6)
        }
    }
}

private struct CollectionsDonutChart: View {
    let items: [CollectionsDashboardData.ProgressSlice]

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(hex: "E5E7EB"), lineWidth: 24)
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                Circle()
                    .trim(from: start(index), to: end(index))
                    .stroke(Color(hex: item.accentHex), style: StrokeStyle(lineWidth: 24, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
            }
        }
    }

    private func start(_ index: Int) -> Double {
        items.prefix(index).reduce(0.0) { $0 + $1.share }
    }

    private func end(_ index: Int) -> Double {
        items.prefix(index + 1).reduce(0.0) { $0 + $1.share }
    }
}

private struct DebtRowView: View {
    let row: CollectionsDashboardData.DebtRow

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(row.name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: "1F2937"))
                Spacer()
                Text(row.status.title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .frame(height: 24)
                    .background(Color(hex: row.status.accentHex))
                    .clipShape(Capsule())
                Text(row.amountText)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(Color(hex: row.status.accentHex))
            }

            Text(row.detailText)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color(hex: "94A3B8"))

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(hex: "E5E7EB"))
                    Capsule().fill(Color(hex: row.status == .vencido ? "F0B232" : "4F83F6"))
                        .frame(width: proxy.size.width * row.progressValue)
                }
            }
            .frame(height: 6)
        }
    }
}

private struct CuotaCardView: View {
    let cuota: CollectionsDashboardData.CuotaRow
    let canPay: Bool
    let onRegister: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Rectangle()
                .fill(Color(hex: cuota.status.accentHex))
                .frame(height: 3)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(cuota.clientName)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: "1F2937"))
                    Text(cuota.installmentText)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(hex: "94A3B8"))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    Text(cuota.status.title)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .frame(height: 24)
                        .background(Color(hex: cuota.status.accentHex))
                        .clipShape(Capsule())
                    Text(cuota.amountText)
                        .font(.system(size: 19, weight: .black, design: .rounded))
                        .foregroundStyle(Color(hex: cuota.status == .pagado ? "22C55E" : "1F2937"))
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Progreso de cuotas")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(hex: "94A3B8"))
                    Spacer()
                    Text(cuota.progressText)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: "64748B"))
                }
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(hex: "E5E7EB"))
                        Capsule().fill(Color(hex: cuota.status.accentHex))
                            .frame(width: proxy.size.width * cuota.progressValue)
                    }
                }
                .frame(height: 6)
            }

            HStack {
                HStack(spacing: 6) {
                    Image(systemName: cuota.status == .vencido ? "exclamationmark.circle" : "clock")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(hex: cuota.status.accentHex))
                    Text(cuota.dueText)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(hex: cuota.status.accentHex))
                }
                Spacer()
                if canPay && cuota.status != .pagado {
                    Button(action: onRegister) {
                        Text("$ Registrar")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .frame(height: 32)
                            .background(Color(hex: "4F83F6"))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: Color.black.opacity(0.07), radius: 10, y: 4)
    }
}

private struct CircleIconButton: View {
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color(hex: "475569"))
                .frame(width: 40, height: 40)
                .background(.white)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.06), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
    }
}

private extension Color {
    init(hex: String) {
        let sanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
