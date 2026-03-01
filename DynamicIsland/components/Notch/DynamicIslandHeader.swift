/*
 * Atoll (DynamicIsland)
 * Copyright (C) 2024-2026 Atoll Contributors
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
                        HeaderIconButton(systemImage: "gear", helpText: "Settings") {
                            SettingsWindowController.shared.showWindow()
                        }
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
