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

struct MuseChatView: View {
    let conversation: MuseConversation
    let onPromptTap: (String) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if conversation.messages.isEmpty {
                        MuseWelcomeView(onPromptTap: onPromptTap)
                            .id("welcome")
                    } else {
                        ForEach(conversation.messages) { message in
                            MuseChatBubble(message: message)
                                .id(message.id)
                        }
                    }
                }
                .padding(12)
            }
            .onAppear {
                scrollToBottom(proxy)
            }
            .onChange(of: conversation.messages.count) { _, _ in
                scrollToBottom(proxy)
            }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            if let lastID = conversation.messages.last?.id {
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(lastID, anchor: .bottom)
                }
            } else {
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("welcome", anchor: .top)
                }
            }
        }
    }
}

