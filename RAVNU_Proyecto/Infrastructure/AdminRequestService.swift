import Foundation
#if canImport(FirebaseAuth)
import FirebaseAuth
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
    let targetEntity: String?
    let targetEntityId: String?
    let message: String?

    init(payload: AdminRequestPayload, result: AdminRequestSubmissionResult?) {
        id = result?.requestId ?? payload.requestId
        type = payload.type
        module = payload.module
        status = result?.status ?? payload.status
        reason = payload.reason
        createdAt = payload.createdAt
        requestedByUserId = payload.requestedBy.userId
        targetEntity = payload.target?.entity
        targetEntityId = payload.target?.entityId
        message = result?.message
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

        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = try validate(response: response, data: data)
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

        let (data, response) = try await URLSession.shared.data(for: request)
        _ = try validate(response: response, data: data)

        if let records = try? JSONDecoder().decode([AdminRequestRecord].self, from: data) {
            return records
        }
        return AdminRequestStore.all().filter { record in
            record.requestedByUserId == requester && (status == nil || record.status == status)
        }
    }

    static func cachedRequests() -> [AdminRequestRecord] {
        AdminRequestStore.all()
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
    private static func validate(response: URLResponse, data: Data) throws -> HTTPURLResponse {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AdminRequestServiceError.requestFailed("No se recibió una respuesta válida del panel administrativo.")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let serverMessage = (try? JSONDecoder().decode(AdminRequestSubmissionResult.self, from: data).message)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let serverMessage, serverMessage.isEmpty == false {
                throw AdminRequestServiceError.requestFailed(serverMessage)
            }
            throw AdminRequestServiceError.requestFailed("El panel administrativo rechazó la solicitud (\(httpResponse.statusCode)).")
        }

        return httpResponse
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
}
