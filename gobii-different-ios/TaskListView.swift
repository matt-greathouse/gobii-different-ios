import SwiftUI
import Combine
import gobii_client_swift

// Import app modules or files


// ViewModel for TaskListView
@MainActor
class TaskListViewModel: ObservableObject {
    @Published var tasks: [GobiiTask] = []
    @Published private var checkingTaskIDs: Set<String> = []

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
    
    func checkAllTasks() {
        Task {
            guard let apiKey = iCloudStorageManager.shared.loadApiKey(), !apiKey.isEmpty else {
                print("Missing API key")
                return
            }
            
            let client = GobiiApiClient(debugMode: true)
            await client.setApiKey(apiKey)
            
            for task in self.tasks {
                if task.detail.status == .in_progress || task.detail.status == .pending {
                    await self.checkStatusWorker(client: client, task: task)
                }
            }
        }
    }

    func loadTasks() {
        tasks = storageManager.loadTasks()
    }

    func saveTasks() {
        storageManager.saveTasks(tasks)
    }

    func addTask(_ task: GobiiTask) {
        tasks.append(task)
        saveTasks()
    }

    func updateTask(_ task: GobiiTask) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
            saveTasks()
        }
    }

    /// Runs the given task asynchronously, updating running state and polling status.
    func runTask(_ task: GobiiTask) async {
        do {
            guard let apiKey = iCloudStorageManager.shared.loadApiKey(), !apiKey.isEmpty else {
                print("missing api key")
                return
            }
            
            var currentResult = task
            currentResult.detail.status = .pending
            updateTask(currentResult)
            
            let client = GobiiApiClient(debugMode: true)
            await client.setApiKey(apiKey)
            // Start running the task
            let runResult = try await client.runTask(task.detail)

            if let index = self.tasks.firstIndex(where: { $0.id == task.id }) {
                self.tasks[index].id = runResult.id ?? ""
                self.saveTasks()
                currentResult.id = runResult.id ?? ""
            }
            
            await checkStatusWorker(client: client, task: currentResult)
        } catch {
            // Notify UI or log error - this example does not have error UI in ViewModel
            print("Error running task: \(error)")
        }
    }
    
    func checkStatusWorker(client: GobiiApiClient, task: GobiiTask) async {
        let alreadyChecking = await MainActor.run { checkingTaskIDs.contains(task.id) }
        if alreadyChecking { return }
        await MainActor.run { checkingTaskIDs.insert(task.id) }
        defer { Task { await MainActor.run { checkingTaskIDs.remove(task.id) } } }
        
        do {
            var currentResult = task
            // Poll for status updates every 5 seconds until completed
            statusCheck: while true {
                // Wait 5 seconds
                try await Task.sleep(nanoseconds: 5 * 1_000_000_000)
                
                // Fetch updated task status
                let updatedTask = try await client.fetchTaskStatus(id: currentResult.id)
                var updatedResult = currentResult
                updatedResult.detail.status = updatedTask.status
                
                if let status = updatedTask.status {
                    switch status {
                    case .completed:
                        updatedResult.lastResult = updatedTask.result ?? ""
                    case .cancelled:
                        updatedResult.lastResult = "Cancelled"
                    case .failed:
                        updatedResult.lastResult = "Failed"
                    default:
                        break
                    }
                    
                    await MainActor.run {
                        self.updateTask(updatedResult)
                    }
                    
                    if status == .failed ||
                        status == .completed ||
                        status == .cancelled {
                        break statusCheck
                    }
                }
                currentResult = updatedResult
            }
        }
        catch {
            print("Error running task: \(error)")
        }
    }
}

struct TaskRowView: View {
    let task: GobiiTask
    let onRun: () -> Void

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(task.name)
                    .font(.headline)
                Spacer()
                if (task.detail.status == .in_progress || task.detail.status == .pending) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    Button(action: onRun) {
                        Image(systemName: "play.fill")
                            .padding(6)
                            .background(Circle().fill(Color.blue.opacity(0.1)))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            if let lastResult = Optional(task.lastResult), !lastResult.isEmpty {
                Text(lastResult)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct TaskListView: View {
    @StateObject private var viewModel: TaskListViewModel = TaskListViewModel();
    @State private var showingNewTaskEditor = false
    @State private var selectedTask: GobiiTask? = nil
    
    init(viewModel: TaskListViewModel? = nil) {
        if let viewModel = viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        }
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.tasks) { task in
                    Button(action: {
                        selectedTask = task
                    }) {
                        TaskRowView(
                            task: task,
                            onRun: {
                                Task {
                                    await viewModel.runTask(task)
                                }
                            }
                        )
                    }
                    .sheet(item: $selectedTask) { task in
                        TaskEditorView(task: task) { updatedTask in
                            viewModel.updateTask(updatedTask)
                            selectedTask = nil
                        }
                    }
                }
                .onDelete { indexSet in
                    viewModel.tasks.remove(atOffsets: indexSet)
                    viewModel.saveTasks()
                }
            }
            .navigationTitle("Tasks")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingNewTaskEditor = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewTaskEditor) {
                TaskEditorView(task: GobiiTask(name: "", detail: TaskDetail(id: UUID().uuidString)), onSave: { newTask in
                    viewModel.addTask(newTask)
                    showingNewTaskEditor = false
                })
            }
        }
        .onAppear {
            viewModel.checkAllTasks()
        }
    }
}



// Preview
struct TaskListView_Previews: PreviewProvider {
    static var previews: some View {
        let mockViewModel = TaskListViewModel();
        mockViewModel.tasks = [
            GobiiTask(name: "Sample Task 1", detail: TaskDetail(id: UUID().uuidString, prompt: "Sample Prompt", outputSchema: nil)),
            GobiiTask(name: "Sample Task 2", detail: TaskDetail(id: UUID().uuidString, prompt: "Sample Prompt", outputSchema: nil)),
            GobiiTask(name: "Sample Task 3", detail: TaskDetail(id: UUID().uuidString, prompt: "Sample Prompt", outputSchema: nil)),
        ]
        return TaskListView(viewModel: mockViewModel)
    }
}
