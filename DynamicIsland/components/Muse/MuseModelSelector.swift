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

import Defaults
import SwiftUI

struct MuseModelSelector: View {
    @Default(.selectedAIProvider) private var selectedProvider
    @Default(.selectedAIModel) private var selectedModel
    @Default(.enableThinkingMode) private var enableThinkingMode

    private var displayText: String {
        let model = selectedModel?.name ?? selectedProvider.supportedModels.first?.name ?? "Model"
        return "\(selectedProvider.displayName) • \(model)"
    }

    var body: some View {
        Menu {
            ForEach(AIModelProvider.allCases) { provider in
                Section(provider.displayName) {
                    ForEach(provider.supportedModels) { model in
                        Button {
                            selectedProvider = provider
                            selectedModel = model
                            if !model.supportsThinking {
                                enableThinkingMode = false
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(model.name)
                                    if model.supportsThinking {
                                        Text("Thinking")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if selectedProvider == provider && selectedModel?.id == model.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "sailboat.fill")
                    .font(.caption)
                Text(displayText)
                    .font(.caption)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.12))
            .clipShape(Capsule())
        }
        .menuStyle(.borderlessButton)
        .help(String(localized: "Select AI model"))
    }
}

