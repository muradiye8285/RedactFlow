import Foundation

final class RedactionHistoryController {
    private var undoStack: [RedactionEditorSnapshot] = []
    private var redoStack: [RedactionEditorSnapshot] = []

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    func capture(_ snapshot: RedactionEditorSnapshot) {
        undoStack.append(snapshot)
        redoStack.removeAll()
    }

    func undo(from current: RedactionEditorSnapshot) -> RedactionEditorSnapshot? {
        guard let snapshot = undoStack.popLast() else { return nil }
        redoStack.append(current)
        return snapshot
    }

    func redo(from current: RedactionEditorSnapshot) -> RedactionEditorSnapshot? {
        guard let snapshot = redoStack.popLast() else { return nil }
        undoStack.append(current)
        return snapshot
    }

    func reset() {
        undoStack.removeAll()
        redoStack.removeAll()
    }
}
