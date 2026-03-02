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

import Defaults
import SwiftUI

struct NotchMuseView: View {
    @ObservedObject private var museManager = MuseManager.shared
    @Default(.museSidebarCollapsed) private var isSidebarCollapsed
    @Default(.selectedAIProvider) private var selectedProvider
    @Default(.selectedAIModel) private var selectedModel

    var body: some View {
        HStack(spacing: 0) {
            if !isSidebarCollapsed {
                MuseConversationListView(isCollapsed: $isSidebarCollapsed)
                    .frame(width: 220)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }

            VStack(spacing: 0) {
                header

                Divider()

                if let conversation = museManager.currentConversation {
                    MuseChatView(conversation: conversation) { prompt in
                        museManager.sendMessage(prompt)
                    }
                } else {
                    MuseWelcomeView { prompt in
                        museManager.sendMessage(prompt)
                    }
                    Spacer()
                }

                Divider()

                MuseInputBar()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .animation(.easeInOut(duration: 0.2), value: isSidebarCollapsed)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.colorScheme, .dark)
    }

    private var header: some View {
        HStack(spacing: 10) {
            if isSidebarCollapsed {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isSidebarCollapsed = false
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                }
                .buttonStyle(.plain)
            }

            Image(systemName: "sailboat.fill")
                .foregroundStyle(.cyan)
            Text("Notchi")
                .font(.headline)

            Spacer()

            HStack(spacing: 5) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 7, height: 7)
                Text("Online")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("\(selectedProvider.displayName) • \(selectedModel?.name ?? selectedProvider.supportedModels.first?.name ?? "Model")")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Double Option or Option+Space")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.06))
    }
}

