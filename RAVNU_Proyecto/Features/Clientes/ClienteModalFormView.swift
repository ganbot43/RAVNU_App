import SwiftUI

struct ClienteModalFormData {
    var nombre = ""
    var documento = ""
    var telefono = ""
    var correo = ""
    var direccion = ""
    var limiteCredito = ""
    var tipoDocumento: TipoDocumento = .dni

    enum TipoDocumento: String, CaseIterable, Identifiable {
        case dni = "DNI"
        case ruc = "RUC"

        var id: String { rawValue }
        var maxLength: Int {
            switch self {
            case .dni: return 8
            case .ruc: return 11
            }
        }

        var placeholder: String {
            switch self {
            case .dni: return "8 dígitos"
            case .ruc: return "11 dígitos"
            }
        }
    }

    var canSave: Bool {
        !nombre.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        documento.count == tipoDocumento.maxLength &&
        telefono.count == 9
    }
}

struct ClienteModalFormView: View {
    let onCancel: () -> Void
    let onSave: (ClienteModalFormData) -> Void

    @State private var form = ClienteModalFormData()

    private var creditValue: Double {
        Double(form.limiteCredito.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 18) {
                    heroCard
                    sectionCard(title: "Identidad del cliente", subtitle: "Registra a la persona o empresa con la base comercial mínima para vender sin fricción.") {
                        fieldCard(
                            title: "Nombre / razón social",
                            icon: "person.fill",
                            placeholder: "Nombre completo o empresa",
                            text: $form.nombre
                        )

                        VStack(alignment: .leading, spacing: 10) {
                            sectionLabel("Documento")
                            HStack(spacing: 12) {
                                Picker("Documento", selection: $form.tipoDocumento) {
                                    ForEach(ClienteModalFormData.TipoDocumento.allCases) { tipo in
                                        Text(tipo.rawValue).tag(tipo)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 120)
                                .onChange(of: form.tipoDocumento) { _, newValue in
                                    form.documento = String(form.documento.prefix(newValue.maxLength))
                                }

                                inputCard(
                                    icon: "doc.text.fill",
                                    placeholder: form.tipoDocumento.placeholder,
                                    text: Binding(
                                        get: { form.documento },
                                        set: { form.documento = String($0.filter(\.isNumber).prefix(form.tipoDocumento.maxLength)) }
                                    ),
                                    keyboardType: .numberPad
                                )
                            }
                        }
                    }

                    sectionCard(title: "Contacto y ubicación", subtitle: "Estos datos alimentan cobranza, seguimiento y visitas operativas.") {
                        fieldCard(
                            title: "Teléfono",
                            icon: "phone.fill",
                            placeholder: "9XX-XXX-XXX",
                            text: Binding(
                                get: { form.telefono },
                                set: { form.telefono = String($0.filter(\.isNumber).prefix(9)) }
                            ),
                            keyboardType: .phonePad
                        )

                        fieldCard(
                            title: "Correo electrónico",
                            icon: "envelope.fill",
                            placeholder: "correo@ejemplo.com",
                            text: $form.correo,
                            keyboardType: .emailAddress
                        )

                        fieldCard(
                            title: "Dirección",
                            icon: "location.fill",
                            placeholder: "Calle, número, distrito",
                            text: $form.direccion
                        )
                    }

                    sectionCard(title: "Línea de crédito", subtitle: "Define el techo comercial inicial. El estado real se recalculará después con ventas y cobros.") {
                        fieldCard(
                            title: "Límite de crédito (S/)",
                            icon: "creditcard.fill",
                            placeholder: "0.00",
                            text: Binding(
                                get: { form.limiteCredito },
                                set: { form.limiteCredito = $0.filter { $0.isNumber || $0 == "." || $0 == "," } }
                            ),
                            keyboardType: .decimalPad,
                            prefix: "S/"
                        )
                        statusCard
                    }

                    Button(action: { onSave(form) }) {
                        HStack(spacing: 8) {
                            Image(systemName: "person.crop.circle.badge.plus")
                            Text("Guardar cliente")
                        }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "2563EB"), Color(hex: "1D4ED8")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(!form.canSave)
                    .opacity(form.canSave ? 1 : 0.45)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .background(Color(hex: "F3F7FB").ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar", action: onCancel)
                }
                ToolbarItem(placement: .principal) {
                    Text("Nuevo cliente")
                        .font(.system(size: 18, weight: .bold))
                }
            }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Activa un nuevo cliente")
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(.white)
                    Text("Deja lista la ficha comercial con documento, contacto y capacidad de crédito para vender sin campos vacíos.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.84))
                }
                Spacer()
                Image(systemName: "person.text.rectangle.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 54, height: 54)
                    .background(Color.white.opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            HStack(spacing: 10) {
                heroMetric(title: "DOC.", value: form.tipoDocumento.rawValue)
                heroMetric(title: "TEL.", value: form.telefono.isEmpty ? "Pendiente" : form.telefono)
                heroMetric(title: "CRÉDITO", value: creditValue > 0 ? "S/\(String(format: "%.0f", creditValue))" : "Definir")
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color(hex: "0F172A"), Color(hex: "2563EB")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Estado inicial")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(hex: "0F172A"))
                Spacer()
                Text("Activo")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color(hex: "16A34A")))
            }

            Text("El estado se actualizará automáticamente según el historial de pagos y el uso del crédito del cliente.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(hex: "166534"))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                statusMetric(title: "Documento", value: form.tipoDocumento.rawValue)
                statusMetric(title: "Crédito", value: creditValue > 0 ? "S/\(String(format: "%.0f", creditValue))" : "Sin línea")
            }
        }
        .padding(16)
        .background(Color(hex: "ECFDF5"))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(hex: "A7F3D0"), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func sectionCard<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(Color(hex: "0F172A"))
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(hex: "64748B"))
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    private func fieldCard(
        title: String,
        icon: String,
        placeholder: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType = .default,
        prefix: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel(title)
            inputCard(
                icon: icon,
                placeholder: placeholder,
                text: text,
                keyboardType: keyboardType,
                prefix: prefix
            )
        }
    }

    private func inputCard(
        icon: String,
        placeholder: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType,
        prefix: String? = nil
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color(hex: "2563EB"))
                .frame(width: 20)

            if let prefix {
                Text(prefix)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color(hex: "64748B"))
            }

            TextField(placeholder, text: text)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color(hex: "0F172A"))
                .keyboardType(keyboardType)
                .textInputAutocapitalization(keyboardType == .emailAddress ? .never : .words)
                .autocorrectionDisabled(true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(Color(hex: "F8FAFC"))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(hex: "DCE6F2"), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .black))
            .foregroundStyle(Color(hex: "64748B"))
            .textCase(.uppercase)
    }

    private func heroMetric(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.68))
            Text(value.isEmpty ? "-" : value)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func statusMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(Color(hex: "6EE7B7"))
            Text(value)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color(hex: "065F46"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private extension Color {
    init(hex: String) {
        let cleaned = hex.replacingOccurrences(of: "#", with: "")
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        self.init(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255.0,
            green: Double((value >> 8) & 0xFF) / 255.0,
            blue: Double(value & 0xFF) / 255.0,
            opacity: 1
        )
    }
}
