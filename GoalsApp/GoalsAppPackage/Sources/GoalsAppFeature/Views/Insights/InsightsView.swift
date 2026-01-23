import SwiftUI
import GoalsDomain
import GoalsData

/// Insights view showing minimalistic overview cards with sparkline charts
public struct InsightsView: View {
    @Environment(AppContainer.self) private var container
    @State private var displayMode: InsightDisplayMode = .both
    @State private var isEditing = false
    @State private var draggedType: InsightType?
    @State private var dropTargetType: InsightType?
    @State private var selectedCard: InsightType?

    public var body: some View {
        NavigationStack {
            insightsList(mode: displayMode)
            .animation(.easeInOut(duration: 0.25), value: displayMode)
            .navigationDestination(item: $selectedCard) { type in
                if let card = container.insightsViewModel.cards.first(where: { $0.type == type }) {
                    card.makeDetailView()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack {
                        Text("Insights")
                            .font(.largeTitle.bold())
                        Spacer()
                        Picker("Mode", selection: $displayMode) {
                            ForEach(InsightDisplayMode.allCases, id: \.self) { mode in
                                Image(systemName: mode.systemImage).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .fixedSize()
                        .opacity(isEditing ? 0 : 1)
                    }
                    .frame(maxWidth: .infinity)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEditing ? "Done" : "Edit") {
                        isEditing.toggle()
                    }
                }
            }
            .task(id: container.settingsRevision) {
                await container.insightsViewModel.loadAll()
                container.insightsViewModel.tasks.startLiveUpdates()
            }
            .refreshable {
                await container.insightsViewModel.loadAll(force: true)
            }
            .onAppear {
                container.insightsViewModel.tasks.startLiveUpdates()
            }
            .onDisappear {
                container.insightsViewModel.tasks.stopLiveUpdates()
            }
        }
    }

    @ViewBuilder
    private func insightsList(mode: InsightDisplayMode) -> some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(container.insightsViewModel.cards) { card in
                    insightCardRow(card: card, mode: mode)
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private func insightCardRow(card: InsightCardConfig, mode: InsightDisplayMode) -> some View {
        let isDropTarget = dropTargetType == card.type && draggedType != card.type

        VStack(spacing: 0) {
            // Drop indicator above card
            if isDropTarget && shouldShowIndicatorAbove(for: card.type) {
                dropIndicator
            }

            // Card with tap gesture for navigation (only when not editing)
            InsightCard(
                title: card.title,
                systemImage: card.systemImage,
                color: card.color,
                summary: card.summary,
                activityData: card.activityData,
                mode: mode,
                fetchStatus: card.fetchStatus
            )
            .overlay(alignment: .topTrailing) {
                Image(systemName: "line.3.horizontal")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .opacity(isEditing ? 1 : 0)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                guard !isEditing else { return }
                selectedCard = card.type
            }
            .draggable(card.type, isEnabled: isEditing) {
                InsightCard(
                    title: card.title,
                    systemImage: card.systemImage,
                    color: card.color,
                    summary: card.summary,
                    activityData: card.activityData,
                    mode: mode,
                    fetchStatus: card.fetchStatus
                )
                .frame(width: 300)
                .opacity(0.8)
            }
            .dropDestination(for: InsightType.self) { items, _ in
                handleDrop(items: items, onto: card.type)
            } isTargeted: { isTargeted in
                guard isEditing else { return }
                withAnimation(.easeInOut(duration: 0.15)) {
                    if isTargeted {
                        dropTargetType = card.type
                    } else if dropTargetType == card.type {
                        dropTargetType = nil
                    }
                }
            }
            .onDrag(isEnabled: isEditing) {
                draggedType = card.type
                return NSItemProvider(object: card.type.rawValue as NSString)
            }

            // Drop indicator below card (for last item)
            if isDropTarget && !shouldShowIndicatorAbove(for: card.type) {
                dropIndicator
            }
        }
    }

    private var dropIndicator: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.accentColor)
            .frame(height: 4)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
    }

    private func shouldShowIndicatorAbove(for targetType: InsightType) -> Bool {
        guard let draggedType,
              let fromIndex = container.insightsViewModel.cardOrder.firstIndex(of: draggedType),
              let toIndex = container.insightsViewModel.cardOrder.firstIndex(of: targetType) else {
            return true
        }
        return toIndex < fromIndex
    }

    private func handleDrop(items: [InsightType], onto targetType: InsightType) -> Bool {
        defer {
            draggedType = nil
            dropTargetType = nil
        }

        guard isEditing,
              let droppedType = items.first,
              let fromIndex = container.insightsViewModel.cardOrder.firstIndex(of: droppedType),
              let toIndex = container.insightsViewModel.cardOrder.firstIndex(of: targetType),
              fromIndex != toIndex else {
            return false
        }

        withAnimation(.easeInOut(duration: 0.25)) {
            container.insightsViewModel.moveCard(
                from: IndexSet(integer: fromIndex),
                to: toIndex > fromIndex ? toIndex + 1 : toIndex
            )
        }
        return true
    }

    public init() {}
}

// MARK: - Drag Modifier Extensions

private extension View {
    @ViewBuilder
    func draggable<T: Transferable>(_ payload: T, isEnabled: Bool, @ViewBuilder preview: () -> some View) -> some View {
        if isEnabled {
            self.draggable(payload, preview: preview)
        } else {
            self
        }
    }

    @ViewBuilder
    func onDrag(isEnabled: Bool, data: @escaping () -> NSItemProvider) -> some View {
        if isEnabled {
            self.onDrag(data)
        } else {
            self
        }
    }
}

#Preview {
    InsightsView()
        .environment(try! AppContainer.preview())
}
