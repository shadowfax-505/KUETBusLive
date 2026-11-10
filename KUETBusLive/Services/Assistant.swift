//
//  Assistant.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  The optional smart assistant. It uses only the phone's own model (Apple's
//  Foundation Models on iOS 26 with Apple Intelligence), so nothing leaves the
//  phone and there is no server. Each person turns it on for their own iPhone,
//  and only phones that can run the model are offered the setting.
//
//  The decisions are kept here as plain Swift so they can be unit tested; the
//  model itself is in OnDeviceModel.swift.
//

import Foundation

enum AssistantError: Error, Equatable {
    case unavailable(String)        // the phone can't run the model, with the reason
    case languageNotSupported       // the model doesn't speak the app's language (for example Bangla)
    case contextTooLong             // the text doesn't fit the model
    case badResponse                // the answer wasn't in the expected shape
    case rateLimited
    case cancelled

    var message: String {
        switch self {
        case .unavailable(let reason): return String(localized: "The assistant can't run on this iPhone: \(reason)")
        case .languageNotSupported: return String(localized: "The assistant doesn't support this language yet.")
        case .contextTooLong: return String(localized: "That text is too long for the assistant. Paste a smaller part.")
        case .badResponse: return String(localized: "The assistant's answer couldn't be read. Try again.")
        case .rateLimited: return String(localized: "Please wait a few seconds before asking again.")
        case .cancelled: return String(localized: "Cancelled.")
        }
    }
}

// Anything that turns instructions and a prompt into text: the real on-device
// model, or a fake one in the unit tests.
protocol AssistantModel {
    @discardableResult
    func complete(system: String, user: String,
                  completion: @escaping (Result<String, AssistantError>) -> Void) -> AssistantRequest
}

// A running request that the screen can cancel.
final class AssistantRequest {
    private var onCancel: (() -> Void)?
    init(onCancel: (() -> Void)? = nil) { self.onCancel = onCancel }
    func cancel() { onCancel?(); onCancel = nil }
}

// What the phone can do, as reported by the Foundation Models framework.
enum DeviceModelAvailability: Equatable {
    case available
    case notSupported           // older iPhone, or iOS before 26
    case appleIntelligenceOff
    case downloading
    case other(String)

    var explanation: String {
        switch self {
        case .available: return ""
        case .notSupported: return String(localized: "This iPhone doesn't support Apple Intelligence, which the assistant needs (iOS 26 on a recent iPhone).")
        case .appleIntelligenceOff: return String(localized: "Turn on Apple Intelligence in Settings to use the assistant.")
        case .downloading: return String(localized: "The model is still downloading. Try again later.")
        case .other(let reason): return reason
        }
    }
}

// Whether the assistant may be used right now (pure, unit tested).
struct AssistantStatus: Equatable {
    var availability: DeviceModelAvailability
    var speaksLanguage: Bool
    var optedIn: Bool

    // Show the on/off switch only on phones that can run the model.
    var canOffer: Bool { availability == .available }

    // Show assistant buttons only when it's on, can run, and speaks the language.
    var isReady: Bool { canOffer && optedIn && speaksLanguage }

    // A short note for Profile, or nil when everything is fine.
    var note: String? {
        if !canOffer { return availability.explanation }
        if !speaksLanguage { return String(localized: "The assistant doesn't support this language yet, so it's hidden while the app is in this language.") }
        return nil
    }
}

// Reading JSON the model wrote (pure, unit tested).
enum AssistantJSON {
    // Models sometimes wrap JSON in ``` fences or add a sentence around it.
    // Take the outermost {...} or [...] and decode that; anything else fails.
    static func decode<T: Decodable>(_ type: T.Type, from text: String) -> T? {
        guard let start = text.firstIndex(where: { $0 == "{" || $0 == "[" }) else { return nil }
        let closing: Character = text[start] == "{" ? "}" : "]"
        guard let end = text.lastIndex(of: closing), end > start else { return nil }
        return try? JSONDecoder().decode(type, from: Data(text[start...end].utf8))
    }
}
