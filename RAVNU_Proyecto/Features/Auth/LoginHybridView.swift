import SwiftUI

struct LoginHybridView: View {
    @ObservedObject var estado: EstadoFormularioLogin
    let usaFirebase: Bool
    let onLogin: () -> Void

    var body: some View {
        ZStack {
            Color(hex: "F4F7FB").ignoresSafeArea()

            GeometryReader { geometry in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        header(heroHeight: heroHeight(for: geometry.size.height))

                        VStack(alignment: .leading, spacing: 18) {
                            titleSection
                            credentialsSection
                            loginButton
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 26)
                        .padding(.bottom, 32)
                    }
                    .frame(minHeight: geometry.size.height)
                }
            }
        }
    }

    private func header(heroHeight: CGFloat) -> some View {
        ZStack {
            Color.blue

            VStack(spacing: 8) {
                Spacer(minLength: 0)
                Image("app")
                    .resizable()
                    .scaledToFit()
                    .frame(width: min(heroHeight * 0.42, 132), height: min(heroHeight * 0.45, 140))

                Text("RAVNU")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)

                Text("Sistema de Gestión de Estaciones")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.9))
                Spacer(minLength: 22)
            }
            .padding(.horizontal, 24)
        }
        .frame(height: heroHeight)
        .clipped()
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Iniciar Sesión")
                .font(.system(size: 25, weight: .bold))
                .foregroundStyle(Color(hex: "111827"))

            Text(usaFirebase ? "Ingresa tu correo y contraseña para continuar" : "Firebase no está disponible en este momento")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Color(.systemGray))
        }
    }

    private var credentialsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("CORREO")
            LoginInputField(
                text: $estado.usuario,
                placeholder: "Ingresa tu correo",
                height: 34
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.emailAddress)

            fieldLabel("CONTRASEÑA")
            LoginSecureField(
                text: $estado.contraseña,
                placeholder: "Ingresa tu contraseña",
                height: 34
            )
        }
    }

    private var loginButton: some View {
        Button(action: onLogin) {
            Text("Ingresar")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 35)
                .background(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(Color(hex: "555555"))
    }

    private func heroHeight(for totalHeight: CGFloat) -> CGFloat {
        min(max(totalHeight * 0.36, 280), 320)
    }
}

private struct LoginInputField: View {
    @Binding var text: String
    let placeholder: String
    let height: CGFloat

    var body: some View {
        TextField(placeholder, text: $text)
            .font(.system(size: 14))
            .padding(.horizontal, 12)
            .frame(height: height)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color(hex: "D1D5DB"), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct LoginSecureField: View {
    @Binding var text: String
    let placeholder: String
    let height: CGFloat
    @State private var isSecure = true

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .font(.system(size: 14))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            Button {
                isSecure.toggle()
            } label: {
                Image(systemName: isSecure ? "eye.slash" : "eye")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(hex: "6B7280"))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .frame(height: height)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(hex: "D1D5DB"), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
