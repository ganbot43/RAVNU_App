import SwiftUI
import Charts

struct CajeroDashboardViewData {
    struct Metric: Identifiable {
        let id = UUID()
        let title: String
        let value: String
        let icon: String
        let color: Color
    }

    struct WeekSale: Identifiable {
        let id = UUID()
        let day: String
        let value: Double
        let isHighlighted: Bool
    }

    let notificationCount: Int
    let metrics: [Metric]
    let weekSales: [WeekSale]
    let lowStockTitle: String
    let lowStockDetail: String
    let lowStockBadge: String
    let debtorName: String
    let debtorAmount: String
    let debtorStatus: String
}

struct CajeroDashboardView: View {
    let data: CajeroDashboardViewData

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    metricsSection
                    weekSalesSection
                    lowStockSection
                    debtorSection
                }
                .padding(.bottom, 24)
            }
        }
        .background(RavnuColor.background.ignoresSafeArea())
    }

    private var header: some View {
        HStack {
            Text("RAVNU")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(RavnuColor.text)

            Spacer()

            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(RavnuColor.blue)

                Text("\(data.notificationCount)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)
                    .frame(width: 16, height: 16)
                    .background(Circle().fill(RavnuColor.red))
                    .offset(x: 6, y: -6)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var metricsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(data.metrics) { metric in
                    VStack(alignment: .leading, spacing: 6) {
                        Image(systemName: metric.icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(metric.color)

                        Text(metric.title)
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundStyle(RavnuColor.gray)

                        Text(metric.value)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(metric.color)
                    }
                    .frame(width: 140, height: 90, alignment: .topLeading)
                    .padding(14)
                    .ravnuCard()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }

    private var weekSalesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("VENTAS ESTA SEMANA", color: RavnuColor.subtle)

            VStack(alignment: .leading, spacing: 12) {
                Text("Ventas esta semana")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(RavnuColor.text)

                Chart(data.weekSales) { item in
                    BarMark(
                        x: .value("Día", item.day),
                        y: .value("Monto", item.value)
                    )
                    .foregroundStyle(item.isHighlighted ? RavnuColor.blue : RavnuColor.blue.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .frame(height: 120)
                .chartYAxis(.hidden)
                .chartXAxis {
                    AxisMarks(values: .automatic) { value in
                        AxisValueLabel()
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(RavnuColor.gray)
                    }
                }
            }
            .padding(16)
            .ravnuCard()
            .padding(.horizontal, 16)
        }
        .padding(.top, 20)
    }

    private var lowStockSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("⚠️ ALERTAS DE STOCK BAJO", color: RavnuColor.orange)

            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(RavnuColor.orange)
                    .frame(width: 3)

                HStack {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(RavnuColor.orange)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(data.lowStockTitle)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(RavnuColor.text)

                            Text(data.lowStockDetail)
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundStyle(RavnuColor.gray)
                        }
                    }

                    Spacer()

                    Text(data.lowStockBadge)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(RavnuColor.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(RavnuColor.redSoft))
                }
                .padding(14)
            }
            .ravnuCard()
            .padding(.horizontal, 16)
        }
        .padding(.top, 20)
    }

    private var debtorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("CLIENTE CON MAYOR DEUDA", color: RavnuColor.subtle)

            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(RavnuColor.blue)
                    .frame(width: 3)

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(data.debtorName)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(RavnuColor.text)

                        Spacer()

                        Text(data.debtorStatus)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(RavnuColor.red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(RavnuColor.redSoft))
                    }

                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Deuda actual")
                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                .foregroundStyle(RavnuColor.gray)

                            Text(data.debtorAmount)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(RavnuColor.red)
                        }

                        Spacer()

                        Button(action: {}) {
                            Text("Ver Detalle →")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(RavnuColor.blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(RavnuColor.blue, lineWidth: 1.5)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .ravnuCard()
            .padding(.horizontal, 16)
        }
        .padding(.top, 20)
    }

    private func sectionLabel(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 16)
    }
}

private enum RavnuColor {
    static let blue = Color(hex: "#3B82F6")
    static let green = Color(hex: "#22C55E")
    static let red = Color(hex: "#EF4444")
    static let orange = Color(hex: "#F59E0B")
    static let text = Color(hex: "#111827")
    static let gray = Color(hex: "#6B7280")
    static let subtle = Color(hex: "#9CA3AF")
    static let background = Color(hex: "#F4F6FA")
    static let redSoft = Color(hex: "#FEE2E2")
}

private extension View {
    func ravnuCard() -> some View {
        self
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

private extension Color {
    init(hex: String) {
        let hexString = hex.replacingOccurrences(of: "#", with: "")
        var int: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&int)
        let red = Double((int >> 16) & 0xFF) / 255.0
        let green = Double((int >> 8) & 0xFF) / 255.0
        let blue = Double(int & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }
}
