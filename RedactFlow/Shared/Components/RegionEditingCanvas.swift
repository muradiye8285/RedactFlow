import SwiftUI

struct RegionEditingCanvas<Content: View>: View {
    let mediaSize: CGSize
    let regions: [RedactionRegion]
    let selectedRegionID: UUID?
    let isInteractionEnabled: Bool
    let onSelectRegion: (UUID) -> Void
    let onBeginMove: (UUID) -> Void
    let onMove: (UUID, CGSize, CGSize) -> Void
    let onBeginResize: (UUID) -> Void
    let onResize: (UUID, CGSize, CGSize) -> Void
    let onEndGesture: () -> Void
    let content: () -> Content

    var body: some View {
        GeometryReader { geometry in
            let fittedSize = mediaSize.aspectFit(in: geometry.size)
            let canvasFrame = CGRect(
                x: (geometry.size.width - fittedSize.width) / 2,
                y: (geometry.size.height - fittedSize.height) / 2,
                width: fittedSize.width,
                height: fittedSize.height
            )

            ZStack(alignment: .topLeading) {
                content()
                    .frame(width: canvasFrame.width, height: canvasFrame.height)
                    .position(x: canvasFrame.midX, y: canvasFrame.midY)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                ForEach(regions) { region in
                    let regionFrame = region.normalizedRect.denormalized(in: canvasFrame.size)

                    EditableRegionView(
                        region: region,
                        isSelected: region.id == selectedRegionID,
                        canvasSize: canvasFrame.size,
                        isInteractionEnabled: isInteractionEnabled,
                        onSelect: { onSelectRegion(region.id) },
                        onBeginMove: { onBeginMove(region.id) },
                        onMove: { translation in
                            onMove(region.id, translation, canvasFrame.size)
                        },
                        onBeginResize: { onBeginResize(region.id) },
                        onResize: { translation in
                            onResize(region.id, translation, canvasFrame.size)
                        },
                        onEndGesture: onEndGesture
                    )
                    .frame(width: regionFrame.width, height: regionFrame.height)
                    .position(
                        x: canvasFrame.minX + regionFrame.midX,
                        y: canvasFrame.minY + regionFrame.midY
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct EditableRegionView: View {
    let region: RedactionRegion
    let isSelected: Bool
    let canvasSize: CGSize
    let isInteractionEnabled: Bool
    let onSelect: () -> Void
    let onBeginMove: () -> Void
    let onMove: (CGSize) -> Void
    let onBeginResize: () -> Void
    let onResize: (CGSize) -> Void
    let onEndGesture: () -> Void

    @State private var moveStarted = false
    @State private var resizeStarted = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            overlayFill
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    isSelected ? Color.white : Color.white.opacity(0.48),
                    style: StrokeStyle(lineWidth: isSelected ? 2.5 : 1.25, dash: isSelected ? [] : [7, 4])
                )

            HStack(spacing: 6) {
                Image(systemName: region.style.systemImage)
                Text(region.style.title)
            }
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.black.opacity(0.54)))
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if isSelected {
                Circle()
                    .fill(Color.white)
                    .frame(width: 22, height: 22)
                    .overlay(
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.black)
                    )
                    .padding(10)
                    .gesture(resizeGesture)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .gesture(moveGesture)
        .shadow(color: .black.opacity(0.18), radius: 14, y: 8)
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard isInteractionEnabled else { return }
                if !moveStarted {
                    moveStarted = true
                    onSelect()
                    onBeginMove()
                }
                onMove(value.translation)
            }
            .onEnded { _ in
                guard isInteractionEnabled else { return }
                moveStarted = false
                onEndGesture()
            }
    }

    private var resizeGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard isInteractionEnabled else { return }
                if !resizeStarted {
                    resizeStarted = true
                    onBeginResize()
                }
                onResize(value.translation)
            }
            .onEnded { _ in
                guard isInteractionEnabled else { return }
                resizeStarted = false
                onEndGesture()
            }
    }

    private var overlayFill: some View {
        switch region.style {
        case .blur:
            return AnyView(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(0.16))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
            )
        case .pixelate:
            return AnyView(
                PixelateFillView()
                    .overlay(Color.black.opacity(0.08))
            )
        case .blackBar:
            return AnyView(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.black.opacity(0.92))
            )
        }
    }

    private var cornerRadius: CGFloat {
        CGFloat(region.cornerRadius) * min(canvasSize.width, canvasSize.height) * 0.12 + 8
    }
}

private struct PixelateFillView: View {
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let step = max(10, min(size.width, size.height) / 5)
                let rows = Int(ceil(size.height / step))
                let columns = Int(ceil(size.width / step))

                for row in 0..<rows {
                    for column in 0..<columns {
                        let rect = CGRect(
                            x: CGFloat(column) * step,
                            y: CGFloat(row) * step,
                            width: step,
                            height: step
                        )
                        let tint = (row + column).isMultiple(of: 2) ? 0.28 : 0.18
                        context.fill(Path(rect), with: .color(Color.white.opacity(tint)))
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}
