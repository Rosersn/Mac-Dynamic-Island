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
import Defaults
import SwiftUI

struct DynamicIslandHeader: View {
    @EnvironmentObject var vm: DynamicIslandViewModel
    @EnvironmentObject var webcamManager: WebcamManager
    @ObservedObject var batteryModel = BatteryStatusViewModel.shared
    @ObservedObject var coordinator = DynamicIslandViewCoordinator.shared
    @ObservedObject var clipboardManager = ClipboardManager.shared
    @ObservedObject var shelfState = ShelfStateViewModel.shared
    @ObservedObject var timerManager = TimerManager.shared
    @ObservedObject var doNotDisturbManager = DoNotDisturbManager.shared
    @State private var showClipboardPopover = false
    @State private var showColorPickerPopover = false
    @State private var showTimerPopover = false
    @Default(.enableTimerFeature) var enableTimerFeature
    @Default(.timerDisplayMode) var timerDisplayMode
    @Default(.showClipboardIcon) var showClipboardIcon
    @Default(.clipboardDisplayMode) var clipboardDisplayMode
    
    var body: some View {
        HStack(spacing: 0) {
            if !Defaults[.enableMinimalisticUI] {
                HStack {
                    let shouldShowTabs = coordinator.alwaysShowTabs || vm.notchState == .open || !shelfState.items.isEmpty
                    if shouldShowTabs {
                        TabSelectionView()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .clipped()
                .opacity(vm.notchState == .closed ? 0 : 1)
                .blur(radius: vm.notchState == .closed ? 20 : 0)
                .animation(.smooth.delay(0.1), value: vm.notchState)
                .zIndex(2)
            }

            if vm.notchState == .open && !Defaults[.enableMinimalisticUI] {
                Rectangle()
                    .fill(NSScreen.screens
                        .first(where: { $0.localizedName == coordinator.selectedScreen })?.safeAreaInsets.top ?? 0 > 0 ? .black : .clear)
                    .frame(width: vm.closedNotchSize.width)
                    .mask {
                        NotchShape()
                    }
            }

            HStack(spacing: 4) {
                if vm.notchState == .open && !Defaults[.enableMinimalisticUI] {
                    if Defaults[.showMirror] {
                        HeaderIconButton(systemImage: "web.camera", helpText: "Mirror") {
                            vm.toggleCameraPreview()
                        }
                    }
                    
                    if Defaults[.enableClipboardManager]
                        && showClipboardIcon
                        && clipboardDisplayMode != .separateTab {
                        HeaderIconButton(systemImage: "doc.on.clipboard", helpText: "Clipboard") {
                            // Switch behavior based on display mode
                            switch clipboardDisplayMode {
                            case .panel:
                                ClipboardPanelManager.shared.toggleClipboardPanel()
                            case .popover:
                                showClipboardPopover.toggle()
                            case .separateTab:
                                coordinator.currentView = .notes
                            }
                        }
                        .popover(isPresented: $showClipboardPopover, arrowEdge: .bottom) {
                            ClipboardPopover()
                        }
                        .onChange(of: showClipboardPopover) { isActive in
                            vm.isClipboardPopoverActive = isActive
                            
                            // If popover was closed, trigger a hover recheck
                            if !isActive {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    vm.shouldRecheckHover.toggle()
                                }
                            }
                        }
                        .onAppear {
                            if Defaults[.enableClipboardManager] && !clipboardManager.isMonitoring {
                                clipboardManager.startMonitoring()
                            }
                        }
                    }
                    
                    // ColorPicker button
                    if Defaults[.enableColorPickerFeature] {
                        HeaderIconButton(systemImage: "eyedropper", helpText: "Color Picker") {
                            switch Defaults[.colorPickerDisplayMode] {
                            case .panel:
                                ColorPickerPanelManager.shared.toggleColorPickerPanel()
                            case .popover:
                                showColorPickerPopover.toggle()
                            }
                        }
                        .popover(isPresented: $showColorPickerPopover, arrowEdge: .bottom) {
                            ColorPickerPopover()
                        }
                        .onChange(of: showColorPickerPopover) { isActive in
                            vm.isColorPickerPopoverActive = isActive
                            
                            // If popover was closed, trigger a hover recheck
                            if !isActive {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    vm.shouldRecheckHover.toggle()
                                }
                            }
                        }
                    }
                    
                    if Defaults[.enableTimerFeature] && timerDisplayMode == .popover {
                        HeaderIconButton(systemImage: "timer", helpText: "Timer") {
                            withAnimation(.smooth) {
                                showTimerPopover.toggle()
                            }
                        }
                        .popover(isPresented: $showTimerPopover, arrowEdge: .bottom) {
                            TimerPopover()
                        }
                        .onChange(of: showTimerPopover) { isActive in
                            vm.isTimerPopoverActive = isActive
                            if !isActive {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    vm.shouldRecheckHover.toggle()
                                }
                            }
                        }
                    }
                    
                    if Defaults[.settingsIconInNotch] {
                        HeaderSettingsMenuButton(
                            onOpenSettings: {
                                SettingsWindowController.shared.showWindow()
                            },
                            onOpenFeedback: {
                                HeaderFeedbackPanelController.shared.showWindow()
                            },
                            onQuitApp: {
                                NSApp.terminate(nil)
                            }
                        )
                    }
                    
                    // Screen Recording Indicator
                    if Defaults[.enableScreenRecordingDetection] && Defaults[.showRecordingIndicator] && !shouldSuppressStatusIndicators {
                        RecordingIndicator()
                            .frame(width: 30, height: 30) // Same size as other header elements
                    }

                    if Defaults[.enableDoNotDisturbDetection]
                        && Defaults[.showDoNotDisturbIndicator]
                        && doNotDisturbManager.isDoNotDisturbActive
                        && !shouldSuppressStatusIndicators {
                        FocusIndicator()
                            .frame(width: 30, height: 30)
                            .transition(.opacity)
                    }
                    


                    if Defaults[.showBatteryIndicator] {
                        DynamicIslandBatteryView(
                            batteryWidth: 30,
                            isCharging: batteryModel.isCharging,
                            isInLowPowerMode: batteryModel.isInLowPowerMode,
                            isPluggedIn: batteryModel.isPluggedIn,
                            levelBattery: batteryModel.levelBattery,
                            maxCapacity: batteryModel.maxCapacity,
                            timeToFullCharge: batteryModel.timeToFullCharge,
                            isForNotification: false
                        )
                    }
                }
            }
            .font(.system(.headline, design: .rounded))
            .frame(maxWidth: .infinity, alignment: .trailing)
            .opacity(vm.notchState == .closed ? 0 : 1)
            .blur(radius: vm.notchState == .closed ? 20 : 0)
            .animation(.smooth.delay(0.1), value: vm.notchState)
            .zIndex(2)
        }
        .foregroundColor(.gray)
        .environmentObject(vm)
        .onChange(of: coordinator.shouldToggleClipboardPopover) { _ in
            // Only toggle if clipboard is enabled
            if Defaults[.enableClipboardManager] {
                switch clipboardDisplayMode {
                case .panel:
                    ClipboardPanelManager.shared.toggleClipboardPanel()
                case .popover:
                    showClipboardPopover.toggle()
                case .separateTab:
                    if coordinator.currentView == .notes {
                        coordinator.currentView = .home
                    } else {
                        coordinator.currentView = .notes
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ToggleClipboardPopover"))) { _ in
            // Handle keyboard shortcut for popover mode
            if Defaults[.enableClipboardManager] && clipboardDisplayMode == .popover {
                showClipboardPopover.toggle()
            }
        }
        .onChange(of: enableTimerFeature) { _, newValue in
            if !newValue {
                showTimerPopover = false
                vm.isTimerPopoverActive = false
            }
        }
        .onChange(of: timerDisplayMode) { _, mode in
            if mode == .tab {
                showTimerPopover = false
                vm.isTimerPopoverActive = false
            }
        }
    }
}

private struct HeaderIconButton: View {
    let systemImage: String
    let helpText: String
    let action: () -> Void
    @Default(.enableHaptics) private var enableHaptics
    @State private var isHovering = false
    @State private var lastHoverHapticTime = Date.distantPast

    var body: some View {
        Button(action: action) {
            Capsule()
                .fill(isHovering ? Color.white.opacity(0.14) : .black)
                .frame(width: 30, height: 30)
                .overlay {
                    Capsule()
                        .stroke(Color.white.opacity(isHovering ? 0.32 : 0.12), lineWidth: 1)
                }
                .overlay {
                    Image(systemName: systemImage)
                        .foregroundColor(.white)
                        .imageScale(.medium)
                        .scaleEffect(isHovering ? 1.08 : 1.0)
                }
                .shadow(color: Color.white.opacity(isHovering ? 0.2 : 0), radius: 8, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
        .help(helpText)
        .onHover { hovering in
            isHovering = hovering
            triggerHoverHapticIfNeeded(hovering)
        }
        .animation(.easeOut(duration: 0.16), value: isHovering)
    }

    private func triggerHoverHapticIfNeeded(_ hovering: Bool) {
        guard hovering, enableHaptics else { return }
        let now = Date()
        guard now.timeIntervalSince(lastHoverHapticTime) > 0.22 else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
        lastHoverHapticTime = now
    }
}

private struct HeaderSettingsMenuButton: View {
    let onOpenSettings: () -> Void
    let onOpenFeedback: () -> Void
    let onQuitApp: () -> Void
    @Default(.enableHaptics) private var enableHaptics
    @State private var isHovering = false
    @State private var lastHoverHapticTime = Date.distantPast

    var body: some View {
        Menu {
            Button("打开设置", action: onOpenSettings)
            Button("问题反馈", action: onOpenFeedback)
            Button("退出 APP", action: onQuitApp)
        } label: {
            Capsule()
                .fill(isHovering ? Color.white.opacity(0.14) : .black)
                .frame(width: 30, height: 30)
                .overlay {
                    Capsule()
                        .stroke(Color.white.opacity(isHovering ? 0.32 : 0.12), lineWidth: 1)
                }
                .overlay {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(.white)
                        .scaleEffect(isHovering ? 1.08 : 1.0)
                }
                .shadow(color: Color.white.opacity(isHovering ? 0.2 : 0), radius: 8, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
        .help("Settings")
        .onHover { hovering in
            isHovering = hovering
            triggerHoverHapticIfNeeded(hovering)
        }
        .animation(.easeOut(duration: 0.16), value: isHovering)
    }

    private func triggerHoverHapticIfNeeded(_ hovering: Bool) {
        guard hovering, enableHaptics else { return }
        let now = Date()
        guard now.timeIntervalSince(lastHoverHapticTime) > 0.22 else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
        lastHoverHapticTime = now
    }
}

@MainActor
private final class HeaderFeedbackPanelController {
    static let shared = HeaderFeedbackPanelController()
    private var panel: HeaderFeedbackPanel?

    private init() {}

    func showWindow() {
        if panel == nil {
            panel = HeaderFeedbackPanel {
                HeaderFeedbackPanelController.shared.hideWindow()
            }
        }

        guard let panel else { return }

        positionWindow(panel)
        NSApp.activate(ignoringOtherApps: true)
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)
    }

    func hideWindow() {
        panel?.orderOut(nil)
    }

    private func positionWindow(_ panel: NSPanel) {
        guard let screen = NSScreen.main else {
            panel.center()
            return
        }
        let visibleFrame = screen.visibleFrame
        let panelSize = panel.frame.size
        let origin = NSPoint(
            x: visibleFrame.midX - panelSize.width / 2,
            y: visibleFrame.midY - panelSize.height / 2
        )
        panel.setFrameOrigin(origin)
    }
}

private final class HeaderFeedbackPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    init(onClose: @escaping () -> Void) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 560),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        setupWindow()
        setupContentView(onClose: onClose)
    }

    private func setupWindow() {
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        level = .floating
        isMovableByWindowBackground = true
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        isFloatingPanel = true
        hidesOnDeactivate = false
        styleMask.insert(.fullSizeContentView)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        ScreenCaptureVisibilityManager.shared.register(self, scope: .panelsOnly)
    }

    private func setupContentView(onClose: @escaping () -> Void) {
        let rootView = HeaderFeedbackDialogView(onClose: onClose)
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.wantsLayer = true
        hostingView.layer?.masksToBounds = true
        hostingView.layer?.cornerRadius = 28
        if #available(macOS 13.0, *) {
            hostingView.layer?.cornerCurve = .continuous
        }
        contentView = hostingView
        setContentSize(CGSize(width: 760, height: 560))
    }

    deinit {
        ScreenCaptureVisibilityManager.shared.unregister(self)
    }
}

private struct HeaderFeedbackDialogView: View {
    let onClose: () -> Void
    private let supportEmail = "yxzsn1314@gmail.com"
    @State private var copiedEmail = false

    var body: some View {
        VStack(spacing: 0) {
            topBanner
            feedbackCard
            Spacer(minLength: 16)
            actionButtons
        }
        .frame(width: 760, height: 560)
        .padding(.horizontal, 26)
        .padding(.top, 22)
        .padding(.bottom, 20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(nsColor: NSColor(calibratedWhite: 0.93, alpha: 1)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }

    private var topBanner: some View {
        HStack(alignment: .top) {
            Text("Hello")
                .font(.system(size: 96, weight: .bold, design: .rounded))
                .foregroundStyle(Color.black.opacity(0.66))

            Spacer(minLength: 20)

            ZStack {
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.28),
                                Color.purple.opacity(0.18)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 200, height: 160)

                Image(systemName: "person.crop.circle.fill.badge.questionmark")
                    .font(.system(size: 84, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.95))
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 2)
    }

    private var feedbackCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("问题反馈")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.8))
                Text("Problem Feedback.")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.5))
            }

            Text("您好，非常感谢您选择并使用我们的软件，您的支持与厚爱是我们不断进步的最大动力。使用过程中，如果您遇到任何问题，发现任何不便，或有任何改进建议，都非常欢迎您随时反馈给我们。您的每一条意见都至关重要，我们将认真核查并尽快优化。我们将竭诚为您提供更好的体验与服务！谢谢您！")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.66))
                .lineSpacing(7)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                Text("技术支持的Email：")
                Text(supportEmail)
                    .fontWeight(.semibold)
            }
            .font(.system(size: 28, weight: .medium))
            .foregroundStyle(Color.black.opacity(0.84))

            if copiedEmail {
                Text("邮箱已复制，可粘贴到任意邮箱客户端发送反馈。")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color(nsColor: .systemGreen))
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 22)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.36))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.75), lineWidth: 1)
        )
    }

    private var actionButtons: some View {
        HStack(spacing: 18) {
            Button("关闭") {
                onClose()
            }
            .buttonStyle(
                FeedbackDialogActionButtonStyle(
                    foreground: Color.black.opacity(0.72),
                    background: Color.white.opacity(0.56),
                    border: Color.black.opacity(0.08),
                    borderWidth: 1
                )
            )

            Button("发送邮件") {
                copyEmailToPasteboard()
            }
            .buttonStyle(
                FeedbackDialogActionButtonStyle(
                    foreground: .white,
                    background: Color(nsColor: .systemBlue),
                    border: .clear,
                    borderWidth: 0
                )
            )
        }
    }

    private func copyEmailToPasteboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(supportEmail, forType: .string)
        withAnimation(.easeInOut(duration: 0.2)) {
            copiedEmail = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeInOut(duration: 0.2)) {
                copiedEmail = false
            }
        }
    }
}

private struct FeedbackDialogActionButtonStyle: ButtonStyle {
    let foreground: Color
    let background: Color
    let border: Color
    let borderWidth: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(foreground.opacity(configuration.isPressed ? 0.86 : 1))
            .frame(width: 210, height: 58)
            .background(
                RoundedRectangle(cornerRadius: 29, style: .continuous)
                    .fill(background.opacity(configuration.isPressed ? 0.86 : 1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 29, style: .continuous)
                    .stroke(border, lineWidth: borderWidth)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private extension DynamicIslandHeader {
    var shouldSuppressStatusIndicators: Bool {
        Defaults[.settingsIconInNotch]
            && Defaults[.enableClipboardManager]
            && Defaults[.showClipboardIcon]
            && Defaults[.enableColorPickerFeature]
            && Defaults[.enableTimerFeature]
    }
}

#Preview {
    DynamicIslandHeader()
        .environmentObject(DynamicIslandViewModel())
        .environmentObject(WebcamManager.shared)
}
