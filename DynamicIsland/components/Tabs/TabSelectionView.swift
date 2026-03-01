/*
 * Atoll (DynamicIsland)
 * Copyright (C) 2024-2026 Atoll Contributors
 *
 * Originally from boring.notch project
 * Modified and adapted for Atoll (DynamicIsland)
 * See NOTICE for details.
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

import AtollExtensionKit
import SwiftUI
import Defaults

struct TabModel: Identifiable {
    let id: String
    let label: String
    let icon: String
    let view: NotchViews
    let experienceID: String?
    let accentColor: Color?

    init(label: String, icon: String, view: NotchViews, experienceID: String? = nil, accentColor: Color? = nil) {
        self.id = experienceID.map { "extension-\($0)" } ?? "system-\(view)-\(label)"
        self.label = label
        self.icon = icon
        self.view = view
        self.experienceID = experienceID
        self.accentColor = accentColor
    }
}

struct TabSelectionView: View {
    @EnvironmentObject var vm: DynamicIslandViewModel
    @ObservedObject var coordinator = DynamicIslandViewCoordinator.shared
    @ObservedObject private var extensionNotchExperienceManager = ExtensionNotchExperienceManager.shared
    @Default(.enableTimerFeature) var enableTimerFeature
    @Default(.enableStatsFeature) var enableStatsFeature
    @Default(.enableColorPickerFeature) var enableColorPickerFeature
    @Default(.enableMuse) var enableMuse
    @Default(.timerDisplayMode) var timerDisplayMode
    @Default(.enableThirdPartyExtensions) private var enableThirdPartyExtensions
    @Default(.enableExtensionNotchExperiences) private var enableExtensionNotchExperiences
    @Default(.enableExtensionNotchTabs) private var enableExtensionNotchTabs
    @Default(.showCalendar) private var showCalendar
    @Default(.showMirror) private var showMirror
    @Default(.showStandardMediaControls) private var showStandardMediaControls
    @Default(.enableMinimalisticUI) private var enableMinimalisticUI
    @Namespace var animation
    @State private var tabSwitchAutoCloseToken = UUID()
    @State private var tabSwitchAutoCloseReleaseWorkItem: DispatchWorkItem?
    @State private var tabSwitchAutoCloseSuppressed = false
    @State private var scrollGestureSuppressionToken = UUID()
    @State private var isSuppressingScrollGestures = false
    
    private var tabs: [TabModel] {
        var tabsArray: [TabModel] = []

        if homeTabVisible {
            tabsArray.append(TabModel(label: "Home", icon: "house.fill", view: .home))
        }

        if enableMuse {
            tabsArray.append(TabModel(label: "Muse", icon: "sailboat.fill", view: .muse))
        }

        if Defaults[.dynamicShelf] {
            tabsArray.append(TabModel(label: "Shelf", icon: "tray.fill", view: .shelf))
        }
        
        if enableTimerFeature && timerDisplayMode == .tab {
            tabsArray.append(TabModel(label: "Timer", icon: "timer", view: .timer))
        }

        // Stats tab only shown when stats feature is enabled
        if Defaults[.enableStatsFeature] {
            tabsArray.append(TabModel(label: "Stats", icon: "chart.xyaxis.line", view: .stats))
        }

        if Defaults[.enableNotes] || (Defaults[.enableClipboardManager] && Defaults[.clipboardDisplayMode] == .separateTab) {
            let label = Defaults[.enableNotes] ? "Notes" : "Clipboard"
            let icon = Defaults[.enableNotes] ? "note.text" : "doc.on.clipboard"
            tabsArray.append(TabModel(label: label, icon: icon, view: .notes))
        }
        if extensionTabsEnabled {
            for payload in extensionTabPayloads {
                guard let tab = payload.descriptor.tab else { continue }
                let accent = payload.descriptor.accentColor.swiftUIColor
                let iconName = tab.iconSymbolName ?? "puzzlepiece.extension"
                tabsArray.append(
                    TabModel(
                        label: tab.title,
                        icon: iconName,
                        view: .extensionExperience,
                        experienceID: payload.descriptor.id,
                        accentColor: accent
                    )
                )
            }
        }
        DispatchQueue.main.async {
            ensureValidSelection(with: tabsArray)
        }
        return tabsArray
    }
    var body: some View {
        let currentTabs = tabs
        let horizontalPadding = tabHorizontalPadding(for: currentTabs.count)

        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(currentTabs) { tab in
                        let isSelected = isSelected(tab)
                        let activeAccent = tab.accentColor ?? .white
                        TabButton(
                            label: tab.label,
                            icon: tab.icon,
                            selected: isSelected,
                            horizontalPadding: horizontalPadding
                        ) {
                            guard !isSelected else { return }
                            suppressAutoCloseDuringTabSwitch()
                            withAnimation(.smooth) {
                                if tab.view == .extensionExperience {
                                    coordinator.selectedExtensionExperienceID = tab.experienceID
                                }
                                coordinator.currentView = tab.view
                            }
                        }
                        .frame(height: 26)
                        .foregroundStyle(isSelected ? activeAccent : .gray)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill((tab.accentColor ?? Color(nsColor: .secondarySystemFill)).opacity(0.25))
                                    .shadow(color: (tab.accentColor ?? .clear).opacity(0.4), radius: 8)
                                    .matchedGeometryEffect(id: "capsule", in: animation)
                            } else {
                                Capsule()
                                    .fill(Color.clear)
                                    .matchedGeometryEffect(id: "capsule", in: animation)
                                    .hidden()
                            }
                        }
                        .id(tab.id)
                    }
                }
            }
            .clipped()
            .onAppear {
                scrollToCurrentSelection(using: proxy, animated: false)
            }
            .onChange(of: coordinator.currentView) { _, _ in
                scrollToCurrentSelection(using: proxy)
            }
            .onChange(of: coordinator.selectedExtensionExperienceID) { _, _ in
                scrollToCurrentSelection(using: proxy)
            }
            .onChange(of: currentTabs.map(\.id)) { _, _ in
                scrollToCurrentSelection(using: proxy, animated: false)
            }
        }
        .clipShape(Capsule())
        .onHover { hovering in
            updateScrollGestureSuppression(for: hovering)
        }
        .onDisappear {
            updateScrollGestureSuppression(for: false)
            releaseTabSwitchAutoCloseSuppression()
        }
    }

    private var extensionTabsEnabled: Bool {
        enableThirdPartyExtensions && enableExtensionNotchExperiences && enableExtensionNotchTabs
    }

    private var extensionTabPayloads: [ExtensionNotchExperiencePayload] {
        extensionNotchExperienceManager.activeExperiences.filter { $0.descriptor.tab != nil }
    }

    private var homeTabVisible: Bool {
        if enableMinimalisticUI {
            return true
        }
        return showStandardMediaControls || showCalendar || showMirror
    }

    private func isSelected(_ tab: TabModel) -> Bool {
        if tab.view == .extensionExperience {
            return coordinator.currentView == .extensionExperience
                && coordinator.selectedExtensionExperienceID == tab.experienceID
        }
        return coordinator.currentView == tab.view
    }

    private func ensureValidSelection(with tabs: [TabModel]) {
        guard !tabs.isEmpty else { return }
        if tabs.contains(where: { isSelected($0) }) {
            return
        }
        guard let first = tabs.first else { return }
        if first.view == .extensionExperience {
            coordinator.selectedExtensionExperienceID = first.experienceID
        } else {
            coordinator.selectedExtensionExperienceID = nil
        }
        coordinator.currentView = first.view
    }

    private func suppressAutoCloseDuringTabSwitch() {
        tabSwitchAutoCloseReleaseWorkItem?.cancel()
        tabSwitchAutoCloseReleaseWorkItem = nil

        if !tabSwitchAutoCloseSuppressed {
            vm.setAutoCloseSuppression(true, token: tabSwitchAutoCloseToken)
            tabSwitchAutoCloseSuppressed = true
        }

        let releaseWorkItem = DispatchWorkItem {
            releaseTabSwitchAutoCloseSuppression()
        }
        tabSwitchAutoCloseReleaseWorkItem = releaseWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: releaseWorkItem)
    }

    private func releaseTabSwitchAutoCloseSuppression() {
        tabSwitchAutoCloseReleaseWorkItem?.cancel()
        tabSwitchAutoCloseReleaseWorkItem = nil

        guard tabSwitchAutoCloseSuppressed else { return }
        vm.setAutoCloseSuppression(false, token: tabSwitchAutoCloseToken)
        tabSwitchAutoCloseSuppressed = false
    }

    private func tabHorizontalPadding(for tabCount: Int) -> CGFloat {
        switch tabCount {
        case ...4:
            return 15
        case 5...6:
            return 12
        default:
            return 10
        }
    }

    private func scrollToCurrentSelection(using proxy: ScrollViewProxy, animated: Bool = true) {
        guard let selectedTab = tabs.first(where: isSelected) else { return }
        let targetID = selectedTab.id

        DispatchQueue.main.async {
            if animated {
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(targetID, anchor: .center)
                }
            } else {
                proxy.scrollTo(targetID, anchor: .center)
            }
        }
    }

    private func updateScrollGestureSuppression(for active: Bool) {
        guard active != isSuppressingScrollGestures else { return }
        isSuppressingScrollGestures = active
        vm.setScrollGestureSuppression(active, token: scrollGestureSuppressionToken)
    }
}

#Preview {
    DynamicIslandHeader().environmentObject(DynamicIslandViewModel())
}
