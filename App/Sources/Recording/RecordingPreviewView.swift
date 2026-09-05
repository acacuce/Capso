import SwiftUI
import Observation

/// Reactive state for the recording preview window. The coordinator
/// flips `isSaving = true` when Save is clicked and feeds `saveProgress`
/// from the export pipeline. The view observes both via `@Observable`
/// tracking and re-renders the right column accordingly.
@MainActor
@Observable
final class RecordingPreviewState {
    var isSaving: Bool = false
    var saveProgress: Double = 0
    var progressLabel: String = String(localized: "Saving…")
}

struct RecordingPreviewView: View {
    let thumbnail: NSImage?
    let duration: String
    let fileSize: String
    let state: RecordingPreviewState
    let onCopy: () -> Void
    let onSave: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .bottomLeading) {
                Rectangle().fill(.black.opacity(0.12))
                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Image(systemName: "video.fill")
                        .font(.system(size: 28))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                QuickAccessWindowDragSurface()
                Label("\(duration) · \(fileSize)", systemImage: "video.fill")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(6)
                    .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 6))
                    .padding(6)
                    .allowsHitTesting(false)
            }
            .frame(height: 142)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .topTrailing) {
                if !state.isSaving {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 26, height: 26)
                            .background(.regularMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dismiss recording")
                    .padding(6)
                }
            }
            Group {
                if state.isSaving {
                    savingOverlay
                } else {
                    HStack(spacing: 8) {
                        quickActionButton("Copy", systemImage: "doc.on.doc", action: onCopy)
                        quickActionButton("Save", systemImage: "square.and.arrow.down", action: onSave)
                    }
                }
            }
            .frame(height: 34)
        }
        .padding(8)
        .frame(width: QuickAccessStackStyle.cardSize.width, height: QuickAccessStackStyle.cardSize.height)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: QuickAccessStackStyle.cardCornerRadius))
    }

    @ViewBuilder
    private var savingOverlay: some View {
        VStack(spacing: 6) {
            GeometryReader { geometry in
                Capsule().fill(.secondary.opacity(0.2))
                    .overlay(alignment: .leading) {
                        Capsule().fill(Color.accentColor)
                            .frame(width: geometry.size.width * min(1, max(0, state.saveProgress)))
                    }
            }
            .frame(height: 4)
            .accessibilityLabel("Export progress")
            .accessibilityValue(Text("\(Int(state.saveProgress * 100)) percent"))
            Text("\(state.progressLabel) \(Int(state.saveProgress * 100))%")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private func quickActionButton(_ title: LocalizedStringKey, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 12))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}
