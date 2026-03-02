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
import SwiftUI

struct MuseInputBar: View {
    @ObservedObject private var museManager = MuseManager.shared
    @State private var messageText: String = ""
    @FocusState private var isInputFocused: Bool

    var compact: Bool = false
    var onSend: ((String) -> Void)? = nil

    var body: some View {
        VStack(spacing: 8) {
            MuseModelSelector()
                .frame(maxWidth: .infinity, alignment: .leading)

            if !museManager.attachedFiles.isEmpty {
                attachmentsRow
            }

            HStack(spacing: 8) {
                attachmentButton
                screenshotMenu

                TextField("Ask Muse...", text: $messageText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .focused($isInputFocused)
                    .onSubmit {
                        triggerSend()
                    }

                recordingButton

                if museManager.isGenerating {
                    stopButton
                } else {
                    sendButton
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(12)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isInputFocused = true
            }
        }
    }

    private var attachmentsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(museManager.attachedFiles) { file in
                    HStack(spacing: 4) {
                        Image(systemName: file.type.iconName)
                            .font(.caption2)
                        Text(file.name)
                            .font(.caption2)
                            .lineLimit(1)
                        Button {
                            museManager.removeFile(file)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption2)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule())
                }
            }
        }
    }

    private var attachmentButton: some View {
        Button {
            openFilePicker()
        } label: {
            Image(systemName: "paperclip")
                .font(.body)
        }
        .buttonStyle(.plain)
        .help("Attach files")
    }

    private var screenshotMenu: some View {
        Menu {
            Button("Area Screenshot") {
                museManager.attachScreenshot(type: .area)
            }
            Button("Window Screenshot") {
                museManager.attachScreenshot(type: .window)
            }
            Button("Full Screen Screenshot") {
                museManager.attachScreenshot(type: .full)
            }
        } label: {
            Image(systemName: "camera")
                .font(.body)
        }
        .menuStyle(.borderlessButton)
        .help("Take screenshot")
    }

    private var recordingButton: some View {
        Button {
            museManager.toggleRecording()
        } label: {
            Image(systemName: museManager.isRecording ? "stop.circle.fill" : "mic.fill")
                .font(.body)
                .foregroundStyle(museManager.isRecording ? .red : .primary)
        }
        .buttonStyle(.plain)
        .help(museManager.isRecording ? "Stop recording" : "Start recording")
    }

    private var sendButton: some View {
        Button {
            triggerSend()
        } label: {
            Image(systemName: "paperplane.fill")
                .font(.body)
        }
        .buttonStyle(.plain)
        .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && museManager.attachedFiles.isEmpty)
        .help("Send message")
    }

    private var stopButton: some View {
        Button {
            museManager.stopGeneration()
        } label: {
            Image(systemName: "stop.fill")
                .font(.body)
        }
        .buttonStyle(.plain)
        .help("Stop generation")
    }

    private func triggerSend() {
        let text = messageText
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !museManager.attachedFiles.isEmpty else {
            return
        }
        onSend?(text)
        if onSend == nil {
            museManager.sendMessage(text)
        }
        messageText = ""
    }

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false

        if panel.runModal() == .OK {
            museManager.addFiles(panel.urls)
        }
    }
}

