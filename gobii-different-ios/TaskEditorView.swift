import SwiftUI
import gobii_client_swift

// ViewModel for TaskEditorView
class TaskEditorViewModel: ObservableObject {
    @Published var task: GobiiTask

    private let storageManager = iCloudStorageManager.shared

    init(task: GobiiTask) {
        self.task = task
    }

    func save() {
        // Load existing tasks
        var tasks = storageManager.loadTasks()

        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            // Update existing task
            tasks[index] = task
        } else {
            // Add new task
            tasks.append(task)
        }

        storageManager.saveTasks(tasks)
    }
}

struct TaskEditorView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject var viewModel: TaskEditorViewModel

    init(task: GobiiTask, onSave: @escaping (GobiiTask) -> Void) {
        _viewModel = StateObject(wrappedValue: TaskEditorViewModel(task: task))
        self.onSave = onSave
    }

    var onSave: (GobiiTask) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Task Name")) {
                    TextField("", text: $viewModel.task.name)
                }
                Section(header: Text("Prompt")) {
                    TextEditor(text: Binding(
                        get: { viewModel.task.detail.prompt ?? "" },
                        set: { viewModel.task.detail.prompt = $0 }
                    ))
                        .frame(height: 100)
                }
            }
            .navigationTitle(viewModel.task.name.isEmpty ? "New Task" : viewModel.task.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.save()
                        onSave(viewModel.task)
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

// Preview
struct TaskEditorView_Previews: PreviewProvider {
    static var previews: some View {
        TaskEditorView(task: GobiiTask(name: "Test Task", detail: TaskDetail(prompt: "Test Prompt"))) { _ in }
    }
}
