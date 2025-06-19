import Foundation
import gobii_client_swift


public struct GobiiTask: Identifiable, Hashable, Codable {
    public var id: String = UUID().uuidString.lowercased()
    public var name: String = ""
    public var lastResult: String = ""
    public var detail: TaskDetail

    public init(name: String, detail: TaskDetail) {
        self.name = name
        self.detail = detail
        self.id = detail.id ?? UUID().uuidString.lowercased()
    }
}
