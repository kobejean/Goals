import SwiftUI
import GoalsDomain

/// Form for creating or editing a task definition
struct CreateTaskView: View {
    @Environment(\.dismiss) private var dismiss

    let existingTask: TaskDefinition?
    let onSave: (TaskDefinition) -> Void

    @State private var name: String = ""
    @State private var selectedColor: TaskColor = .blue
    @State private var selectedIcon: String = "checkmark.circle"

    private var isEditing: Bool {
        existingTask != nil
    }

    private let availableIcons = [
        "checkmark.circle",
        "book",
        "pianokeys",
        "figure.run",
        "brain.head.profile",
        "pencil",
        "laptopcomputer",
        "gamecontroller",
        "music.note",
        "paintbrush",
        "wrench.and.screwdriver",
        "leaf",
        "heart",
        "star",
        "flame",
        "bolt",
        "cup.and.saucer",
        "bed.double",
        "person.2",
        "phone"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Task Name") {
                    TextField("Enter task name", text: $name)
                        .textInputAutocapitalization(.words)
                }

                Section("Color") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
                        ForEach(TaskColor.allCases, id: \.self) { color in
                            Button {
                                selectedColor = color
                            } label: {
                                Circle()
                                    .fill(color.swiftUIColor)
                                    .frame(width: 36, height: 36)
                                    .overlay {
                                        if selectedColor == color {
                                            Image(systemName: "checkmark")
                                                .font(.caption.bold())
                                                .foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(color.displayName)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("Icon") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
                        ForEach(availableIcons, id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.title2)
                                    .frame(width: 44, height: 44)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(selectedIcon == icon
                                                ? selectedColor.swiftUIColor.opacity(0.2)
                                                : Color.clear)
                                    )
                                    .foregroundStyle(selectedIcon == icon
                                        ? selectedColor.swiftUIColor
                                        : .secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(icon)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle(isEditing ? "Edit Task" : "New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveTask()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let existing = existingTask {
                    name = existing.name
                    selectedColor = existing.color
                    selectedIcon = existing.icon
                }
            }
        }
    }

    private func saveTask() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        let task = TaskDefinition(
            id: existingTask?.id ?? UUID(),
            name: trimmedName,
            color: selectedColor,
            icon: selectedIcon,
            isArchived: existingTask?.isArchived ?? false,
            createdAt: existingTask?.createdAt ?? Date(),
            sortOrder: existingTask?.sortOrder ?? 0
        )

        onSave(task)
        dismiss()
    }
}

#Preview("Create") {
    CreateTaskView(existingTask: nil) { task in
        print("Created: \(task.name)")
    }
}

#Preview("Edit") {
    CreateTaskView(
        existingTask: TaskDefinition(name: "Reading", color: .blue, icon: "book")
    ) { task in
        print("Updated: \(task.name)")
    }
}
