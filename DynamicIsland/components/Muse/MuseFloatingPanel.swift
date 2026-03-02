/*
 * Notchi (DynamicIsland)
 * Copyright (C) 2024-2026 Notchi Contributors
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <https://www.gnu.org/licenses/>.
 */

import AppKit
import Combine
import Defaults
import SwiftUI

private enum MuseFloatingPanelSizing {
    static let minWidth: CGFloat = 360
    static let maxWidth: CGFloat = 900
    static let minCompactHeight: CGFloat = 84
    static let maxCompactHeight: CGFloat = 280
    static let minExpandedHeight: CGFloat = 220
    static let maxExpandedHeight: CGFloat = 980
    static let minExpandedDelta: CGFloat = 120
    static let minEdgeInset: CGFloat = 8
    static let maxEdgeInset: CGFloat = 120
}

final class MuseFloatingPanel: NSPanel, NSWindowDelegate {
    private let positionXKey = "museFloatingPanelPositionX"
    private let positionYKey = "museFloatingPanelPositionY"
    private let positionSavedKey = "museFloatingPanelPositionSaved"
    private let museManager = MuseManager.shared
    private var isApplyingProgrammaticFrame = false
    private var isSynchronizingSizeFromResize = false
    private var pendingPositionSaveWorkItem: DispatchWorkItem?

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )

        setupWindow()
        setupContentView()
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    private func setupWindow() {
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        level = .floating
        isMovableByWindowBackground = true
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        isFloatingPanel = true

        styleMask.insert(.fullSizeContentView)
        styleMask.insert(.resizable)
        collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .fullScreenAuxiliary
        ]
        delegate = self

        ScreenCaptureVisibilityManager.shared.register(self, scope: .panelsOnly)
        acceptsMouseMovedEvents = true
    }

    private func setupContentView() {
        let content = MuseFloatingPanelView { [weak self] in
            self?.close()
        }
        let host = NSHostingView(rootView: content)
        host.wantsLayer = true
        host.layer?.cornerRadius = 16
        host.layer?.masksToBounds = true
        if #available(macOS 13.0, *) {
            host.layer?.cornerCurve = .continuous
        }
        self.contentView = host
        refreshLayout(animated: false)
    }

    func refreshLayout(animated: Bool) {
        let size = panelTargetSize()
        updateResizeBounds(for: size)
        let useDefaultPosition = !Defaults[.museFloatingPanelRememberLastPosition]
        let targetFrame = resolvedFrame(for: size, forceDefaultPosition: useDefaultPosition)

        guard hasMeaningfulFrameChange(targetFrame) else { return }
        applyFrame(targetFrame, animated: animated, display: true)
    }

    func positionDefaultIfNeeded() {
        let panelSize = panelTargetSize()
        updateResizeBounds(for: panelSize)

        if Defaults[.museFloatingPanelRememberLastPosition], let saved = savedPosition() {
            let targetFrame = resolvedFrame(for: panelSize, preferredOrigin: saved)
            applyFrame(targetFrame, animated: false, display: false)
            return
        }

        let targetFrame = resolvedFrame(for: panelSize, forceDefaultPosition: true)
        applyFrame(targetFrame, animated: false, display: false)
    }

    override func setFrameOrigin(_ point: NSPoint) {
        super.setFrameOrigin(point)
        guard !isApplyingProgrammaticFrame else { return }
        guard !inLiveResize else { return }
        scheduleCurrentOriginPersistenceIfNeeded(point)
    }

    override func close() {
        persistCurrentOriginIfNeeded(frame.origin)
        super.close()
    }

    func invalidateSavedPosition() {
        clearSavedPosition()
    }

    private func panelTargetSize() -> CGSize {
        let width = resolvedWidth()
        let compactHeight = resolvedCompactHeight()
        let expandedHeight = resolvedExpandedHeight(compactHeight: compactHeight)
        let hasMessages = !(museManager.currentConversation?.messages.isEmpty ?? true)
        let height = hasMessages ? expandedHeight : compactHeight
        return CGSize(width: width, height: height)
    }

    private func applyFrame(_ targetFrame: NSRect, animated: Bool, display: Bool) {
        if animated {
            isApplyingProgrammaticFrame = true
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                self.animator().setFrame(targetFrame, display: display)
            } completionHandler: { [weak self] in
                self?.isApplyingProgrammaticFrame = false
            }
        } else {
            isApplyingProgrammaticFrame = true
            setFrame(targetFrame, display: display)
            isApplyingProgrammaticFrame = false
        }
    }

    private func updateResizeBounds(for size: CGSize) {
        let hasMessages = !(museManager.currentConversation?.messages.isEmpty ?? true)
        let minWidth = MuseFloatingPanelSizing.minWidth
        let maxWidth = MuseFloatingPanelSizing.maxWidth
        let minHeight: CGFloat
        let maxHeight: CGFloat

        if hasMessages {
            let compactHeight = resolvedCompactHeight()
            minHeight = max(
                MuseFloatingPanelSizing.minExpandedHeight,
                compactHeight + MuseFloatingPanelSizing.minExpandedDelta
            )
            maxHeight = MuseFloatingPanelSizing.maxExpandedHeight
        } else {
            minHeight = MuseFloatingPanelSizing.minCompactHeight
            maxHeight = MuseFloatingPanelSizing.maxCompactHeight
        }

        let minSize = CGSize(width: minWidth, height: minHeight)
        let maxSize = CGSize(width: maxWidth, height: maxHeight)
        contentMinSize = minSize
        contentMaxSize = maxSize

        if frame.width <= 0 || frame.height <= 0 {
            return
        }

        let clampedWidth = min(max(size.width, minWidth), maxWidth)
        let clampedHeight = min(max(size.height, minHeight), maxHeight)
        if abs(frame.width - clampedWidth) > 0.5 || abs(frame.height - clampedHeight) > 0.5 {
            let target = NSRect(
                x: frame.origin.x,
                y: frame.origin.y,
                width: clampedWidth,
                height: clampedHeight
            )
            applyFrame(target, animated: false, display: true)
        }
    }

    private func persistCurrentOriginIfNeeded(_ point: CGPoint) {
        guard Defaults[.museFloatingPanelRememberLastPosition] else { return }
        pendingPositionSaveWorkItem?.cancel()
        pendingPositionSaveWorkItem = nil
        savePosition(point)
    }

    private func scheduleCurrentOriginPersistenceIfNeeded(_ point: CGPoint, delay: TimeInterval = 0.12) {
        guard Defaults[.museFloatingPanelRememberLastPosition] else { return }
        pendingPositionSaveWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.savePosition(point)
        }
        pendingPositionSaveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func syncSizeDefaultsFromCurrentFrame() {
        guard frame.width > 0, frame.height > 0 else { return }

        let hasMessages = !(museManager.currentConversation?.messages.isEmpty ?? true)
        let clampedWidth = min(max(frame.width, MuseFloatingPanelSizing.minWidth), MuseFloatingPanelSizing.maxWidth)

        isSynchronizingSizeFromResize = true
        defer { isSynchronizingSizeFromResize = false }

        if abs(Defaults[.museFloatingPanelWidth] - clampedWidth) > 0.5 {
            Defaults[.museFloatingPanelWidth] = clampedWidth
        }

        if hasMessages {
            let compactHeight = min(
                max(Defaults[.museFloatingPanelCompactHeight], MuseFloatingPanelSizing.minCompactHeight),
                MuseFloatingPanelSizing.maxCompactHeight
            )
            let minExpanded = max(
                MuseFloatingPanelSizing.minExpandedHeight,
                compactHeight + MuseFloatingPanelSizing.minExpandedDelta
            )
            let clampedExpandedHeight = min(max(frame.height, minExpanded), MuseFloatingPanelSizing.maxExpandedHeight)
            if abs(Defaults[.museFloatingPanelExpandedHeight] - clampedExpandedHeight) > 0.5 {
                Defaults[.museFloatingPanelExpandedHeight] = clampedExpandedHeight
            }
        } else {
            let clampedCompactHeight = min(max(frame.height, MuseFloatingPanelSizing.minCompactHeight), MuseFloatingPanelSizing.maxCompactHeight)
            if abs(Defaults[.museFloatingPanelCompactHeight] - clampedCompactHeight) > 0.5 {
                Defaults[.museFloatingPanelCompactHeight] = clampedCompactHeight
            }

            let minimumExpanded = max(
                MuseFloatingPanelSizing.minExpandedHeight,
                clampedCompactHeight + MuseFloatingPanelSizing.minExpandedDelta
            )
            if Defaults[.museFloatingPanelExpandedHeight] < minimumExpanded {
                Defaults[.museFloatingPanelExpandedHeight] = minimumExpanded
            }
        }
    }

    private func savePosition(_ point: CGPoint) {
        UserDefaults.standard.set(point.x, forKey: positionXKey)
        UserDefaults.standard.set(point.y, forKey: positionYKey)
        UserDefaults.standard.set(true, forKey: positionSavedKey)
    }

    private func savedPosition() -> CGPoint? {
        guard UserDefaults.standard.bool(forKey: positionSavedKey) else { return nil }
        let x = UserDefaults.standard.double(forKey: positionXKey)
        let y = UserDefaults.standard.double(forKey: positionYKey)
        return CGPoint(x: x, y: y)
    }

    private func clearSavedPosition() {
        UserDefaults.standard.removeObject(forKey: positionXKey)
        UserDefaults.standard.removeObject(forKey: positionYKey)
        UserDefaults.standard.removeObject(forKey: positionSavedKey)
    }

    private func resolvedWidth() -> CGFloat {
        min(max(Defaults[.museFloatingPanelWidth], MuseFloatingPanelSizing.minWidth), MuseFloatingPanelSizing.maxWidth)
    }

    private func resolvedCompactHeight() -> CGFloat {
        min(max(Defaults[.museFloatingPanelCompactHeight], MuseFloatingPanelSizing.minCompactHeight), MuseFloatingPanelSizing.maxCompactHeight)
    }

    private func resolvedExpandedHeight(compactHeight: CGFloat) -> CGFloat {
        let minExpanded = max(MuseFloatingPanelSizing.minExpandedHeight, compactHeight + MuseFloatingPanelSizing.minExpandedDelta)
        return min(max(Defaults[.museFloatingPanelExpandedHeight], minExpanded), MuseFloatingPanelSizing.maxExpandedHeight)
    }

    private func resolvedEdgeInset() -> CGFloat {
        min(max(Defaults[.museFloatingPanelEdgeInset], MuseFloatingPanelSizing.minEdgeInset), MuseFloatingPanelSizing.maxEdgeInset)
    }

    private func resolvedFrame(for size: CGSize, forceDefaultPosition: Bool = false, preferredOrigin: CGPoint? = nil) -> NSRect {
        guard let screen = resolvedScreen() else {
            return NSRect(origin: .zero, size: size)
        }

        let visible = screen.visibleFrame
        let origin: CGPoint
        if let preferredOrigin {
            origin = clamped(origin: preferredOrigin, size: size, visibleFrame: visible)
        } else if forceDefaultPosition {
            origin = defaultOrigin(for: size, visibleFrame: visible)
        } else {
            origin = clamped(origin: frame.origin, size: size, visibleFrame: visible)
        }

        return NSRect(origin: origin, size: size)
    }

    private func resolvedScreen() -> NSScreen? {
        if let panelScreen = screen {
            return panelScreen
        }

        if frame.width > 0, frame.height > 0 {
            let mid = CGPoint(x: frame.midX, y: frame.midY)
            if let matched = NSScreen.screens.first(where: { $0.frame.contains(mid) }) {
                return matched
            }
        }

        return NSScreen.main ?? NSScreen.screens.first
    }

    private func defaultOrigin(for size: CGSize, visibleFrame: CGRect) -> CGPoint {
        let inset = resolvedEdgeInset()
        let leftX = visibleFrame.minX + inset
        let rightX = visibleFrame.maxX - size.width - inset
        let topY = visibleFrame.maxY - size.height - inset
        let centerY = visibleFrame.midY - size.height / 2
        let bottomY = visibleFrame.minY + inset

        switch Defaults[.museFloatingPanelDefaultPosition] {
        case .topLeft:
            return CGPoint(x: leftX, y: topY)
        case .topRight:
            return CGPoint(x: rightX, y: topY)
        case .centerLeft:
            return CGPoint(x: leftX, y: centerY)
        case .center:
            return CGPoint(x: visibleFrame.midX - size.width / 2, y: centerY)
        case .centerRight:
            return CGPoint(x: rightX, y: centerY)
        case .bottomLeft:
            return CGPoint(x: leftX, y: bottomY)
        case .bottomRight:
            return CGPoint(x: rightX, y: bottomY)
        }
    }

    private func clamped(origin: CGPoint, size: CGSize, visibleFrame: CGRect) -> CGPoint {
        let minX = visibleFrame.minX
        let maxX = visibleFrame.maxX - size.width
        let minY = visibleFrame.minY
        let maxY = visibleFrame.maxY - size.height

        return CGPoint(
            x: min(max(origin.x, minX), maxX),
            y: min(max(origin.y, minY), maxY)
        )
    }

    private func hasMeaningfulFrameChange(_ targetFrame: NSRect) -> Bool {
        abs(targetFrame.origin.x - frame.origin.x) > 0.5
            || abs(targetFrame.origin.y - frame.origin.y) > 0.5
            || abs(targetFrame.size.width - frame.size.width) > 0.5
            || abs(targetFrame.size.height - frame.size.height) > 0.5
    }

    var shouldDeferExternalLayoutRefresh: Bool {
        inLiveResize || isSynchronizingSizeFromResize
    }

    func windowDidMove(_ notification: Notification) {
        guard !isApplyingProgrammaticFrame else { return }
        guard !inLiveResize else { return }
        scheduleCurrentOriginPersistenceIfNeeded(frame.origin)
    }

    func windowDidResize(_ notification: Notification) {
        guard !isApplyingProgrammaticFrame else { return }
        if !inLiveResize {
            syncSizeDefaultsFromCurrentFrame()
        }
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        guard !isApplyingProgrammaticFrame else { return }
        syncSizeDefaultsFromCurrentFrame()
        persistCurrentOriginIfNeeded(frame.origin)
    }

    deinit {
        pendingPositionSaveWorkItem?.cancel()
        ScreenCaptureVisibilityManager.shared.unregister(self)
    }
}

struct MuseFloatingPanelView: View {
    @ObservedObject private var museManager = MuseManager.shared
    let onClose: () -> Void
    @State private var isNearResizeEdge = false

    var body: some View {
        let hasMessages = !(museManager.currentConversation?.messages.isEmpty ?? true)

        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "sailboat.fill")
                    .foregroundStyle(.cyan)
                Text("Notchi")
                    .font(.headline)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            if hasMessages, let conversation = museManager.currentConversation {
                Divider()
                MuseChatView(conversation: conversation) { prompt in
                    museManager.sendMessage(prompt)
                }
            }

            Divider()
            MuseInputBar(compact: !hasMessages)
        }
        .background(MusePanelVisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
        .overlay {
            MusePanelEdgeProximityTracker(edgeThreshold: 18, isNearEdge: $isNearResizeEdge)
        }
        .overlay(alignment: .bottomTrailing) {
            resizeHint()
                .opacity(isNearResizeEdge ? 1 : 0)
                .animation(.easeInOut(duration: 0.14), value: isNearResizeEdge)
        }
        .environment(\.colorScheme, .dark)
    }

    private func resizeHint() -> some View {
        Image(systemName: "arrow.up.left.and.arrow.down.right")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(8)
            .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(8)
            .allowsHitTesting(false)
    }
}

private struct MusePanelEdgeProximityTracker: NSViewRepresentable {
    let edgeThreshold: CGFloat
    @Binding var isNearEdge: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(isNearEdge: $isNearEdge)
    }

    func makeNSView(context: Context) -> MusePanelMouseTrackingView {
        let view = MusePanelMouseTrackingView()
        let coordinator = context.coordinator
        view.edgeThreshold = edgeThreshold
        view.onEdgeProximityChanged = { nearEdge in
            coordinator.setNearEdge(nearEdge)
        }
        return view
    }

    func updateNSView(_ nsView: MusePanelMouseTrackingView, context: Context) {
        let coordinator = context.coordinator
        nsView.edgeThreshold = edgeThreshold
        nsView.onEdgeProximityChanged = { nearEdge in
            coordinator.setNearEdge(nearEdge)
        }
    }

    final class Coordinator {
        private var isNearEdge: Binding<Bool>

        init(isNearEdge: Binding<Bool>) {
            self.isNearEdge = isNearEdge
        }

        func setNearEdge(_ nearEdge: Bool) {
            guard isNearEdge.wrappedValue != nearEdge else { return }
            isNearEdge.wrappedValue = nearEdge
        }
    }
}

private final class MusePanelMouseTrackingView: NSView {
    var edgeThreshold: CGFloat = 18
    var onEdgeProximityChanged: ((Bool) -> Void)?

    private var trackingAreaRef: NSTrackingArea?
    private var lastNearEdge = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingAreaRef {
            removeTrackingArea(trackingAreaRef)
        }

        let options: NSTrackingArea.Options = [
            .inVisibleRect,
            .activeAlways,
            .mouseMoved,
            .mouseEnteredAndExited
        ]
        let area = NSTrackingArea(rect: .zero, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingAreaRef = area
    }

    override func mouseEntered(with event: NSEvent) {
        updateEdgeProximity(using: event)
    }

    override func mouseMoved(with event: NSEvent) {
        updateEdgeProximity(using: event)
    }

    override func mouseExited(with event: NSEvent) {
        publishIfChanged(false)
    }

    private func updateEdgeProximity(using event: NSEvent) {
        guard bounds.width > 0, bounds.height > 0 else {
            publishIfChanged(false)
            return
        }

        let location = convert(event.locationInWindow, from: nil)
        let nearEdge = location.x <= edgeThreshold
            || location.x >= bounds.width - edgeThreshold
            || location.y <= edgeThreshold
            || location.y >= bounds.height - edgeThreshold
        publishIfChanged(nearEdge)
    }

    private func publishIfChanged(_ nearEdge: Bool) {
        guard nearEdge != lastNearEdge else { return }
        lastNearEdge = nearEdge
        onEdgeProximityChanged?(nearEdge)
    }
}

struct MusePanelVisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

@MainActor
final class MuseFloatingPanelManager: ObservableObject {
    static let shared = MuseFloatingPanelManager()

    private var panel: MuseFloatingPanel?
    private var cancellables = Set<AnyCancellable>()

    private init() {
        MuseManager.shared.$conversations
            .sink { [weak self] _ in
                self?.refreshPanelLayout(animated: true)
            }
            .store(in: &cancellables)

        Defaults.publisher(.museFloatingPanelWidth)
            .sink { [weak self] _ in
                self?.refreshPanelLayout(animated: false)
            }
            .store(in: &cancellables)

        Defaults.publisher(.museFloatingPanelCompactHeight)
            .sink { [weak self] _ in
                self?.refreshPanelLayout(animated: false)
            }
            .store(in: &cancellables)

        Defaults.publisher(.museFloatingPanelExpandedHeight)
            .sink { [weak self] _ in
                self?.refreshPanelLayout(animated: false)
            }
            .store(in: &cancellables)

        Defaults.publisher(.museFloatingPanelEdgeInset)
            .sink { [weak self] _ in
                guard Defaults[.museFloatingPanelRememberLastPosition] == false else { return }
                self?.refreshPanelLayout(animated: true)
            }
            .store(in: &cancellables)

        Defaults.publisher(.museFloatingPanelDefaultPosition)
            .sink { [weak self] _ in
                guard Defaults[.museFloatingPanelRememberLastPosition] == false else { return }
                self?.refreshPanelLayout(animated: true)
            }
            .store(in: &cancellables)

        Defaults.publisher(.museFloatingPanelRememberLastPosition)
            .sink { [weak self] change in
                guard let panel = self?.panel else { return }
                if change.newValue == false {
                    panel.invalidateSavedPosition()
                }
                panel.positionDefaultIfNeeded()
                self?.refreshPanelLayout(animated: true)
            }
            .store(in: &cancellables)
    }

    func showPanel() {
        hidePanel()

        let panel = MuseFloatingPanel()
        panel.positionDefaultIfNeeded()
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()

        self.panel = panel
    }

    func hidePanel() {
        panel?.close()
        panel = nil
    }

    func togglePanel() {
        if isPanelVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    var isPanelVisible: Bool {
        panel?.isVisible == true
    }

    private func refreshPanelLayout(animated: Bool) {
        guard let panel else { return }
        guard !panel.shouldDeferExternalLayoutRefresh else { return }
        panel.refreshLayout(animated: animated)
    }
}

