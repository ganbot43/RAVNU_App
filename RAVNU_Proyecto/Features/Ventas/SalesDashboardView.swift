import Charts
import SwiftUI

struct SalesDashboardViewData {
    struct Metric: Identifiable {
        let id = UUID()
        let icon: String
        let label: String
        let value: String
        let sub: String
        let colorHex: String
    }

    struct WeekBar: Identifiable {
        let id = UUID()
        let label: String
        let value: Double
        var isHighlighted: Bool = false
    }

    struct TrendBar: Identifiable {
        let id = UUID()
        let label: String
        let cash: Double
        let credit: Double
    }

    struct ProductRow: Identifiable {
        let id = UUID()
        let name: String
        let revenue: Double
        var percent: Int = 0
        let colorHex: String
    }

    struct DistributionRow: Identifiable {
        let id = UUID()
        let colorHex: String
        let label: String
        let value: String
    }

    struct SaleRow: Identifiable {
        let id = UUID()
        let clientName: String
        let productInfo: String
        let total: String
        let paymentType: String
        let colorHex: String
        let date: String
    }

    let title: String
    let subtitle: String
    let canCreateSale: Bool
    let metrics: [Metric]
    let weekBars: [WeekBar]
    let trendBars: [TrendBar]
    let productRows: [ProductRow]
    let distributionRows: [DistributionRow]
    let totalSalesCountText: String
    let cashPercent: Double
    let salesRows: [SaleRow]
}

struct SalesDashboardView: View {
    let data: SalesDashboardViewData
    let onNewSale: () -> Void

    @State private var currentTab: Tab = .summary

    enum Tab {
        case summary
        case list
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            tabs

            Group {
                if currentTab == .summary {
                    summaryContent
                } else {
                    listContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(SalesColor.background.ignoresSafeArea())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
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

                if data.canCreateSale {
                    Button(action: onNewSale) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .bold))
                            Text("Nueva Venta")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(SalesColor.blue)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var tabs: some View {
        HStack(spacing: 4) {
            tabButton(title: "Resumen", tab: .summary)
            tabButton(title: "Lista de Ventas", tab: .list)
        }
        .padding(4)
        .background(Color(hex: "E5E7EB"))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private func tabButton(title: String, tab: Tab) -> some View {
        Button(action: { currentTab = tab }) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(currentTab == tab ? Color.black : Color(uiColor: .systemGray))
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(currentTab == tab ? Color.white : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(color: currentTab == tab ? Color.black.opacity(0.08) : .clear, radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }

    private var summaryContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 12) {
                metricsSection
                weeklyChartCard
                trendChartCard
                productChartCard
                distributionChartCard
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
    }

    private var listContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 12) {
                ForEach(data.salesRows) { sale in
                    SaleRowCardView(sale: sale)
                }
                if data.salesRows.isEmpty {
                    Text("Sin ventas registradas")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Color(uiColor: .systemGray))
                        .frame(maxWidth: .infinity, minHeight: 220)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
    }

    private var metricsSection: some View {
        HStack(spacing: 10) {
            ForEach(data.metrics) { metric in
                VStack(alignment: .leading, spacing: 6) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(hex: metric.colorHex))
                            .frame(width: 32, height: 32)
                        Image(systemName: metric.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.white)
                    }

                    Text(metric.label)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(uiColor: .systemGray))

                    Text(metric.value)
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(Color.black)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text(metric.sub)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(Color(uiColor: .systemGray))
                }
                .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
                .padding(12)
                .salesCard()
            }
        }
    }

    private var weeklyChartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Ventas Diarias")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.black)
                Spacer()
                HStack(spacing: 2) {
                    segmentPill(title: "Semana", active: true)
                    segmentPill(title: "Mes", active: false)
                }
                .padding(2)
                .background(Color(hex: "F3F4F6"))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            Chart(data.weekBars) { item in
                BarMark(x: .value("Día", item.label), y: .value("Monto", item.value))
                    .foregroundStyle(item.isHighlighted ? SalesColor.blue : Color(hex: "BFDBFE"))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .frame(height: 120)
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisValueLabel()
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(uiColor: .systemGray))
                }
            }
        }
        .padding(16)
        .salesCard()
    }

    private var trendChartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tendencia Efectivo vs Crédito")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.black)

            Chart {
                ForEach(data.trendBars) { item in
                    BarMark(x: .value("Mes", item.label), y: .value("Monto", item.credit))
                        .foregroundStyle(SalesColor.blue)
                    BarMark(x: .value("Mes", item.label), y: .value("Monto", item.cash))
                        .foregroundStyle(SalesColor.green)
                }
            }
            .frame(height: 110)
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisValueLabel()
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(uiColor: .systemGray))
                }
            }

            HStack(spacing: 16) {
                legendItem(color: SalesColor.green, label: "Efectivo")
                legendItem(color: SalesColor.blue, label: "Crédito")
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .salesCard()
    }

    private var productChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ventas por Producto")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.black)

            ForEach(data.productRows) { row in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(hex: row.colorHex))
                            .frame(width: 10, height: 10)
                        Text(row.name)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.black)
                        Spacer()
                        Text("\(row.percent)%")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(Color(uiColor: .systemGray))
                        Text(currencyString(row.revenue))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.black)
                    }

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color(hex: "F3F4F6"))
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color(hex: row.colorHex))
                                .frame(width: max(8, proxy.size.width * CGFloat(row.percent) / 100.0))
                        }
                    }
                    .frame(height: 6)
                }
                .frame(height: 38)
            }
        }
        .padding(16)
        .salesCard()
    }

    private var distributionChartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Distribución de Pagos")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.black)

            HStack(spacing: 20) {
                DonutChartView(cashPercent: max(0, min(1, data.cashPercent)))
                    .frame(width: 100, height: 100)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(data.distributionRows) { row in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color(hex: row.colorHex))
                                .frame(width: 10, height: 10)
                            Text(row.label)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(Color(uiColor: .systemGray))
                            Spacer()
                            Text(row.value)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.black)
                        }
                    }
                    Divider()
                    Text(data.totalSalesCountText)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(Color(uiColor: .systemGray))
                }
            }
        }
        .padding(16)
        .salesCard()
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(Color(uiColor: .systemGray))
        }
    }

    private func segmentPill(title: String, active: Bool) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(active ? Color.black : Color(uiColor: .systemGray))
            .frame(width: 66, height: 28)
            .background(active ? Color.white : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private func currencyString(_ amount: Double) -> String {
        String(format: "S/%.0f", amount)
    }
}

private struct SaleRowCardView: View {
    let sale: SalesDashboardViewData.SaleRow

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color(hex: sale.colorHex))
                .frame(height: 2)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(sale.clientName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.black)
                    Text(sale.productInfo)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color(uiColor: .systemGray))
                    Text(sale.date)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(Color(hex: "D1D5DB"))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(sale.total)
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(Color.black)
                    Text(sale.paymentType)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(hex: sale.colorHex))
                        .clipShape(Capsule())
                }
            }
            .padding(16)
        }
        .salesCard()
    }
}

private struct DonutChartView: View {
    let cashPercent: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(SalesColor.blue, lineWidth: 20)
            Circle()
                .trim(from: 0, to: cashPercent)
                .stroke(SalesColor.green, style: StrokeStyle(lineWidth: 20, lineCap: .butt))
                .rotationEffect(.degrees(-90))
            Circle()
                .fill(Color.white)
                .frame(width: 52, height: 52)
        }
    }
}

private enum SalesColor {
    static let background = Color(hex: "F4F6FA")
    static let blue = Color(hex: "3B82F6")
    static let green = Color(hex: "22C55E")
}

private extension View {
    func salesCard() -> some View {
        background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

private extension Color {
    init(hex: String) {
        let clean = hex.replacingOccurrences(of: "#", with: "")
        var value: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&value)
        self.init(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255.0,
            green: Double((value >> 8) & 0xFF) / 255.0,
            blue: Double(value & 0xFF) / 255.0,
            opacity: 1
        )
    }
}
