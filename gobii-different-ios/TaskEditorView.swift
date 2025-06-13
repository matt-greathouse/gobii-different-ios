import SwiftUI

// ViewModel for TaskEditorView
class TaskEditorViewModel: ObservableObject {
    @Published var task: Task

    private let storageManager = iCloudStorageManager.shared

    init(task: Task) {
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

// View for editing the OutputSchema recursively
struct OutputSchemaEditorView: View {
    @Binding var schema: OutputSchema
    @State private var newFieldName: String = ""

    var body: some View {
        switch schema {
        case .number:
            Text("Number")
        case .string:
            Text("String")
        case .boolean:
            Text("Boolean")
        case .object(let properties):
            let keys = Array(properties.keys.sorted())
            VStack(alignment: .leading) {
                List {
                    ForEach(keys, id: \String.self) { key in
                        if let value = properties[key] {
                            PropertyRow(key: key, value: value, onUpdate: { newValue in
                                var updatedProperties = properties
                                updatedProperties[key] = newValue
                                schema = .object(properties: updatedProperties)
                            }, onRemove: {
                                var updatedProperties = properties
                                updatedProperties.removeValue(forKey: key)
                                schema = .object(properties: updatedProperties)
                            })
                        }
                    }
                }
                HStack {
                    TextField("New Field Name", text: $newFieldName)
                    OutputSchemaPicker(schema: .constant(.string))
                        .frame(width: 100)
                    Button("Add") {
                        guard !newFieldName.isEmpty else { return }
                        var updatedProperties = properties
                        updatedProperties[newFieldName] = .string
                        schema = .object(properties: updatedProperties)
                        newFieldName = ""
                    }
                }
                .padding(.horizontal)
            }
        case .array(let items):
            VStack(alignment: .leading) {
                Text("Array of:")
                OutputSchemaEditorView(schema: Binding(
                    get: { items },
                    set: { newSchema in
                        schema = .array(items: newSchema)
                    }))
            }
        }
    }
}

struct PropertyRow: View {
    let key: String
    let value: OutputSchema
    let onUpdate: (OutputSchema) -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(key)
                    .fontWeight(.bold)
                Spacer()
                OutputSchemaPicker(schema: Binding(
                    get: { value },
                    set: { newValue in
                        onUpdate(newValue)
                    }))
                Button(action: {
                    onRemove()
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
            if case .object = value {
                OutputSchemaEditorView(schema: Binding(
                    get: { value },
                    set: { newValue in
                        onUpdate(newValue)
                    }))
            } else if case .array = value {
                OutputSchemaEditorView(schema: Binding(
                    get: { value },
                    set: { newValue in
                        onUpdate(newValue)
                    }))
            }
        }
    }
}

// Picker view for selecting OutputSchema type
struct OutputSchemaPicker: View {
    @Binding var schema: OutputSchema
    @State private var selectedType: OutputSchema.OutputType = .string

    var body: some View {
        Picker("", selection: Binding(
            get: {
                switch schema {
                case .number: return OutputSchema.OutputType.number
                case .string: return OutputSchema.OutputType.string
                case .boolean: return OutputSchema.OutputType.boolean
                case .object: return OutputSchema.OutputType.object
                case .array: return OutputSchema.OutputType.array
                }
            },
            set: { newType in
                switch newType {
                case .number:
                    schema = .number
                case .string:
                    schema = .string
                case .boolean:
                    schema = .boolean
                case .object:
                    schema = .object(properties: [:])
                case .array:
                    schema = .array(items: .string)
                }
            })) {
            Text("Number").tag(OutputSchema.OutputType.number)
            Text("String").tag(OutputSchema.OutputType.string)
            Text("Boolean").tag(OutputSchema.OutputType.boolean)
            Text("Object").tag(OutputSchema.OutputType.object)
            Text("Array").tag(OutputSchema.OutputType.array)
        }
        .pickerStyle(MenuPickerStyle())
    }
}

struct TaskEditorView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject var viewModel: TaskEditorViewModel

    init(task: Task, onSave: @escaping (Task) -> Void) {
        _viewModel = StateObject(wrappedValue: TaskEditorViewModel(task: task))
        self.onSave = onSave
    }

    var onSave: (Task) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Task Name")) {
                    TextField("", text: $viewModel.task.name)
                }
                Section(header: Text("Prompt")) {
                    TextEditor(text: $viewModel.task.prompt)
                        .frame(height: 100)
                }
                Section(header: Text("Output Schema")) {
                    OutputSchemaEditorView(schema: $viewModel.task.outputSchema)
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
        TaskEditorView(task: Task()) { _ in }
    }
}
