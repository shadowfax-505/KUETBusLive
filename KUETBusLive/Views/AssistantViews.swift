//
//  AssistantViews.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  Screens for the optional assistant. Each one is hidden while the assistant is off,
//  and every suggestion is shown to a person first: nothing is posted or saved by
//  the model on its own.
//

import SwiftUI

// Small grey note under every answer.
struct AssistantSourceNote: View {
    var body: some View {
        Label("Answered on this iPhone", systemImage: "iphone")
            .font(.caption)
            .foregroundColor(.secondary)
    }
}

// MARK: - Profile: the on/off switch

struct AssistantSettingsSection: View {
    @EnvironmentObject var assistant: AssistantViewModel

    var body: some View {
        let status = assistant.status()
        Section(header: Text("Smart assistant"),
                footer: Text(status.note ?? String(localized: "Uses Apple's model on this iPhone. Nothing you ask leaves the phone. Answers may be wrong, so check the timetable."))) {
            if status.canOffer {
                Toggle("Smart assistant (on this iPhone)", isOn: $assistant.optedIn)
            } else {
                Label("Not available on this iPhone", systemImage: "iphone.slash")
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Rider: Ask

struct AskView: View {
    @EnvironmentObject var assistant: AssistantViewModel
    @Environment(\.dismiss) private var dismiss
    // Everything the answer may use, gathered by the map screen.
    let makePrompt: (String) -> String
    // A timetable answer that needs no model (TimetableAnswerer).
    let fallback: (String) -> String

    @State private var question = ""
    @State private var answer = ""
    // Why the timetable answered instead of the model, if it did.
    @State private var fallbackReason: String?
    @State private var isAsking = false
    @State private var request: AssistantRequest?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. When is the next bus to Rupsha?", text: $question, axis: .vertical)
                        .lineLimit(1...4)
                        .onSubmit { if !isAsking { ask() } }
                    Button(isAsking ? String(localized: "Cancel") : String(localized: "Ask")) {
                        isAsking ? cancel() : ask()
                    }
                    .disabled(question.trimmingCharacters(in: .whitespaces).isEmpty && !isAsking)
                }
                if !answer.isEmpty {
                    Section {
                        Text(answer)
                        if let reason = fallbackReason {
                            Label("From the timetable", systemImage: "tablecells")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if !reason.isEmpty {
                                Text(reason)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        } else if !isAsking {
                            AssistantSourceNote()
                        }
                    }
                }
                Section {
                    Text(assistant.isReady()
                         ? LocalizedStringKey("Answers come from this iPhone's own model, using only today's timetable, the buses running now and the latest news. They may be wrong, so check the timetable before you rely on them.")
                         : LocalizedStringKey("Answers come straight from today's timetable. Turn on the smart assistant in Profile for answers in your own words, where the iPhone supports it."))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Ask")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { cancel(); dismiss() }
                }
            }
        }
    }

    func ask() {
        let text = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        // No model on this phone (or switched off): answer from the timetable at once.
        guard assistant.isReady() else {
            answer = fallback(text)
            fallbackReason = ""
            return
        }
        let language = PlaceNames.isBangla ? "Bangla" : "English"
        isAsking = true
        fallbackReason = nil
        answer = String(localized: "Thinking...")
        request = assistant.askAsRider(system: RiderQuestion.system(languageName: language),
                                       user: makePrompt(text)) { result in
            isAsking = false
            switch result {
            case .success(let reply):
                answer = reply
            case .failure(.cancelled):
                answer = ""
            case .failure(let error):
                // The model failed: the timetable still answers, with the reason underneath.
                answer = fallback(text)
                fallbackReason = error.message
            }
        }
        if request == nil { isAsking = false }
    }

    func cancel() {
        request?.cancel()
        isAsking = false
    }
}

// MARK: - Admin: complaint suggestion

struct ComplaintSuggestionView: View {
    let complaint: Complaint
    @EnvironmentObject var assistant: AssistantViewModel
    let onUseReply: (String, ComplaintStatus?) -> Void

    @State private var triage: ComplaintTriage?
    @State private var errorMessage = ""
    @State private var isWorking = false
    @State private var request: AssistantRequest?

    var body: some View {
        if assistant.isReady(languageCode: AssistantViewModel.language(of: complaint.text)) {
            Section(header: Text("Assistant")) {
                Button(isWorking ? String(localized: "Cancel") : String(localized: "Suggest")) {
                    if isWorking {
                        request?.cancel()
                        isWorking = false
                    } else {
                        suggest()
                    }
                }
                if let triage = triage {
                    LabeledContent("Category", value: ComplaintCategory(rawValue: triage.category)?.title ?? triage.category)
                    LabeledContent("Urgency", value: triage.urgency)
                    Text(triage.summary).font(.subheadline)
                    Text(triage.reply)
                        .padding(8)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(8)
                    Button("Use this reply") {
                        onUseReply(triage.reply, nil)
                    }
                    AssistantSourceNote()
                }
                if !errorMessage.isEmpty {
                    Text(errorMessage).foregroundColor(.red).font(.footnote)
                }
            }
        }
    }

    func suggest() {
        isWorking = true
        errorMessage = ""
        request = assistant.triage(complaint) { result in
            isWorking = false
            switch result {
            case .success(let value): triage = value
            case .failure(let error): errorMessage = error.message
            }
        }
    }
}

// MARK: - Admin: announcement draft

struct AnnouncementDraftSection: View {
    @EnvironmentObject var assistant: AssistantViewModel
    @Binding var title: String
    @Binding var message: String

    @State private var note = ""
    @State private var draft: AnnouncementDraft?
    @State private var errorMessage = ""
    @State private var isWorking = false
    @State private var request: AssistantRequest?

    var body: some View {
        if assistant.isReady() {
            Section(header: Text("Draft with assistant"),
                    footer: Text("Write a short note. You get an English and a Bangla version to edit before posting.")) {
                TextField("Note, e.g. Normal-2 late 15 min, flat tyre", text: $note, axis: .vertical)
                Button(isWorking ? String(localized: "Cancel") : String(localized: "Draft")) {
                    if isWorking { request?.cancel(); isWorking = false } else { makeDraft() }
                }
                .disabled(note.trimmingCharacters(in: .whitespaces).isEmpty && !isWorking)
                if let draft = draft {
                    Button("Use English: \(draft.titleEn)") {
                        title = draft.titleEn
                        message = draft.bodyEn
                    }
                    Button("Use Bangla: \(draft.titleBn)") {
                        title = draft.titleBn
                        message = draft.bodyBn
                    }
                    Button("Use both") {
                        title = "\(draft.titleEn) / \(draft.titleBn)"
                        message = "\(draft.bodyEn)\n\n\(draft.bodyBn)"
                    }
                    AssistantSourceNote()
                }
                if !errorMessage.isEmpty {
                    Text(errorMessage).foregroundColor(.red).font(.footnote)
                }
            }
        }
    }

    func makeDraft() {
        isWorking = true
        errorMessage = ""
        // Only the admin's own note goes to the model.
        request = assistant.ask(system: AnnouncementDraft.system, user: "Note: \(note)") { result in
            isWorking = false
            switch result {
            case .success(let text):
                if let parsed = AnnouncementDraft.parse(text) { draft = parsed } else { errorMessage = AssistantError.badResponse.message }
            case .failure(let error):
                errorMessage = error.message
            }
        }
    }
}

// MARK: - Admin: timetable from pasted text

struct TimetableImportView: View {
    @EnvironmentObject var assistant: AssistantViewModel
    @ObservedObject var scheduleViewModel: ScheduleViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var pasted = ""
    @State private var proposed: [ImportedTrip]?
    @State private var errorMessage = ""
    @State private var isWorking = false
    @State private var request: AssistantRequest?

    var current: [ImportedTrip] {
        scheduleViewModel.schedules.map(ImportedTrip.init)
    }

    var diff: TimetableImport.Diff? {
        proposed.map { TimetableImport.diff(current: current, proposed: $0) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(footer: Text("Paste the text of the KUET transport timetable. The assistant turns it into trips; every time and field is checked, and you see the changes before anything is saved.")) {
                    TextEditor(text: $pasted)
                        .frame(minHeight: 150)
                    Button(isWorking ? String(localized: "Cancel") : String(localized: "Read with assistant")) {
                        if isWorking { request?.cancel(); isWorking = false } else { read() }
                    }
                    .disabled(pasted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isWorking)
                    AssistantSourceNote()
                }
                if !errorMessage.isEmpty {
                    Text(errorMessage).foregroundColor(.red)
                }
                if let diff = diff {
                    if diff.isEmpty {
                        Text("No changes: the timetable already matches.")
                    }
                    if !diff.added.isEmpty {
                        Section(header: Text("New trips (\(diff.added.count))")) {
                            ForEach(diff.added, id: \.self) { TripLine(trip: $0) }
                        }
                    }
                    if !diff.changed.isEmpty {
                        Section(header: Text("Changed (\(diff.changed.count))")) {
                            ForEach(diff.changed.indices, id: \.self) { index in
                                VStack(alignment: .leading) {
                                    TripLine(trip: diff.changed[index].old).strikethrough().foregroundColor(.secondary)
                                    TripLine(trip: diff.changed[index].new)
                                }
                            }
                        }
                    }
                    if !diff.removed.isEmpty {
                        Section(header: Text("Removed (\(diff.removed.count))")) {
                            ForEach(diff.removed, id: \.self) { TripLine(trip: $0).foregroundColor(.red) }
                        }
                    }
                }
            }
            .navigationTitle("Import timetable")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard") { request?.cancel(); dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Approve") { apply(); dismiss() }
                        .disabled(diff?.isEmpty ?? true)
                }
            }
        }
    }

    func read() {
        isWorking = true
        errorMessage = ""
        proposed = nil
        request = assistant.ask(system: TimetableImport.system, user: pasted) { result in
            isWorking = false
            switch result {
            case .success(let text):
                if let trips = TimetableImport.parse(text) {
                    proposed = trips
                } else {
                    errorMessage = String(localized: "The assistant's timetable didn't pass the checks (a time, day or field was wrong). Nothing was changed.")
                }
            case .failure(let error):
                errorMessage = error.message
            }
        }
    }

    // Saves exactly the changes shown: adds new trips, updates changed ones, deletes removed ones.
    func apply() {
        guard let diff = diff else { return }
        func schedule(_ trip: ImportedTrip, id: String?) -> BusSchedule? {
            guard let audience = BusAudience(rawValue: trip.audience), let days = TripDays(rawValue: trip.days),
                  let period = TripPeriod(rawValue: trip.period) else { return nil }
            var new = BusSchedule(tripName: trip.tripName, audience: audience, days: days, period: period,
                                  campusTime: trip.campusTime, spot: trip.spot, spotTime: trip.spotTime,
                                  remarks: trip.remarks ?? "")
            new.id = id
            return new
        }
        func existing(_ trip: ImportedTrip) -> BusSchedule? {
            scheduleViewModel.schedules.first { ImportedTrip($0).key == trip.key }
        }
        for trip in diff.added { if let s = schedule(trip, id: nil) { scheduleViewModel.save(s) } }
        for change in diff.changed {
            if let old = existing(change.old), let s = schedule(change.new, id: old.id) { scheduleViewModel.save(s) }
        }
        for trip in diff.removed { if let old = existing(trip) { scheduleViewModel.delete(old) } }
    }
}

struct TripLine: View {
    let trip: ImportedTrip

    var body: some View {
        Text("\(trip.tripName) · \(trip.spot) · \(TripDays(rawValue: trip.days)?.title ?? trip.days) · \(BusSchedule.display(trip.campusTime)) / \(BusSchedule.display(trip.spotTime))")
            .font(.footnote)
    }
}
