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

import SwiftUI

struct MuseChatBubble: View {
    let message: MuseMessage

    @State private var showThinking = false

    private var isUser: Bool { message.role == .user }
    private var isToolMessage: Bool { message.role == .tool }
    private var isSystemMessage: Bool { message.role == .system }

    var body: some View {
        if isSystemMessage {
            Text(message.content)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.72))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
        } else {
        HStack(alignment: .top, spacing: 10) {
            if isUser {
                Spacer(minLength: 40)
            } else {
                avatar
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 8) {
                header

                if let thinking = message.thinkingContent, !thinking.isEmpty {
                    thinkingView(thinking)
                }

                if let calls = message.toolCalls, !calls.isEmpty {
                    toolCallsView(calls)
                }

                if !message.content.isEmpty || (!isToolMessage && message.state == .sending) {
                    contentView
                }

                if let error = message.errorMessage, !error.isEmpty {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .frame(maxWidth: 480, alignment: isUser ? .trailing : .leading)

            if !isUser {
                Spacer(minLength: 40)
            }
        }
        }
    }

    private var avatar: some View {
        Image(systemName: isToolMessage ? "wrench.and.screwdriver.fill" : "sailboat.fill")
            .font(.subheadline)
            .foregroundStyle(isToolMessage ? .orange : .cyan)
            .frame(width: 28, height: 28)
            .background((isToolMessage ? Color.orange : Color.cyan).opacity(0.15))
            .clipShape(Circle())
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text(senderLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(senderColor)

            Text(message.timestamp, style: .time)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.65))

            if message.state == .thinking {
                Text("Thinking")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.65))
            } else if message.state == .streaming {
                Text("Streaming")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.65))
            } else if message.state == .toolCalling {
                Text("Tool Running")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.65))
            } else if message.state == .stopped {
                Text("Stopped")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.65))
            }
        }
    }

    @ViewBuilder
    private func thinkingView(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    showThinking.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: showThinking ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                    Text("Thinking")
                        .font(.caption)
                    Spacer()
                }
            }
            .buttonStyle(.plain)

            if showThinking {
                MuseMarkdownText(content: text)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.72))
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(8)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func toolCallsView(_ calls: [MuseToolCall]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(calls) { call in
                HStack(spacing: 8) {
                    Image(systemName: icon(for: call.state))
                        .font(.caption)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(call.name)
                            .font(.caption.weight(.semibold))
                        if !call.arguments.isEmpty {
                            Text(call.arguments)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.72))
                                .lineLimit(2)
                        }
                        if let result = call.result, !result.isEmpty {
                            Text(result)
                                .font(.caption2)
                                .foregroundStyle(call.state == .error ? .red : .white.opacity(0.72))
                                .lineLimit(3)
                        }
                    }
                    Spacer()
                }
                .padding(8)
                .background(Color.white.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        if message.state == .sending && message.content.isEmpty {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Sending...")
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.16))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            MuseMarkdownText(content: message.content)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .foregroundStyle(isUser ? .white : .white.opacity(0.94))
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            isUser
                                ? Color.blue
                                : (isToolMessage ? Color.orange.opacity(0.26) : Color.white.opacity(0.18))
                        )
                )
        }
    }

    private func icon(for state: MuseToolCallState) -> String {
        switch state {
        case .calling:
            return "ellipsis.circle"
        case .success:
            return "checkmark.circle"
        case .error:
            return "xmark.octagon"
        }
    }

    private var senderLabel: String {
        switch message.role {
        case .user:
            return "You"
        case .assistant:
            return "Notchi"
        case .tool:
            return "Tool"
        case .system:
            return "System"
        }
    }

    private var senderColor: Color {
        switch message.role {
        case .user:
            return .blue
        case .assistant:
            return .mint
        case .tool:
            return .orange
        case .system:
            return .secondary
        }
    }
}

struct MuseMarkdownText: View {
    let content: String

    var body: some View {
        if let attributed = try? AttributedString(markdown: content) {
            Text(attributed)
        } else {
            Text(content)
        }
    }
}

