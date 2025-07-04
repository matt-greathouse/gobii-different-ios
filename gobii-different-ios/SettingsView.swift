import SwiftUI
import Combine

final class SettingsViewModel: ObservableObject {
    @Published var apiKey: String = "" {
        didSet {
            saveApiKey()
        }
    }

    private var cancellables = Set<AnyCancellable>()

    init() {
        loadApiKey()
        // Optionally listen for external changes if needed
        iCloudStorageManager.shared.externalChangePublisher
            .sink { [weak self] in
                self?.loadApiKey()
            }
            .store(in: &cancellables)
    }

    private func loadApiKey() {
        if let loadedKey = iCloudStorageManager.shared.loadApiKey() {
            if loadedKey != apiKey {
                DispatchQueue.main.async {
                    self.apiKey = loadedKey
                }
            }
        }
    }

    func saveApiKey() {
        iCloudStorageManager.shared.saveApiKey(apiKey)
    }

    func deleteApiKey() {
        iCloudStorageManager.shared.saveApiKey("")
        DispatchQueue.main.async {
            self.apiKey = ""
        }
    }
}

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("API Key")) {
                    SecureField("Enter API Key", text: $viewModel.apiKey)
                        .textContentType(.password)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    Button("Delete") {
                        viewModel.deleteApiKey()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
