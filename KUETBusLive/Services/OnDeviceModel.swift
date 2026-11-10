//
//  OnDeviceModel.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  Apple's on-device model (Foundation Models framework, iOS 26 with Apple
//  Intelligence). The app still supports iOS 17, so everything here is wrapped in
//  `#if canImport(FoundationModels)` and `#available(iOS 26, *)`. The framework's
//  API is async; this wraps it in completion handlers like the rest of the app.
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

enum OnDeviceModelInfo {
    // What the phone can do right now.
    static var availability: DeviceModelAvailability {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available: return .available
            case .unavailable(.deviceNotEligible): return .notSupported
            case .unavailable(.appleIntelligenceNotEnabled): return .appleIntelligenceOff
            case .unavailable(.modelNotReady): return .downloading
            case .unavailable(let other): return .other(String(describing: other))
            }
        }
        #endif
        return .notSupported
    }

    // Does the model understand this language ("en", "bn")?
    static func speaks(_ languageCode: String) -> Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return SystemLanguageModel.default.supportedLanguages
                .contains { $0.languageCode?.identifier == languageCode }
        }
        #endif
        return false
    }
}

struct OnDeviceModel: AssistantModel {
    func complete(system: String, user: String,
                  completion: @escaping (Result<String, AssistantError>) -> Void) -> AssistantRequest {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let task = Task {
                do {
                    let session = LanguageModelSession(instructions: system)
                    let response = try await session.respond(to: user)
                    let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                    await MainActor.run { completion(text.isEmpty ? .failure(.badResponse) : .success(text)) }
                } catch {
                    await MainActor.run { completion(.failure(Self.mapError(error))) }
                }
            }
            return AssistantRequest { task.cancel() }
        }
        #endif
        DispatchQueue.main.async { completion(.failure(.unavailable(DeviceModelAvailability.notSupported.explanation))) }
        return AssistantRequest()
    }

    // Complaint triage with guided generation: the model fills in a fixed shape.
    func triage(system: String, user: String,
                completion: @escaping (Result<ComplaintTriage, AssistantError>) -> Void) -> AssistantRequest {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let task = Task {
                do {
                    let session = LanguageModelSession(instructions: system)
                    let result = try await session.respond(to: user, generating: GeneratedTriage.self).content
                    let triage = ComplaintTriage(category: result.category, urgency: result.urgency,
                                                 summary: result.summary, reply: result.reply)
                    await MainActor.run { completion(triage.isValid ? .success(triage) : .failure(.badResponse)) }
                } catch {
                    await MainActor.run { completion(.failure(Self.mapError(error))) }
                }
            }
            return AssistantRequest { task.cancel() }
        }
        #endif
        DispatchQueue.main.async { completion(.failure(.unavailable(DeviceModelAvailability.notSupported.explanation))) }
        return AssistantRequest()
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    static func mapError(_ error: Error) -> AssistantError {
        if error is CancellationError { return .cancelled }
        if let generation = error as? LanguageModelSession.GenerationError {
            switch generation {
            case .exceededContextWindowSize: return .contextTooLong
            case .unsupportedLanguageOrLocale: return .languageNotSupported
            default: return .unavailable(generation.localizedDescription)
            }
        }
        return .unavailable(error.localizedDescription)
    }
    #endif
}

#if canImport(FoundationModels)
// Guided generation: the model must fill in exactly these fields.
@available(iOS 26.0, *)
@Generable
struct GeneratedTriage {
    @Guide(description: "Best category: late, driverBehaviour, overcrowding, busCondition, app or other")
    var category: String
    @Guide(description: "How urgent it is: low, medium or high")
    var urgency: String
    @Guide(description: "One short sentence summarising the complaint")
    var summary: String
    @Guide(description: "A short, polite draft reply from the transport office, in English")
    var reply: String
}
#endif
