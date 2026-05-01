import SwiftUI
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct MyRequestsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedFilter: RequestFilter = .all
    @State private var requests: [AdminRequestRecord] = []
    @State private var selectedRequest: AdminRequestRecord?
    @State private var isLoading = false
    @State private var errorMessage: String?
    #if canImport(FirebaseFirestore)
    @State private var realtimeListener: ListenerRegistration?
    #endif

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "F4F6FA").ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        headerCard
                        filterBar
                        summaryGrid
                        contentSection
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 18)
                }
            }
            .navigationTitle("Mis solicitudes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cerrar") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await loadRequests() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .sheet(item: $selectedRequest) { request in
                RequestDetailView(request: request)
            }
            .task {
                await loadRequests()
            }
            .onAppear {
                startRealtimeSync()
            }
            .onDisappear {
                stopRealtimeSync()
            }
        }
    }

    private var filteredRequests: [AdminRequestRecord] {
        requests.filter { selectedFilter.matches($0) }
    }

    private var pendingCount: Int { requests.filter { $0.normalizedStatus == "pending" }.count }
    private var approvedCount: Int { requests.filter { isApproved($0) }.count }
    private var rejectedCount: Int { requests.filter { isRejected($0) }.count }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Seguimiento operativo")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text("Revisa solicitudes pendientes, aprobadas y denegadas con comentarios del panel administrativo.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.82))
            HStack(spacing: 10) {
                statusBadge(title: "Pendientes", value: "\(pendingCount)", color: Color(hex: "F59E0B"))
                statusBadge(title: "Aceptadas", value: "\(approvedCount)", color: Color(hex: "22C55E"))
                statusBadge(title: "Denegadas", value: "\(rejectedCount)", color: Color(hex: "EF4444"))
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "4F7CF7"), Color(hex: "3B82F6")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(RequestFilter.allCases) { filter in
                    Button {
                        selectedFilter = filter
                    } label: {
                        Text(filter.title)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(selectedFilter == filter ? .white : Color(hex: "6B7280"))
                            .padding(.horizontal, 14)
                            .frame(height: 36)
                            .background(
                                Capsule()
                                    .fill(selectedFilter == filter ? Color(hex: "3B82F6") : Color.white)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var summaryGrid: some View {
        HStack(spacing: 12) {
            summaryTile(title: "Total", value: "\(requests.count)", tint: Color(hex: "3B82F6"))
            summaryTile(title: "Panel", value: AdminRequestService.requestEndpointDescription().contains("http") ? "API OK" : "Sin API", tint: Color(hex: "22C55E"))
        }
    }

    @ViewBuilder
    private var contentSection: some View {
        if isLoading {
            ProgressView("Cargando solicitudes...")
                .frame(maxWidth: .infinity, minHeight: 240)
        } else if let errorMessage {
            errorCard(message: errorMessage)
        } else if filteredRequests.isEmpty {
            emptyCard
        } else {
            VStack(spacing: 14) {
                ForEach(filteredRequests) { request in
                    requestCard(request)
                }
            }
        }
    }

    private var emptyCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color(hex: "9CA3AF"))
            Text("No hay solicitudes registradas")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: "172033"))
            Text("Cuando envíes una solicitud desde clientes, almacén o ventas aparecerá aquí.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color(hex: "6B7280"))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
        .padding(24)
        .background(cardBackground)
    }

    private func requestCard(_ request: AdminRequestRecord) -> some View {
        Button {
            selectedRequest = request
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(humanTitle(for: request.type))
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .foregroundStyle(Color(hex: "172033"))
                        Text(request.module.capitalized)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: "6B7280"))
                    }
                    Spacer()
                    statusPill(for: request)
                }

                Group {
                    infoRow(label: "Motivo", value: request.reason)
                    infoRow(label: "Entidad", value: [request.targetEntity, request.targetEntityId].compactMap { $0 }.joined(separator: " · ").nonEmptyOr("Sin destino"))
                    infoRow(label: "Fecha", value: formattedDate(request.createdAt))
                    infoRow(label: "Comentario", value: requestComment(request))
                }
            }
            .padding(18)
            .background(cardBackground)
        }
        .buttonStyle(.plain)
    }

    private func errorCard(message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("No se pudieron cargar las solicitudes")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: "7F1D1D"))
            Text(message)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color(hex: "991B1B"))
            Button("Reintentar") {
                Task { await loadRequests() }
            }
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(Color(hex: "EF4444"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(hex: "FEF2F2"))
        )
    }

    private func summaryTile(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: "8E9AAD"))
            Text(value)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(Color(hex: "172033"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(cardBackground)
        .overlay(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(tint.opacity(0.16), lineWidth: 1)
        }
    }

    private func statusBadge(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.72))
            Text(value)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(color.opacity(0.2), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func statusPill(for request: AdminRequestRecord) -> some View {
        let descriptor = statusDescriptor(for: request)
        return Text(descriptor.title)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(descriptor.text)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(descriptor.background)
            .clipShape(Capsule())
    }

    private func infoRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: "9CA3AF"))
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(hex: "172033"))
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func loadRequests() async {
        isLoading = true
        errorMessage = nil
        do {
            let loaded = try await AdminRequestService.fetchMyRequests()
            await MainActor.run {
                requests = loaded.sorted { $0.createdAt > $1.createdAt }
                isLoading = false
            }
        } catch {
            await MainActor.run {
                requests = AdminRequestService.cachedRequests()
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func startRealtimeSync() {
        #if canImport(FirebaseFirestore)
        guard realtimeListener == nil else { return }
        do {
            realtimeListener = try AdminRequestService.subscribeMyRequests(
                onUpdate: { records in
                    Task { @MainActor in
                        requests = records.sorted { $0.createdAt > $1.createdAt }
                        errorMessage = nil
                        isLoading = false
                    }
                },
                onError: { message in
                    Task { @MainActor in
                        errorMessage = message
                        isLoading = false
                    }
                }
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        #endif
    }

    private func stopRealtimeSync() {
        #if canImport(FirebaseFirestore)
        realtimeListener?.remove()
        realtimeListener = nil
        #endif
    }

    private func humanTitle(for type: String) -> String {
        switch type {
        case "create_customer": return "Alta de cliente"
        case "edit_sale": return "Edición de venta"
        case "cancel_sale": return "Anulación de venta"
        case "create_product": return "Alta de producto"
        case "update_product": return "Actualización de producto"
        case "create_warehouse": return "Alta de almacén"
        case "update_warehouse": return "Actualización de almacén"
        case "create_supplier": return "Alta de proveedor"
        case "create_purchase_order": return "Orden de compra"
        case "update_purchase_order_status": return "Cambio de estado de orden"
        default: return type.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private func formattedDate(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: iso) else { return iso.nonEmptyOr("Sin fecha") }
        let output = DateFormatter()
        output.locale = Locale(identifier: "es_PE")
        output.dateStyle = .medium
        output.timeStyle = .short
        return output.string(from: date)
    }

    private func requestComment(_ request: AdminRequestRecord) -> String {
        if let rejectionReason = request.rejectionReason?.nonEmpty {
            return rejectionReason
        }
        if let reviewComment = request.reviewComment?.nonEmpty {
            return reviewComment
        }
        if let message = request.message?.nonEmpty {
            return message
        }
        if let reviewedBy = request.reviewedBy?.nonEmpty {
            return "Revisado por \(reviewedBy)"
        }
        return request.normalizedStatus == "pending" ? "En revisión" : "Sin comentarios"
    }

    private func statusDescriptor(for request: AdminRequestRecord) -> (title: String, text: Color, background: Color) {
        if isApproved(request) {
            return ("Aceptada", Color(hex: "166534"), Color(hex: "ECFDF5"))
        }
        if isRejected(request) {
            return ("Denegada", Color(hex: "991B1B"), Color(hex: "FEF2F2"))
        }
        return ("Pendiente", Color(hex: "92400E"), Color(hex: "FFF7E6"))
    }

    private func isApproved(_ request: AdminRequestRecord) -> Bool {
        ["approved", "accepted", "aprobada", "aceptada"].contains(request.normalizedStatus)
    }

    private func isRejected(_ request: AdminRequestRecord) -> Bool {
        ["rejected", "denied", "rechazada", "denegada"].contains(request.normalizedStatus)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color.white)
            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 3)
    }
}

private struct RequestDetailView: View {
    let request: AdminRequestRecord
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    section("Solicitud") {
                        detailRow("Tipo", request.type)
                        detailRow("Módulo", request.module)
                        detailRow("Estado", request.status)
                        detailRow("Motivo", request.reason)
                    }
                    section("Seguimiento") {
                        detailRow("Creada", request.createdAt.nonEmptyOr("Sin fecha"))
                        detailRow("Revisada", request.reviewedAt.nonEmptyOr("Sin fecha"))
                        detailRow("Revisó", request.reviewedBy.nonEmptyOr("Sin datos"))
                        detailRow("Comentario", request.rejectionReason?.nonEmpty ?? request.message?.nonEmpty ?? "Sin comentarios")
                    }
                    section("Destino") {
                        detailRow("Entidad", request.targetEntity.nonEmptyOr("Sin datos"))
                        detailRow("ID", request.targetEntityId.nonEmptyOr("Sin datos"))
                    }
                }
                .padding(18)
            }
            .background(Color(hex: "F4F6FA").ignoresSafeArea())
            .navigationTitle("Detalle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(Color(hex: "172033"))
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white)
        )
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: "9CA3AF"))
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(hex: "172033"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private enum RequestFilter: String, CaseIterable, Identifiable {
    case all
    case pending
    case approved
    case rejected

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "Todas"
        case .pending: return "Pendientes"
        case .approved: return "Aceptadas"
        case .rejected: return "Denegadas"
        }
    }

    func matches(_ request: AdminRequestRecord) -> Bool {
        switch self {
        case .all:
            return true
        case .pending:
            return request.normalizedStatus == "pending"
        case .approved:
            return ["approved", "accepted", "aprobada", "aceptada"].contains(request.normalizedStatus)
        case .rejected:
            return ["rejected", "denied", "rechazada", "denegada"].contains(request.normalizedStatus)
        }
    }
}

private extension Optional where Wrapped == String {
    var nonEmpty: String? {
        guard let value = self?.trimmingCharacters(in: .whitespacesAndNewlines), value.isEmpty == false else { return nil }
        return value
    }

    func nonEmptyOr(_ fallback: String) -> String {
        nonEmpty ?? fallback
    }
}

private extension String {
    var nonEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    func nonEmptyOr(_ fallback: String) -> String {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback : self
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
