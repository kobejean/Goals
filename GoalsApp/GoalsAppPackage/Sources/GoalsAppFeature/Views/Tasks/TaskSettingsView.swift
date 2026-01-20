import SwiftUI
import GoalsDomain

/// View for managing task definitions (add, edit, delete)
struct TaskSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    let tasks: [TaskDefinition]
    let onCreateTask: (TaskDefinition) -> Void
    let onUpdateTask: (TaskDefinition) -> Void
    let onDeleteTask: (TaskDefinition) -> Void

    @State private var showingCreateSheet = false
    @State private var taskToEdit: TaskDefinition?

    var body: some View {
        NavigationStack {
            List {
                ForEach(tasks) { task in
                    HStack {
                        Image(systemName: task.icon)
                            .font(.title2)
                            .foregroundStyle(task.color.swiftUIColor)
                            .frame(width: 32)

                        Text(task.name)
                            .font(.body)

                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        taskToEdit = task
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            onDeleteTask(task)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }

                Button {
                    showingCreateSheet = true
                } label: {
                    Label("Add Task", systemImage: "plus")
                }
            }
            .navigationTitle("Manage Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingCreateSheet) {
                CreateTaskView(existingTask: nil) { task in
                    onCreateTask(task)
                }
            }
            .sheet(item: $taskToEdit) { task in
                CreateTaskView(existingTask: task) { updatedTask in
                    onUpdateTask(updatedTask)
                }
            }
        }
    }
}

#Preview {
    TaskSettingsView(
        tasks: [
            TaskDefinition(name: "Reading", color: .blue, icon: "book"),
            TaskDefinition(name: "Piano", color: .purple, icon: "pianokeys"),
            TaskDefinition(name: "Exercise", color: .green, icon: "figure.run")
        ],
        onCreateTask: { _ in },
        onUpdateTask: { _ in },
        onDeleteTask: { _ in }
    )
}
