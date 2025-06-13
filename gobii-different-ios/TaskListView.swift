import SwiftUI
import Combine

// Import app modules or files


// ViewModel for TaskListView
class TaskListViewModel: ObservableObject {
    @Published var tasks: [AppTask] = []

    private let storageManager = iCloudStorageManager.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        loadTasks()
        // Subscribe to external changes from iCloud storage
        storageManager.externalChangePublisher
            .sink { [weak self] _ in
                self?.loadTasks()
            }
            .store(in: &cancellables)
    }

    func loadTasks() {
        tasks = storageManager.loadTasks()
    }

    func saveTasks() {
        storageManager.saveTasks(tasks)
    }

    func addTask(_ task: AppTask) {
        tasks.append(task)
        saveTasks()
    }

    func updateTask(_ task: AppTask) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
            saveTasks()
        }
    }
}

struct TaskListView: View {
    @StateObject private var viewModel = TaskListViewModel()
    @State private var showingNewTaskEditor = false
    @State private var selectedTask: AppTask? = nil

    // New states for alert presentation
    @State private var showingAlert = false
    @State private var alertMessage = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.tasks) { task in
                    HStack {
                        NavigationLink(value: task) {
                            Text(task.name)
                        }
                        Spacer()
                        Button(action: {
                            Task {
                                do {
                                    let response = try await GobiiApiClient.shared.runTask(task)
                                    // Assuming response has id and name fields
                                    alertMessage = "Task run successful: \nName: \(response.name)\nID: \(response.id)"
                                } catch {
                                    alertMessage = "Failed to run task: \(error.localizedDescription)"
                                }
                                showingAlert = true
                            }
                        }) {
                            Text("Run")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                }
            }
            .navigationTitle("Tasks")
            .navigationDestination(for: AppTask.self) { task in
                TaskEditorView(task: task) { updatedTask in
                    viewModel.updateTask(updatedTask)
                }
            }
            .navigationDestination(isPresented: $showingNewTaskEditor) {
                if let newTask = selectedTask {
                    TaskEditorView(task: newTask) { updatedTask in
                        if !viewModel.tasks.contains(where: { $0.id == updatedTask.id }) {
                            viewModel.addTask(updatedTask)
                        } else {
                            viewModel.updateTask(updatedTask)
                        }
                        selectedTask = nil
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        let newTask = AppTask(name: "New Task", prompt: "", outputSchema: .sample)
                        selectedTask = newTask
                        showingNewTaskEditor = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert(isPresented: $showingAlert) {
                Alert(title: Text("Run Task"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
    }
}



// Preview
struct TaskListView_Previews: PreviewProvider {
    static var previews: some View {
        TaskListView()
    }
}
