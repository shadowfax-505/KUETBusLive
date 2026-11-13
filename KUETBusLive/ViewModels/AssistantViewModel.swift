//
//  AssistantViewModel.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  The smart assistant's switch and its requests. Each person turns it on for their
//  own iPhone in Settings > Smart assistant; it is off by default. Everything runs on the phone.
//

import Foundation

class AssistantViewModel: ObservableObject {
    static let optInKey = "smartAssistantOn"

    @Published var optedIn: Bool {
        didSet { UserDefaults.standard.set(optedIn, forKey: Self.optInKey) }
    }

    // The model to use: the real one, or a fake in unit tests.
    var model: AssistantModel
    private var lastRiderQuestion = Date.distantPast

    init(model: AssistantModel = OnDeviceModel()) {
        self.model = model
        optedIn = UserDefaults.standard.bool(forKey: Self.optInKey)
    }

    // The language answers are in: the app's language.
    static var appLanguage: String {
        PlaceNames.isBangla ? "bn" : "en"
    }

    // Bangla letters in a text (for example a complaint) mean the text is Bangla.
    static func language(of text: String) -> String {
        text.unicodeScalars.contains { (0x0980...0x09FF).contains($0.value) } ? "bn" : "en"
    }

    func status(languageCode: String = appLanguage) -> AssistantStatus {
        AssistantStatus(availability: OnDeviceModelInfo.availability,
                        speaksLanguage: OnDeviceModelInfo.speaks(languageCode), optedIn: optedIn)
    }

    // Screens show assistant buttons only when this is true.
    func isReady(languageCode: String = appLanguage) -> Bool {
        status(languageCode: languageCode).isReady
    }

    @discardableResult
    func ask(system: String, user: String, languageCode: String = appLanguage,
             completion: @escaping (Result<String, AssistantError>) -> Void) -> AssistantRequest {
        guard isReady(languageCode: languageCode) else {
            let status = status(languageCode: languageCode)
            completion(.failure(status.canOffer ? .languageNotSupported : .unavailable(status.availability.explanation)))
            return AssistantRequest()
        }
        return model.complete(system: system, user: user, completion: completion)
    }

    // Riders may ask once every 10 seconds.
    func askAsRider(system: String, user: String,
                    completion: @escaping (Result<String, AssistantError>) -> Void) -> AssistantRequest? {
        guard Date().timeIntervalSince(lastRiderQuestion) >= RiderQuestion.minSecondsBetween else {
            completion(.failure(.rateLimited))
            return nil
        }
        lastRiderQuestion = Date()
        return ask(system: system, user: user, completion: completion)
    }

    // Complaint triage with guided generation, in the complaint's own language.
    func triage(_ complaint: Complaint,
                completion: @escaping (Result<ComplaintTriage, AssistantError>) -> Void) -> AssistantRequest {
        let language = Self.language(of: complaint.text)
        guard isReady(languageCode: language) else {
            completion(.failure(.languageNotSupported))
            return AssistantRequest()
        }
        return OnDeviceModel().triage(system: ComplaintTriage.system, user: ComplaintTriage.prompt(for: complaint),
                                      completion: completion)
    }
}
