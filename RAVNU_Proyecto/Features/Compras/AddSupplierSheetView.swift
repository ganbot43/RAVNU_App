import SwiftUI

struct AddSupplierDraft {
    let name: String
    let category: String
    let phone: String
    let email: String
    let address: String
    let rating: Int
    let isPreferred: Bool
    let isVerified: Bool
}

struct AddSupplierSheetView: View {
    let onCancel: () -> Void
    let onSave: (AddSupplierDraft) -> Void

    @State private var name = ""
    @State private var category = "Nacional"
    @State private var phone = ""
    @State private var email = ""
    @State private var address = ""
    @State private var rating = 0
    @State private var isPreferred = false
    @State private var isVerified = false

    private let categories = ["Nacional", "Internacional", "Estatal", "Cadena nacional"]

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
                    VStack(alignment: .leading, spacing: 20) {
                        fieldSection(title: "Nombre *") {
                            iconTextField(systemName: "building.2", placeholder: "Ej. PetroPerú, Repsol...", text: $name, accent: "F5C22B")
                        }

                        fieldSection(title: "Categoría") {
                            WrappingChips(items: categories, selected: category) { category = $0 }
                        }

                        HStack(spacing: 12) {
                            fieldSection(title: "Teléfono") {
                                iconTextField(systemName: "phone", placeholder: "01-XXX-XXXX", text: $phone, accent: "DDE3EC")
                            }
                            fieldSection(title: "Email") {
                                iconTextField(systemName: "envelope", placeholder: "email@...", text: $email, accent: "DDE3EC")
                            }
                        }

                        fieldSection(title: "Dirección") {
                            iconTextField(systemName: "location", placeholder: "Av. ..., Lima", text: $address, accent: "DDE3EC")
                        }

                        fieldSection(title: "Calificación") {
                            HStack(spacing: 8) {
                                ForEach(1...5, id: \.self) { value in
                                    Button {
                                        rating = value
                                    } label: {
                                        Image(systemName: value <= rating ? "star.fill" : "star")
                                            .font(.system(size: 24, weight: .semibold))
                                            .foregroundStyle(value <= rating ? Color(hex: "F5C22B") : Color(hex: "E3E8F0"))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        HStack(spacing: 12) {
                            togglePill(title: "Preferido", systemName: "star", isOn: $isPreferred)
                            togglePill(title: "Verificado", systemName: "checkmark.shield", isOn: $isVerified)
                        }

                        Button {
                            onSave(
                                AddSupplierDraft(
                                    name: name,
                                    category: category,
                                    phone: phone,
                                    email: email,
                                    address: address,
                                    rating: rating,
                                    isPreferred: isPreferred,
                                    isVerified: isVerified
                                )
                            )
                        } label: {
                            Text("Agregar Proveedor")
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
    }

    private var header: some View {
        HStack {
            Button("Cancelar", action: onCancel)
                .font(.system(size: 18, weight: .regular, design: .rounded))
                .foregroundStyle(Color(hex: "3B82F6"))
            Spacer()
            Text("Agregar Proveedor")
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

    private func iconTextField(systemName: String, placeholder: String, text: Binding<String>, accent: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemName)
                .foregroundStyle(Color(hex: "7A8699"))
            TextField(placeholder, text: text)
                .font(.system(size: 18, weight: .medium, design: .rounded))
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
        .background(Color(hex: "F2F5F9"))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(hex: accent), lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func togglePill(title: String, systemName: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: systemName)
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .foregroundStyle(isOn.wrappedValue ? Color(hex: "F59E0B") : Color(hex: "98A2B3"))
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(isOn.wrappedValue ? Color(hex: "FFF7E6") : Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isOn.wrappedValue ? Color(hex: "F5C561") : Color(hex: "E6EBF2"), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct WrappingChips: View {
    let items: [String]
    let selected: String
    let onSelect: (String) -> Void

    var body: some View {
        FlexibleView(data: items, spacing: 8, alignment: .leading) { item in
            Button {
                onSelect(item)
            } label: {
                Text(item)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(selected == item ? .white : Color(hex: "6F7B8D"))
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .background(selected == item ? Color(hex: "F59E0B") : Color(hex: "F1F4F8"))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }
}

private struct FlexibleView<Data: Collection, Content: View>: View where Data.Element: Hashable {
    let data: Data
    let spacing: CGFloat
    let alignment: HorizontalAlignment
    let content: (Data.Element) -> Content

    init(data: Data, spacing: CGFloat, alignment: HorizontalAlignment, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data
        self.spacing = spacing
        self.alignment = alignment
        self.content = content
    }

    var body: some View {
        VStack(alignment: alignment, spacing: spacing) {
            let rows = generateRows()
            ForEach(rows.indices, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(rows[row], id: \.self) { item in
                        content(item)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func generateRows() -> [[Data.Element]] {
        var rows: [[Data.Element]] = [[]]
        var currentRow = 0
        for item in data {
            if rows[currentRow].count >= 3 {
                rows.append([])
                currentRow += 1
            }
            rows[currentRow].append(item)
        }
        return rows
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
