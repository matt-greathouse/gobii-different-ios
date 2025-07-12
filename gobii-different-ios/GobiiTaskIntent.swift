import Foundation
import AppIntents
import gobii_client_swift

struct GobiiTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Run Gobii Task"
    
    // Input parameter: prompt string
    @Parameter(title: "Prompt")
    var prompt: String
    
    // Output structure for the intent
    struct Output: Codable, CustomStringConvertible {
        let lastResult: String
        
        var description: String { lastResult }
    }
    
    // Perform method creates the task and returns its ID without polling
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        // Create a TaskDetail with given prompt
        let taskDetail = TaskDetail(id: UUID().uuidString, prompt: prompt, outputSchema: nil)
        
        // Load API key
        guard let apiKey = iCloudStorageManager.shared.loadApiKey(), !apiKey.isEmpty else {
            throw NSError(
                domain: "GobiiTaskIntent",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "API key is missing. Please configure your API key in the app settings."]
            )
        }
        
        let client = GobiiApiClient(debugMode: true)
        await client.setApiKey(apiKey)
        
        // Run the task using the GobiiApiClient
        let runResult = try await client.runTask(taskDetail)
        
        let taskId = runResult.id ?? "Unknown ID"
        
        let dialog = IntentDialog(full: "Task created with ID: \(taskId)",
                                  supporting: "Task ID: \(taskId)")
        
        return .result(value: taskId, dialog: dialog)
    }
}
