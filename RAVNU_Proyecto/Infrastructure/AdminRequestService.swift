import Foundation
import SwiftUI
import UIKit
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct AdminRequestPayload: Encodable {
    let requestId: String
    let type: String
    let module: String
    let status: String
    let requestedBy: RequestedBy
    let target: RequestTarget?
    let payload: [String: JSONValue]
    let reason: String
    let createdAt: String
    let reviewedAt: String?
    let reviewedBy: String?
    let rejectionReason: String?

    struct RequestedBy: Encodable {
        let userId: String
        let authUid: String
        let fullName: String
        let roleId: String
        let email: String
    }

    struct RequestTarget: Encodable {
        let entity: String
        let entityId: String
    }
}

struct AdminRequestSubmissionResult: Decodable {
    let success: Bool?
    let requestId: String?
    let status: String?
    let message: String?
}

struct AdminRequestRecord: Codable, Identifiable {
    let id: String
    let type: String
    let module: String
    let status: String
    let reason: String
    let createdAt: String
    let requestedByUserId: String
    let requestedByName: String?
    let requestedByRoleId: String?
    let targetEntity: String?
    let targetEntityId: String?
    let reviewedAt: String?
    let reviewedBy: String?
    let rejectionReason: String?
    let reviewComment: String?
    let message: String?

    init(payload: AdminRequestPayload, result: AdminRequestSubmissionResult?) {
        id = result?.requestId ?? payload.requestId
        type = payload.type
        module = payload.module
        status = result?.status ?? payload.status
        reason = payload.reason
        createdAt = payload.createdAt
        requestedByUserId = payload.requestedBy.userId
        requestedByName = payload.requestedBy.fullName
        requestedByRoleId = payload.requestedBy.roleId
        targetEntity = payload.target?.entity
        targetEntityId = payload.target?.entityId
        reviewedAt = payload.reviewedAt
        reviewedBy = payload.reviewedBy
        rejectionReason = payload.rejectionReason
        reviewComment = nil
        message = result?.message
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? container.decodeIfPresent(String.self, forKey: .requestId)
            ?? UUID().uuidString
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? "unknown"
        module = try container.decodeIfPresent(String.self, forKey: .module) ?? "general"
        status = try container.decodeFlexibleString(forKey: .status) ?? "pending"
        reason = try container.decodeIfPresent(String.self, forKey: .reason) ?? "Sin motivo"
        createdAt = try container.decodeFlexibleString(forKey: .createdAt) ?? ""
        let requestedBy = try container.decodeIfPresent(RequestedByRecord.self, forKey: .requestedBy)
        let fallbackRequestedByUserId = try container.decodeIfPresent(String.self, forKey: .requestedByUserId)
        requestedByUserId = requestedBy?.userId ?? fallbackRequestedByUserId ?? ""
        requestedByName = requestedBy?.fullName
        requestedByRoleId = requestedBy?.roleId
        let target = try container.decodeIfPresent(TargetRecord.self, forKey: .target)
        let fallbackTargetEntity = try container.decodeIfPresent(String.self, forKey: .targetEntity)
        let fallbackTargetEntityId = try container.decodeIfPresent(String.self, forKey: .targetEntityId)
        targetEntity = target?.entity ?? fallbackTargetEntity
        targetEntityId = target?.entityId ?? fallbackTargetEntityId
        reviewedAt = try container.decodeFlexibleString(forKey: .reviewedAt)
        let reviewedByRecord = try container.decodeIfPresent(ReviewedByRecord.self, forKey: .reviewedBy)
        let fallbackReviewedBy = try container.decodeFlexibleString(forKey: .reviewedBy)
        reviewedBy = reviewedByRecord?.displayName ?? fallbackReviewedBy
        rejectionReason = try container.decodeFlexibleString(forKey: .rejectionReason)
        reviewComment = try container.decodeFlexibleString(forKey: .reviewComment)
        message = try container.decodeFlexibleString(forKey: .message)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(module, forKey: .module)
        try container.encode(status, forKey: .status)
        try container.encode(reason, forKey: .reason)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(requestedByUserId, forKey: .requestedByUserId)
        try container.encodeIfPresent(requestedByName, forKey: .requestedByName)
        try container.encodeIfPresent(requestedByRoleId, forKey: .requestedByRoleId)
        try container.encodeIfPresent(targetEntity, forKey: .targetEntity)
        try container.encodeIfPresent(targetEntityId, forKey: .targetEntityId)
        try container.encodeIfPresent(reviewedAt, forKey: .reviewedAt)
        try container.encodeIfPresent(reviewedBy, forKey: .reviewedBy)
        try container.encodeIfPresent(rejectionReason, forKey: .rejectionReason)
        try container.encodeIfPresent(reviewComment, forKey: .reviewComment)
        try container.encodeIfPresent(message, forKey: .message)
    }

    var normalizedStatus: String {
        status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case requestId
        case type
        case module
        case status
        case reason
        case createdAt
        case requestedByUserId
        case requestedByName
        case requestedByRoleId
        case requestedBy
        case targetEntity
        case targetEntityId
        case target
        case reviewedAt
        case reviewedBy
        case rejectionReason
        case reviewComment
        case message
    }

    private struct RequestedByRecord: Codable {
        let userId: String
        let fullName: String?
        let roleId: String?
    }

    private struct TargetRecord: Codable {
        let entity: String?
        let entityId: String?
    }

    private struct ReviewedByRecord: Codable {
        let userId: String?
        let fullName: String?
        let email: String?
        let roleId: String?

        var displayName: String? {
            fullName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? fullName : email
        }
    }
}

enum JSONValue: Encodable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case null

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

enum AdminRequestServiceError: LocalizedError {
    case missingBaseURL
    case invalidBaseURL
    case invalidRequester
    case unauthorized
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingBaseURL:
            return "Falta configurar la URL base del panel administrativo en Info.plist."
        case .invalidBaseURL:
            return "La URL del panel administrativo no es válida."
        case .invalidRequester:
            return "No se pudo identificar al usuario que envía la solicitud."
        case .unauthorized:
            return "No se pudo autenticar la solicitud contra el panel administrativo."
        case .requestFailed(let message):
            return message
        }
    }
}

private struct AdminRequestServiceConfig {
    let baseURL: URL
    let requestsPath: String
    let authMode: AuthMode

    enum AuthMode: String {
        case none
        case bearerToken = "bearer_token"
        case firebaseIDToken = "firebase_id_token"
    }
}

private enum AdminRequestStore {
    private static let key = "adminRequestRecords"
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    static func save(_ record: AdminRequestRecord) {
        var records = all()
        records.removeAll { $0.id == record.id }
        records.insert(record, at: 0)
        let trimmed = Array(records.prefix(100))
        guard let data = try? encoder.encode(trimmed) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func replaceAll(_ records: [AdminRequestRecord]) {
        guard let data = try? encoder.encode(records) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func all() -> [AdminRequestRecord] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let records = try? decoder.decode([AdminRequestRecord].self, from: data) else {
            return []
        }
        return records
    }
}

enum AdminRequestService {
    private static let baseURLInfoKey = "AdminRequestsAPIBaseURL"
    private static let requestsPathInfoKey = "AdminRequestsAPIRequestsPath"
    private static let authModeInfoKey = "AdminRequestsAuthMode"

    static func currentRequester() throws -> AdminRequestPayload.RequestedBy {
        guard let userId = AppSession.shared.userDocumentId, userId.isEmpty == false,
              let authUid = AppSession.shared.authUid, authUid.isEmpty == false,
              let fullName = AppSession.shared.usuarioLogueado, fullName.isEmpty == false,
              let roleId = AppSession.shared.rolLogueado, roleId.isEmpty == false else {
            throw AdminRequestServiceError.invalidRequester
        }

        return AdminRequestPayload.RequestedBy(
            userId: userId,
            authUid: authUid,
            fullName: fullName,
            roleId: roleId.lowercased(),
            email: AppSession.shared.userEmail ?? ""
        )
    }

    @discardableResult
    static func submit(_ payload: AdminRequestPayload) async throws -> AdminRequestSubmissionResult {
        let config = try loadConfig()
        var request = URLRequest(url: config.baseURL.appendingPathComponent(config.requestsPath))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let authorization = try await authorizationHeaderValue(for: config.authMode) {
            request.setValue(authorization, forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(payload)
        logRequest(request, body: request.httpBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = try validate(response: response, data: data, request: request)
        let result = decodeSubmissionResult(from: data, statusCode: httpResponse.statusCode, requestId: payload.requestId)
        AdminRequestStore.save(AdminRequestRecord(payload: payload, result: result))
        return result
    }

    static func fetchMyRequests(status: String? = nil) async throws -> [AdminRequestRecord] {
        let config = try loadConfig()
        guard let requester = AppSession.shared.userDocumentId, requester.isEmpty == false else {
            throw AdminRequestServiceError.invalidRequester
        }

        var components = URLComponents(url: config.baseURL.appendingPathComponent(config.requestsPath), resolvingAgainstBaseURL: false)
        var queryItems = [URLQueryItem(name: "requesterId", value: requester)]
        if let status, status.isEmpty == false {
            queryItems.append(URLQueryItem(name: "status", value: status))
        }
        components?.queryItems = queryItems
        guard let url = components?.url else {
            throw AdminRequestServiceError.invalidBaseURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let authorization = try await authorizationHeaderValue(for: config.authMode) {
            request.setValue(authorization, forHTTPHeaderField: "Authorization")
        }
        logRequest(request, body: nil)

        let (data, response) = try await URLSession.shared.data(for: request)
        _ = try validate(response: response, data: data, request: request)

        let decoder = JSONDecoder()
        if let records = try? decoder.decode([AdminRequestRecord].self, from: data) {
            let merged = mergeWithCache(records, requesterId: requester)
            AdminRequestStore.replaceAll(merged)
            return filter(merged, requesterId: requester, status: status)
        }
        if let envelope = try? decoder.decode(AdminRequestListEnvelope.self, from: data) {
            let merged = mergeWithCache(envelope.records, requesterId: requester)
            AdminRequestStore.replaceAll(merged)
            return filter(merged, requesterId: requester, status: status)
        }
        let fallback = mergeWithCache([], requesterId: requester)
        return filter(fallback, requesterId: requester, status: status)
    }

    static func cachedRequests() -> [AdminRequestRecord] {
        AdminRequestStore.all()
    }

    #if canImport(FirebaseFirestore)
    @discardableResult
    static func subscribeMyRequests(
        onUpdate: @escaping ([AdminRequestRecord]) -> Void,
        onError: @escaping (String) -> Void
    ) throws -> ListenerRegistration {
        guard let requester = AppSession.shared.userDocumentId, requester.isEmpty == false else {
            throw AdminRequestServiceError.invalidRequester
        }

        let query = Firestore.firestore()
            .collection("admin_requests")
            .whereField("requestedBy.userId", isEqualTo: requester)

        return query.addSnapshotListener { snapshot, error in
            if let error {
                onError(error.localizedDescription)
                return
            }
            guard let snapshot else {
                onError("No se recibieron solicitudes desde Firestore.")
                return
            }

            let remoteRecords = snapshot.documents.compactMap { document in
                record(from: document.data(), documentId: document.documentID)
            }
            let merged = mergeWithCache(remoteRecords, requesterId: requester)
            AdminRequestStore.replaceAll(merged)
            onUpdate(merged)
        }
    }
    #endif

    static func requestEndpointDescription() -> String {
        guard let config = try? loadConfig() else {
            return "No configurado"
        }
        return config.baseURL.appendingPathComponent(config.requestsPath).absoluteString
    }

    private static func loadConfig() throws -> AdminRequestServiceConfig {
        guard let baseURLString = Bundle.main.object(forInfoDictionaryKey: baseURLInfoKey) as? String,
              baseURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            throw AdminRequestServiceError.missingBaseURL
        }
        guard let baseURL = URL(string: baseURLString) else {
            throw AdminRequestServiceError.invalidBaseURL
        }

        let requestsPath = (Bundle.main.object(forInfoDictionaryKey: requestsPathInfoKey) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let authModeRaw = (Bundle.main.object(forInfoDictionaryKey: authModeInfoKey) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? AdminRequestServiceConfig.AuthMode.firebaseIDToken.rawValue

        return AdminRequestServiceConfig(
            baseURL: baseURL,
            requestsPath: (requestsPath?.isEmpty == false ? requestsPath! : "admin/requests"),
            authMode: AdminRequestServiceConfig.AuthMode(rawValue: authModeRaw) ?? .firebaseIDToken
        )
    }

    private static func authorizationHeaderValue(for mode: AdminRequestServiceConfig.AuthMode) async throws -> String? {
        switch mode {
        case .none:
            return nil
        case .bearerToken:
            guard let token = AppSession.shared.adminAPIAuthToken?.trimmingCharacters(in: .whitespacesAndNewlines),
                  token.isEmpty == false else {
                throw AdminRequestServiceError.unauthorized
            }
            return "Bearer \(token)"
        case .firebaseIDToken:
            #if canImport(FirebaseAuth)
            guard let user = Auth.auth().currentUser else {
                throw AdminRequestServiceError.unauthorized
            }
            let token: String = try await withCheckedThrowingContinuation { continuation in
                user.getIDToken { token, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let token, token.isEmpty == false {
                        continuation.resume(returning: token)
                    } else {
                        continuation.resume(throwing: AdminRequestServiceError.unauthorized)
                    }
                }
            }
            return "Bearer \(token)"
            #else
            throw AdminRequestServiceError.unauthorized
            #endif
        }
    }

    @discardableResult
    private static func validate(response: URLResponse, data: Data, request: URLRequest) throws -> HTTPURLResponse {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AdminRequestServiceError.requestFailed("No se recibió una respuesta válida del panel administrativo.")
        }

        logResponse(httpResponse, data: data, request: request)

        guard (200...299).contains(httpResponse.statusCode) else {
            let serverMessage = (try? JSONDecoder().decode(AdminRequestSubmissionResult.self, from: data).message)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let serverMessage, serverMessage.isEmpty == false {
                throw AdminRequestServiceError.requestFailed(serverMessage)
            }
            throw AdminRequestServiceError.requestFailed(buildFailureMessage(statusCode: httpResponse.statusCode, request: request, data: data))
        }

        return httpResponse
    }

    private static func buildFailureMessage(statusCode: Int, request: URLRequest, data: Data) -> String {
        let method = request.httpMethod ?? "REQUEST"
        let url = request.url?.absoluteString ?? "URL desconocida"
        let rawBody = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let responseSnippet = rawBody?.isEmpty == false ? "\nRespuesta: \(rawBody!)" : ""

        if statusCode == 404 {
            return """
            El panel administrativo rechazó la solicitud (404).
            Método: \(method)
            URL: \(url)
            Verifica que el backend exponga exactamente esa ruta en ngrok, por ejemplo `POST /admin/requests`.
            \(responseSnippet)
            """
        }

        return """
        El panel administrativo rechazó la solicitud (\(statusCode)).
        Método: \(method)
        URL: \(url)\(responseSnippet)
        """
    }

    private static func logRequest(_ request: URLRequest, body: Data?) {
        let method = request.httpMethod ?? "REQUEST"
        let url = request.url?.absoluteString ?? "URL desconocida"
        let headers = request.allHTTPHeaderFields ?? [:]
        let safeHeaders = headers.mapValues { keyValue in
            if keyValue.lowercased().contains("bearer ") {
                return "Bearer ***"
            }
            return keyValue
        }
        let bodyString = body.flatMap { String(data: $0, encoding: .utf8) } ?? "sin body"
        print("""
        [AdminRequestService] -> \(method) \(url)
        [AdminRequestService] Headers: \(safeHeaders)
        [AdminRequestService] Body: \(bodyString)
        """)
    }

    private static func logResponse(_ response: HTTPURLResponse, data: Data, request: URLRequest) {
        let method = request.httpMethod ?? "REQUEST"
        let url = request.url?.absoluteString ?? "URL desconocida"
        let bodyString = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "sin body"
        print("""
        [AdminRequestService] <- \(response.statusCode) \(method) \(url)
        [AdminRequestService] Response: \(bodyString)
        """)
    }

    private static func decodeSubmissionResult(from data: Data, statusCode: Int, requestId: String) -> AdminRequestSubmissionResult {
        if let decoded = try? JSONDecoder().decode(AdminRequestSubmissionResult.self, from: data) {
            return decoded
        }
        return AdminRequestSubmissionResult(
            success: (200...299).contains(statusCode),
            requestId: requestId,
            status: "pending",
            message: nil
        )
    }

    private static func mergeWithCache(_ remoteRecords: [AdminRequestRecord], requesterId: String) -> [AdminRequestRecord] {
        var mergedById = Dictionary(uniqueKeysWithValues: AdminRequestStore.all().map { ($0.id, $0) })
        for record in remoteRecords where record.requestedByUserId == requesterId || record.requestedByUserId.isEmpty {
            mergedById[record.id] = record
        }
        return mergedById.values.sorted { $0.createdAt > $1.createdAt }
    }

    private static func filter(_ records: [AdminRequestRecord], requesterId: String, status: String?) -> [AdminRequestRecord] {
        records.filter { record in
            let matchesRequester = record.requestedByUserId.isEmpty || record.requestedByUserId == requesterId
            let matchesStatus = status == nil || record.normalizedStatus == status?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return matchesRequester && matchesStatus
        }
    }

    #if canImport(FirebaseFirestore)
    private static func record(from data: [String: Any], documentId: String) -> AdminRequestRecord? {
        var normalized = normalizeFirestoreValue(data) as? [String: Any] ?? [:]
        if normalized["requestId"] == nil {
            normalized["requestId"] = documentId
        }
        if normalized["id"] == nil {
            normalized["id"] = documentId
        }
        guard JSONSerialization.isValidJSONObject(normalized),
              let jsonData = try? JSONSerialization.data(withJSONObject: normalized),
              let record = try? JSONDecoder().decode(AdminRequestRecord.self, from: jsonData) else {
            return nil
        }
        return record
    }

    private static func normalizeFirestoreValue(_ value: Any) -> Any {
        if let timestamp = value as? Timestamp {
            return ISO8601DateFormatter().string(from: timestamp.dateValue())
        }
        if value is NSNull {
            return NSNull()
        }
        if let dictionary = value as? [String: Any] {
            return dictionary.mapValues { normalizeFirestoreValue($0) }
        }
        if let array = value as? [Any] {
            return array.map { normalizeFirestoreValue($0) }
        }
        return value
    }
    #endif
}

private struct AdminRequestListEnvelope: Decodable {
    let records: [AdminRequestRecord]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let records = try? container.decode([AdminRequestRecord].self) {
            self.records = records
            return
        }

        let keyed = try decoder.container(keyedBy: CodingKeys.self)
        if let records = try keyed.decodeIfPresent([AdminRequestRecord].self, forKey: .requests) {
            self.records = records
        } else if let records = try keyed.decodeIfPresent([AdminRequestRecord].self, forKey: .items) {
            self.records = records
        } else if let records = try keyed.decodeIfPresent([AdminRequestRecord].self, forKey: .data) {
            self.records = records
        } else {
            self.records = []
        }
    }

    private enum CodingKeys: String, CodingKey {
        case requests
        case items
        case data
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleString(forKey key: Key) throws -> String? {
        if let value = try decodeIfPresent(String.self, forKey: key) {
            return value
        }
        if let number = try decodeIfPresent(Double.self, forKey: key) {
            return String(number)
        }
        if let bool = try decodeIfPresent(Bool.self, forKey: key) {
            return bool ? "true" : "false"
        }
        if let timestamp = try decodeIfPresent(FirestoreTimestampLike.self, forKey: key) {
            return timestamp.isoString
        }
        return nil
    }
}

private struct FirestoreTimestampLike: Decodable {
    let seconds: Double?
    let nanoseconds: Double?
    let dateString: String?

    init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer(), let string = try? single.decode(String.self) {
            seconds = nil
            nanoseconds = nil
            dateString = string
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        seconds = try container.decodeIfPresent(Double.self, forKey: .seconds)
            ?? container.decodeIfPresent(Double.self, forKey: ._seconds)
        nanoseconds = try container.decodeIfPresent(Double.self, forKey: .nanoseconds)
            ?? container.decodeIfPresent(Double.self, forKey: ._nanoseconds)
        dateString = try container.decodeIfPresent(String.self, forKey: .isoString)
            ?? container.decodeIfPresent(String.self, forKey: .timestamp)
    }

    var isoString: String? {
        if let dateString, dateString.isEmpty == false {
            return dateString
        }
        guard let seconds else { return nil }
        let date = Date(timeIntervalSince1970: seconds + (nanoseconds ?? 0) / 1_000_000_000)
        return ISO8601DateFormatter().string(from: date)
    }

    private enum CodingKeys: String, CodingKey {
        case seconds
        case nanoseconds
        case _seconds
        case _nanoseconds
        case isoString
        case timestamp
    }
}

struct AdminRequestComposerField {
    let title: String
    let placeholder: String
    let helper: String
    let isRequired: Bool
}

struct AdminRequestComposerItem: Identifiable {
    let id = UUID()
    let title: String
    let value: String
}

struct AdminRequestComposerConfig {
    let title: String
    let subtitle: String
    let moduleLabel: String
    let typeLabel: String
    let targetLabel: String
    let accent: AdminRequestComposerAccent
    let primaryField: AdminRequestComposerField
    let secondaryField: AdminRequestComposerField?
    let tertiaryField: AdminRequestComposerField?
    let summaryItems: [AdminRequestComposerItem]
    let endpointLabel: String
}

struct AdminRequestComposerResult {
    let primaryText: String
    let secondaryText: String
    let tertiaryText: String
}

enum AdminRequestComposerAccent {
    case blue
    case green
    case orange

    var tint: Color {
        switch self {
        case .blue:
            return Color(hex: "3B82F6")
        case .green:
            return Color(hex: "22C55E")
        case .orange:
            return Color(hex: "F59E0B")
        }
    }

    var softBackground: Color {
        switch self {
        case .blue:
            return Color(hex: "EFF6FF")
        case .green:
            return Color(hex: "ECFDF5")
        case .orange:
            return Color(hex: "FFF7ED")
        }
    }
}

private struct AdminRequestComposerView: View {
    let config: AdminRequestComposerConfig
    let onCancel: () -> Void
    let onSubmit: (AdminRequestComposerResult) -> Void

    @State private var primaryText = ""
    @State private var secondaryText = ""
    @State private var tertiaryText = ""
    @State private var validationMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    heroCard
                    formCard
                    summaryCard
                    endpointCard
                    if let validationMessage {
                        validationBanner(message: validationMessage)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 20)
            }
            .background(Color(hex: "F4F6FA").ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar", action: onCancel)
                        .foregroundStyle(Color(hex: "6B7280"))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Enviar") {
                        submit()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(config.accent.tint)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(config.accent.tint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(config.title)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color(hex: "111827"))
                    Text(config.subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(hex: "6B7280"))
                }
            }

            HStack(spacing: 10) {
                chip(title: "Módulo", value: config.moduleLabel)
                chip(title: "Tipo", value: config.typeLabel)
            }

            chip(title: "Destino", value: config.targetLabel)
        }
        .padding(18)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color(hex: "DCE6F2"), lineWidth: 1)
        )
    }

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Qué debe completar")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color(hex: "111827"))

            fieldView(
                title: config.primaryField.title,
                placeholder: config.primaryField.placeholder,
                helper: config.primaryField.helper,
                text: $primaryText
            )

            if let secondaryField = config.secondaryField {
                fieldView(
                    title: secondaryField.title,
                    placeholder: secondaryField.placeholder,
                    helper: secondaryField.helper,
                    text: $secondaryText
                )
            }

            if let tertiaryField = config.tertiaryField {
                fieldView(
                    title: tertiaryField.title,
                    placeholder: tertiaryField.placeholder,
                    helper: tertiaryField.helper,
                    text: $tertiaryText
                )
            }
        }
        .padding(18)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color(hex: "DCE6F2"), lineWidth: 1)
        )
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Resumen de la solicitud")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color(hex: "111827"))

            ForEach(config.summaryItems) { item in
                HStack(alignment: .top, spacing: 12) {
                    Text(item.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(hex: "6B7280"))
                        .frame(width: 112, alignment: .leading)
                    Text(item.value)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(hex: "111827"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(18)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color(hex: "DCE6F2"), lineWidth: 1)
        )
    }

    private var endpointCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Destino configurado")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color(hex: "111827"))
            Text(config.endpointLabel)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color(hex: "1D4ED8"))
                .textSelection(.enabled)
            Text("La solicitud se verá en la pestaña web de Solicitudes con estos mismos datos.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(hex: "6B7280"))
        }
        .padding(18)
        .background(config.accent.softBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(config.accent.tint.opacity(0.18), lineWidth: 1)
        )
    }

    private func validationBanner(message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color(hex: "F59E0B"))
            Text(message)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(hex: "92400E"))
            Spacer()
        }
        .padding(14)
        .background(Color(hex: "FFF7ED"), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(hex: "FED7AA"), lineWidth: 1)
        )
    }

    private func chip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color(hex: "6B7280"))
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(hex: "111827"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(hex: "F8FAFC"), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func fieldView(title: String, placeholder: String, helper: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(hex: "111827"))
            TextField(placeholder, text: text, axis: .vertical)
                .lineLimit(3, reservesSpace: true)
                .padding(14)
                .background(Color(hex: "F8FAFC"), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color(hex: "DCE6F2"), lineWidth: 1)
                )
            Text(helper)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(hex: "6B7280"))
        }
    }

    private func submit() {
        validationMessage = nil
        let primary = primaryText.trimmingCharacters(in: .whitespacesAndNewlines)
        let secondary = secondaryText.trimmingCharacters(in: .whitespacesAndNewlines)
        let tertiary = tertiaryText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard primary.isEmpty == false else {
            validationMessage = "Completa el motivo principal antes de enviar."
            return
        }
        if let secondaryField = config.secondaryField, secondaryField.isRequired, secondary.isEmpty {
            validationMessage = "Completa \(secondaryField.title.lowercased()) para que la solicitud tenga contexto operativo."
            return
        }
        if let tertiaryField = config.tertiaryField, tertiaryField.isRequired, tertiary.isEmpty {
            validationMessage = "Completa \(tertiaryField.title.lowercased()) antes de enviar."
            return
        }

        onSubmit(
            AdminRequestComposerResult(
                primaryText: primary,
                secondaryText: secondary,
                tertiaryText: tertiary
            )
        )
    }
}

extension UIViewController {
    func presentAdminRequestComposer(
        config: AdminRequestComposerConfig,
        onSubmit: @escaping (AdminRequestComposerResult, UIViewController) -> Void
    ) {
        var host: UIHostingController<AdminRequestComposerView>!
        host = UIHostingController(
            rootView: AdminRequestComposerView(
                config: config,
                onCancel: { [weak self] in
                    self?.dismiss(animated: true)
                },
                onSubmit: { result in
                    onSubmit(result, host)
                }
            )
        )
        host.modalPresentationStyle = .pageSheet
        if let sheet = host.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 28
        }
        present(host, animated: true)
    }
}

private extension Color {
    init(hex: String) {
        let cleaned = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }
}
