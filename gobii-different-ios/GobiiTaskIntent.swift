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
    
    // Perform method runs the task asynchronously and returns the lastResult
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
        
        // Poll for status until completion or failure
        var finalResult = ""
        var status = runResult.status
        var currentTask = runResult
        
        while status == .pending || status == .in_progress {
            try await Task.sleep(nanoseconds: 2 * 1_000_000_000) // 2 seconds delay
            currentTask = try await client.fetchTaskStatus(id: currentTask.id ?? "")
            status = currentTask.status
        }
        
        if status == .completed {
            finalResult = currentTask.result ?? ""
        } else if status == .failed {
            finalResult = "Failed"
        } else if status == .cancelled {
            finalResult = "Cancelled"
        } else {
            finalResult = "Unknown status"
        }
        
        let dialog = IntentDialog(full: "Result: \(finalResult)",
                                  supporting: "\(finalResult)")
        
        return .result(value: finalResult, dialog: dialog)
    }
}
