import SwiftUI

struct MoreDashboardViewData {
    struct TeamMember: Identifiable {
        let id = UUID()
        let initials: String
        let colorHex: String
    }

    struct VisibleModules {
        let tesoreria: Bool
        let cobros: Bool
        let compras: Bool
        let rrhh: Bool
    }

    let title: String
    let subtitle: String
    let userName: String
    let userRole: String
    let userSubtitle: String
    let userInitials: String
    let treasuryAmount: String
    let treasuryDelta: String
    let treasuryIncome: String
    let treasuryExpense: String
    let collectionsAmount: String
    let collectionsOverdue: String
    let collectionsPending: String
    let purchasesAmount: String
    let purchasesPending: String
    let purchasesSuppliers: String
    let teamTitle: String
    let teamSubtitle: String
    let teamCount: String
    let teamStatus: String
    let teamMembers: [TeamMember]
    let sparklineValues: [Double]
    let visibleModules: VisibleModules
}

struct MoreDashboardView: View {
    let data: MoreDashboardViewData
    let onOpenTreasury: () -> Void
    let onOpenCollections: () -> Void
    let onOpenPurchases: () -> Void
    let onOpenHumanResources: () -> Void
    let onLogout: () -> Void

    var body: some View {
        ZStack {
            Color(hex: "F4F6FA").ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    profileCard

                    if data.visibleModules.tesoreria {
                        treasuryCard
                    }

                    moduleGrid

                    if data.visibleModules.rrhh {
                        hrCard
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(data.title)
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(Color(hex: "172033"))

            Text(data.subtitle)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var profileCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.22))
                    .frame(width: 42, height: 42)

                Text(data.userInitials)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(data.userName)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text(data.userRole)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.85))

                Text(data.userSubtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.72))
            }

            Spacer()

            Button(action: onLogout) {
                Image(systemName: "arrow.right.square")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(Color.white.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "4F7CF7"), Color(hex: "3B82F6")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
    }

    private var treasuryCard: some View {
        Button(action: onOpenTreasury) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TESORERÍA")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: "9AA3B2"))

                        Text("Flujo de caja")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(hex: "C5CBD4"))
                }

                Text(data.treasuryAmount)
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(Color(hex: "172033"))

                Text(data.treasuryDelta)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(hex: "EF4444"))

                SparklineShape(values: data.sparklineValues)
                    .stroke(Color(hex: "4CCB68"), lineWidth: 2)
                    .frame(height: 30)

                HStack(spacing: 18) {
                    legendDot(text: data.treasuryIncome, color: Color(hex: "4CCB68"))
                    legendDot(text: data.treasuryExpense, color: Color(hex: "F87171"))
                }
            }
            .padding(18)
            .background(cardBackground)
        }
        .buttonStyle(.plain)
    }

    private var moduleGrid: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 14) {
                if data.visibleModules.cobros {
                    smallCard(
                        icon: "wallet.pass",
                        iconColor: Color(hex: "4F7CF7"),
                        iconBackground: Color(hex: "E8F0FF"),
                        title: "COBROS",
                        amount: data.collectionsAmount,
                        pillOne: data.collectionsOverdue,
                        pillOneColor: Color(hex: "EF4444"),
                        pillOneBackground: Color(hex: "FEF2F2"),
                        pillTwo: data.collectionsPending,
                        pillTwoColor: Color(hex: "F59E0B"),
                        pillTwoBackground: Color(hex: "FFF7E6"),
                        action: onOpenCollections
                    )
                }
            }

            VStack(spacing: 14) {
                if data.visibleModules.compras {
                    smallCard(
                        icon: "cart",
                        iconColor: Color(hex: "F59E0B"),
                        iconBackground: Color(hex: "FFF7E6"),
                        title: "COMPRAS",
                        amount: data.purchasesAmount,
                        pillOne: data.purchasesPending,
                        pillOneColor: Color(hex: "F59E0B"),
                        pillOneBackground: Color(hex: "FFF7E6"),
                        pillTwo: data.purchasesSuppliers,
                        pillTwoColor: Color(hex: "D97706"),
                        pillTwoBackground: Color(hex: "FFF7E6"),
                        action: onOpenPurchases
                    )
                }
            }
        }
    }

    private var hrCard: some View {
        Button(action: onOpenHumanResources) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(data.teamTitle)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: "8E9AAD"))
                        Text(data.teamSubtitle)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(hex: "C5CBD4"))
                }

                HStack(spacing: 10) {
                    HStack(spacing: -10) {
                        ForEach(data.teamMembers) { member in
                            Text(member.initials)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(width: 34, height: 34)
                                .background(Color(hex: member.colorHex))
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(data.teamCount)
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(Color(hex: "172033"))
                        Text(data.teamStatus)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color(hex: "22C55E"))
                    }
                }
            }
            .padding(18)
            .background(cardBackground)
        }
        .buttonStyle(.plain)
    }

    private func smallCard(
        icon: String,
        iconColor: Color,
        iconBackground: Color,
        title: String,
        amount: String,
        pillOne: String,
        pillOneColor: Color,
        pillOneBackground: Color,
        pillTwo: String,
        pillTwoColor: Color,
        pillTwoBackground: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(iconColor)
                        .frame(width: 34, height: 34)
                        .background(iconBackground)
                        .clipShape(Circle())

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(hex: "C5CBD4"))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: "8E9AAD"))
                    Text(amount)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(Color(hex: "172033"))
                }

                VStack(alignment: .leading, spacing: 8) {
                    pill(text: pillOne, textColor: pillOneColor, background: pillOneBackground)
                    pill(text: pillTwo, textColor: pillTwoColor, background: pillTwoBackground)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 185, alignment: .topLeading)
            .padding(18)
            .background(cardBackground)
        }
        .buttonStyle(.plain)
    }

    private func pill(text: String, textColor: Color, background: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(textColor)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(textColor)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(background)
        .clipShape(Capsule())
    }

    private func legendDot(text: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color(hex: "8E9AAD"))
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color.white)
            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 3)
    }
}

private struct SparklineShape: Shape {
    let values: [Double]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard values.count > 1, let upper = values.max(), let lower = values.min() else { return path }
        let range = Swift.max(upper - lower, 0.0001)

        for (index, value) in values.enumerated() {
            let x = rect.width * CGFloat(index) / CGFloat(values.count - 1)
            let normalized = (value - lower) / range
            let y = rect.height * (1 - CGFloat(normalized))
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
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
