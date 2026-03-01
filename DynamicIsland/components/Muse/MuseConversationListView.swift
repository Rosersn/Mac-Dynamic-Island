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

import SwiftUI

struct MuseConversationListView: View {
    @ObservedObject private var museManager = MuseManager.shared

    @Binding var isCollapsed: Bool

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(museManager.conversations) { conversation in
                        conversationRow(conversation)
                    }
                }
                .padding(8)
            }
        }
        .background(Color.white.opacity(0.03))
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("History")
                .font(.headline)
            Spacer()
            Button {
                museManager.createConversation()
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.plain)
            .help("New conversation")

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isCollapsed.toggle()
                }
            } label: {
                Image(systemName: "sidebar.left")
            }
            .buttonStyle(.plain)
            .help("Collapse sidebar")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func conversationRow(_ conversation: MuseConversation) -> some View {
        let isSelected = museManager.currentConversationID == conversation.id

        return HStack(spacing: 8) {
            Button {
                museManager.selectConversation(conversation.id)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(conversation.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(conversation.previewText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button {
                museManager.deleteConversation(conversation.id)
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .help("Delete conversation")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(isSelected ? Color.blue.opacity(0.2) : Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

