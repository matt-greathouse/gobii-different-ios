import Foundation
import Combine

final class iCloudStorageManager {
    static let shared = iCloudStorageManager()
    private let store = NSUbiquitousKeyValueStore.default

    // Notification publisher for external changes
    var externalChangePublisher: AnyPublisher<Void, Never> {
        externalChangeSubject.eraseToAnyPublisher()
    }
    private let externalChangeSubject = PassthroughSubject<Void, Never>()

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudKeyValueStoreDidChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store
        )
        store.synchronize()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - API Key

    func saveApiKey(_ key: String) {
        store.set(key, forKey: "apiKey")
        store.synchronize()
    }

    func loadApiKey() -> String? {
        return store.string(forKey: "apiKey")
    }

    // MARK: - Tasks

    func saveTasks(_ tasks: [Task]) {
        do {
            let data = try JSONEncoder().encode(tasks)
            store.set(data, forKey: "tasks")
            store.synchronize()
        } catch {
            print("Failed to encode tasks for iCloud storage: \(error)")
        }
    }

    func loadTasks() -> [Task] {
        guard let data = store.data(forKey: "tasks") else {
            return []
        }
        do {
            let tasks = try JSONDecoder().decode([Task].self, from: data)
            return tasks
        } catch {
            print("Failed to decode tasks from iCloud storage: \(error)")
            return []
        }
    }

    // MARK: - Notification handler

    @objc private func iCloudKeyValueStoreDidChange(_ notification: Notification) {
        // Notify subscribers about external changes
        externalChangeSubject.send(())
    }
}
