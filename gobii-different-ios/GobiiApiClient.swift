import Foundation

enum GobiiApiError: Error, LocalizedError {
    case missingApiKey
    case invalidResponse
    case serverError(statusCode: Int)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .missingApiKey:
            return "API key is missing. Please configure your API key in settings."
        case .invalidResponse:
            return "Received invalid response from the server."
        case .serverError(let statusCode):
            return "Server returned an error with status code \(statusCode)."
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error occurred: \(error.localizedDescription)"
        }
    }
}

class GobiiApiClient {
    static let shared = GobiiApiClient()
    private init() {}

    /// Runs the given task by sending a POST request to /tasks/browser-use/ endpoint.
    /// - Parameter task: The Task object to run.
    /// - Returns: The Task object returned by the server.
    /// - Throws: GobiiApiError for various failure cases.
    func runTask(_ task: AppTask) async throws -> AppTask {
        // Retrieve API key
        guard let apiKey = iCloudStorageManager.shared.loadApiKey(), !apiKey.isEmpty else {
            throw GobiiApiError.missingApiKey
        }

        // Construct URL
        guard let url = URL(string: "https://api.gobii.org/tasks/browser-use/") else {
            throw GobiiApiError.invalidResponse
        }

        // Prepare URLRequest
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        // Encode Task to JSON
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        do {
            let taskDetail = TaskDetail(from: task) // Convert Task to TaskDetail for API schema
            let jsonData = try encoder.encode(taskDetail)
            request.httpBody = jsonData
        } catch {
            throw GobiiApiError.decodingError(error)
        }

        // Send request
        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw GobiiApiError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw GobiiApiError.serverError(statusCode: httpResponse.statusCode)
            }

            // Decode response
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            do {
                let taskResponse = try decoder.decode(TaskDetail.self, from: data)
                return AppTask(from: taskResponse) // Convert back to Task model
            } catch {
                throw GobiiApiError.decodingError(error)
            }
        } catch {
            throw GobiiApiError.networkError(error)
        }
    }
}

// MARK: - TaskDetail API Model

// Define TaskDetail struct matching the API schema for /tasks/browser-use/
// This struct is Codable and converts to/from Task model

struct TaskDetail: Codable {
    var id: UUID?
    var name: String
    var prompt: String
    var outputSchema: OutputSchema?

    // Additional fields could be added here if API expands

    // Init from Task model
    init(from task: AppTask) {
        self.id = task.id
        self.name = task.name
        self.prompt = task.prompt
        self.outputSchema = task.outputSchema
    }

    // Convenience to convert back to Task
    func toTask() -> AppTask {
        return AppTask(id: self.id ?? UUID(), name: self.name, prompt: self.prompt, outputSchema: self.outputSchema ?? .string)
    }
}

// Extend Task to init from TaskDetail
extension AppTask {
    init(from detail: TaskDetail) {
        self.id = detail.id ?? UUID()
        self.name = detail.name
        self.prompt = detail.prompt
        self.outputSchema = detail.outputSchema ?? .string
    }
}

// Extend Task to convert to TaskDetail
extension AppTask {
    func toTaskDetail() -> TaskDetail {
        return TaskDetail(from: self)
    }
}
