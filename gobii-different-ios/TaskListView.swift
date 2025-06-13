import SwiftUI
import Combine

// ViewModel for TaskListView
class TaskListViewModel: ObservableObject {
    @Published var tasks: [Task] = []

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

    func addTask(_ task: Task) {
        tasks.append(task)
        saveTasks()
    }

    func updateTask(_ task: Task) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
            saveTasks()
        }
    }
}

struct TaskListView: View {
    @StateObject private var viewModel = TaskListViewModel()
    @State private var showingNewTaskEditor = false
    @State private var selectedTask: Task? = nil

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.tasks) { task in
                    NavigationLink(value: task) {
                        Text(task.name)
                    }
                }
            }
            .navigationTitle("Tasks")
            .navigationDestination(for: Task.self) { task in
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
                        let newTask = Task(name: "New Task", prompt: "", outputSchema: .sample)
                        selectedTask = newTask
                        showingNewTaskEditor = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
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
