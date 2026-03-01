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

import AISDKProvider
import AnthropicProvider
import DeepSeekProvider
import Defaults
import Foundation
import GoogleProvider
import OpenAICompatibleProvider
import OpenAIProvider

enum MuseProviderFactoryError: LocalizedError {
    case customEndpointMissing

    var errorDescription: String? {
        switch self {
        case .customEndpointMissing:
            return String(localized: "Custom OpenAI endpoint is missing")
        }
    }
}

enum MuseProviderFactory {
    static func makeLanguageModel(
        provider: AIModelProvider,
        modelID: String
    ) throws -> any LanguageModelV3 {
        switch provider {
        case .openai:
            let openAI = createOpenAIProvider(
                settings: OpenAIProviderSettings(
                    apiKey: Defaults[.openaiApiKey]
                )
            )
            return try openAI.languageModel(modelId: modelID)

        case .claude:
            let anthropic = createAnthropicProvider(
                settings: AnthropicProviderSettings(
                    apiKey: Defaults[.claudeApiKey]
                )
            )
            return try anthropic.languageModel(modelId: modelID)

        case .gemini:
            let google = createGoogleGenerativeAI(
                settings: GoogleProviderSettings(
                    apiKey: Defaults[.geminiApiKey]
                )
            )
            return try google.languageModel(modelId: modelID)

        case .deepseek:
            let deepSeek = createDeepSeekProvider(
                settings: DeepSeekProviderSettings(
                    apiKey: Defaults[.deepseekApiKey]
                )
            )
            return try deepSeek.languageModel(modelId: modelID)

        case .local:
            let endpoint = normalizedOpenAICompatibleBaseURL(
                Defaults[.localModelEndpoint],
                fallback: "http://localhost:11434/v1"
            )
            let local = createOpenAICompatibleProvider(
                settings: OpenAICompatibleProviderSettings(
                    baseURL: endpoint,
                    name: "muse.ollama",
                    apiKey: "ollama"
                )
            )
            return try local.languageModel(modelId: modelID)

        case .customOpenAI:
            let rawEndpoint = Defaults[.customOpenAIEndpoint].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rawEndpoint.isEmpty else {
                throw MuseProviderFactoryError.customEndpointMissing
            }
            let custom = createOpenAICompatibleProvider(
                settings: OpenAICompatibleProviderSettings(
                    baseURL: normalizedOpenAICompatibleBaseURL(rawEndpoint, fallback: rawEndpoint),
                    name: "muse.custom-openai",
                    apiKey: Defaults[.customOpenAIApiKey]
                )
            )
            return try custom.languageModel(modelId: modelID)
        }
    }

    private static func normalizedOpenAICompatibleBaseURL(_ raw: String, fallback: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.isEmpty ? fallback : trimmed
        if base.hasSuffix("/v1") {
            return base
        }
        if base.hasSuffix("/") {
            return base + "v1"
        }
        return base + "/v1"
    }
}

