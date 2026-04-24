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

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    fieldCard(
                        title: "NOMBRE / RAZÓN SOCIAL",
                        icon: "person.fill",
                        placeholder: "Nombre completo o empresa",
                        text: $form.nombre
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        sectionLabel("DOCUMENTO")
                        HStack(spacing: 12) {
                            Picker("Documento", selection: $form.tipoDocumento) {
                                ForEach(ClienteModalFormData.TipoDocumento.allCases) { tipo in
                                    Text(tipo.rawValue).tag(tipo)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 118)
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

                    fieldCard(
                        title: "TELÉFONO",
                        icon: "phone.fill",
                        placeholder: "9XX-XXX-XXX",
                        text: Binding(
                            get: { form.telefono },
                            set: { form.telefono = String($0.filter(\.isNumber).prefix(9)) }
                        ),
                        keyboardType: .phonePad
                    )

                    fieldCard(
                        title: "CORREO ELECTRÓNICO",
                        icon: "envelope.fill",
                        placeholder: "correo@ejemplo.com",
                        text: $form.correo,
                        keyboardType: .emailAddress
                    )

                    fieldCard(
                        title: "DIRECCIÓN",
                        icon: "location.fill",
                        placeholder: "Calle, número, distrito",
                        text: $form.direccion
                    )

                    fieldCard(
                        title: "LÍMITE DE CRÉDITO (S/)",
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

                    Button(action: { onSave(form) }) {
                        Text("Guardar Cliente")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(uiColor: .appBlue))
                    .disabled(!form.canSave)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: Color(uiColor: .appBlue).opacity(0.3), radius: 10, x: 0, y: 4)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 32)
            }
            .background(Color(uiColor: .appBackground))
        }
        .background(Color(uiColor: .appBackground).ignoresSafeArea())
    }

    private var header: some View {
        ZStack {
            Text("Agregar Cliente")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(uiColor: .label))

            HStack {
                Button("Cancelar", action: onCancel)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundStyle(Color(uiColor: .appBlue))
                Spacer()
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 56)
        .background(Color(uiColor: .systemBackground))
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Estado inicial")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(uiColor: .label))
                Spacer()
                Text("Activo")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color(uiColor: .appGreen)))
            }

            Text("El estado se actualizará automáticamente según el historial de pagos del cliente")
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(Color(uiColor: .secondaryLabel))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(uiColor: UIColor(hex: "#F0FDF4")))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(uiColor: UIColor(hex: "#BBF7D0")), lineWidth: 1)
        )
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
                .foregroundStyle(Color(uiColor: .appBlue))
                .frame(width: 20)

            if let prefix {
                Text(prefix)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
            }

            TextField(placeholder, text: text)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundStyle(Color(uiColor: .label))
                .keyboardType(keyboardType)
                .textInputAutocapitalization(keyboardType == .emailAddress ? .never : .words)
                .autocorrectionDisabled(true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(uiColor: .separator), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(Color(uiColor: .secondaryLabel))
            .textCase(.uppercase)
    }
}

private extension UIColor {
    static let appBlue = UIColor(hex: "#3B82F6")
    static let appGreen = UIColor(hex: "#22C55E")
    static let appBackground = UIColor(hex: "#F4F6FA")

    convenience init(hex: String) {
        let hexValue = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        var int: UInt64 = 0
        Scanner(string: hexValue).scanHexInt64(&int)
        self.init(
            red: CGFloat((int & 0xFF0000) >> 16) / 255,
            green: CGFloat((int & 0x00FF00) >> 8) / 255,
            blue: CGFloat(int & 0x0000FF) / 255,
            alpha: 1
        )
    }
}
