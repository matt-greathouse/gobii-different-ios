import Foundation
import AppIntents
import gobii_client_swift

struct GobiiTaskStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Gobii Task Status"
    
    @Parameter(title: "Task ID")
    var taskId: String
    
    struct Output: Codable, CustomStringConvertible {
        let status: String
        let result: String?
        
        var description: String {
            if let result = result, !result.isEmpty {
                return "Status: \(status), Result: \(result)"
            } else {
                return "Status: \(status)"
            }
        }
    }
    
    func perform() async throws -> some IntentResult & ReturnsValue<String?> & ProvidesDialog {
        // Load API key
        guard let apiKey = iCloudStorageManager.shared.loadApiKey(), !apiKey.isEmpty else {
            throw NSError(
                domain: "GobiiTaskStatusIntent",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "API key is missing. Please configure your API key in the app settings."]
            )
        }
        
        let client = GobiiApiClient(debugMode: true)
        await client.setApiKey(apiKey)
        
        // Fetch the task status using the GobiiApiClient
        let taskStatus = try await client.fetchTaskStatus(id: taskId)
        
        let statusString: String
        switch taskStatus.status {
        case .pending:
            statusString = "Pending"
        case .in_progress:
            statusString = "In Progress"
        case .completed:
            statusString = "Completed"
        case .failed:
            statusString = "Failed"
        case .cancelled:
            statusString = "Cancelled"
        default:
            statusString = "Unknown"
        }
        
        if taskStatus.status == .failed || taskStatus.status == .cancelled {
            throw NSError(
                domain: "GobiiTaskStatusIntent",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Task status is \(statusString). Please check the task details for more information."]
            )
        }
        
        let resultString: String
        let dialog: IntentDialog
        
        if taskStatus.status == .completed {
            resultString = taskStatus.result ?? ""
            dialog = IntentDialog(full: "Status: \(statusString)\nResult: \(resultString)",
                                  supporting: "Status: \(statusString)")
            return .result(value: "\(resultString)", dialog: dialog)
        } else {
            dialog = IntentDialog(full: "Status: \(statusString)\nThe task is not completed yet.",
                                  supporting: "Status: \(statusString)")
            return .result(value: nil, dialog: dialog)
        }
    }
}
