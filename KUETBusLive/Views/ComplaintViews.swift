//
//  ComplaintViews.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  Profile > Report a problem: a short form that sends a complaint.
//  Profile > My complaints: what I sent, its status and the admin's reply.
//  Admin > Complaints: the inbox, filtered by status, with a reply box.
//

import SwiftUI

// MARK: - Rider or driver: send a complaint

struct ReportProblemView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var complaintViewModel = ComplaintViewModel()
    @StateObject private var routeViewModel = RouteViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var category = ComplaintCategory.late
    @State private var routeName = ""      // "" means not about one route
    @State private var busName = ""
    @State private var addTime = false
    @State private var tripTime = Date()
    @State private var text = ""
    @State private var isSending = false
    @State private var errorMessage = ""
    @State private var sent = false

    var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && text.count <= Complaint.maxTextLength && !isSending
    }

    var body: some View {
        Form {
            Section(header: Text("What happened?")) {
                Picker("Category", selection: $category) {
                    ForEach(ComplaintCategory.allCases) { category in
                        Text(category.title).tag(category)
                    }
                }
                TextField("Tell the transport office what happened", text: $text, axis: .vertical)
                    .lineLimit(4...10)
            }

            Section(header: Text("Which bus? (optional)")) {
                Picker("Route", selection: $routeName) {
                    Text("Not sure").tag("")
                    ForEach(routeViewModel.routes) { route in
                        Text(route.displayName).tag(route.name)
                    }
                }
                TextField("Bus, e.g. Normal-2", text: $busName)
                Toggle("Add the time", isOn: $addTime.animation())
                if addTime {
                    DatePicker("When", selection: $tripTime, in: ...Date())
                }
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
            }

            Section(footer: Text("Only you and the transport admin can read this. You can't change it after sending.")) {
                Button {
                    send()
                } label: {
                    HStack {
                        Text("Send")
                        if isSending {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(!canSend)
            }
        }
        .navigationTitle("Report a problem")
        .onAppear { routeViewModel.startListening() }
        .onDisappear { routeViewModel.stopListening() }
        .alert("Sent", isPresented: $sent) {
            Button("OK") { dismiss() }
        } message: {
            Text("Thank you. You can follow it in My complaints.")
        }
    }

    func send() {
        guard let uid = authViewModel.user?.uid, let profile = authViewModel.profile else { return }
        let complaint = Complaint.new(uid: uid, userName: profile.name, userRole: profile.role,
                                      category: category,
                                      routeName: routeName.isEmpty ? nil : routeName,
                                      busName: busName.trimmingCharacters(in: .whitespaces).isEmpty
                                          ? nil : busName.trimmingCharacters(in: .whitespaces),
                                      tripTime: addTime ? tripTime : nil,
                                      text: text)
        isSending = true
        errorMessage = ""
        complaintViewModel.send(complaint) { error in
            isSending = false
            if let error = error {
                errorMessage = error
            } else {
                sent = true
            }
        }
    }
}

// MARK: - Rider or driver: my complaints

struct MyComplaintsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var complaintViewModel = ComplaintViewModel()

    var body: some View {
        List(complaintViewModel.complaints) { complaint in
            ComplaintRow(complaint: complaint, showSender: false)
        }
        .overlay {
            if complaintViewModel.complaints.isEmpty {
                ContentUnavailableView("No complaints",
                                       systemImage: "checkmark.bubble",
                                       description: Text("Problems you report will appear here with the transport office's reply."))
            }
        }
        .navigationTitle("My complaints")
        .onAppear {
            if let uid = authViewModel.user?.uid {
                complaintViewModel.listenToMine(uid: uid)
            }
        }
        .onDisappear { complaintViewModel.stopListening() }
    }
}

// One complaint in a list: category, status, text and the admin's reply if any.
struct ComplaintRow: View {
    let complaint: Complaint
    let showSender: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(complaint.category.title, systemImage: complaint.category.icon)
                    .font(.headline)
                Spacer()
                StatusTag(status: complaint.status)
            }
            if showSender {
                Text("\(complaint.userName) · \(UserRole(rawValue: complaint.userRole)?.title ?? complaint.userRole)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            if let busAndRoute = complaint.busAndRoute {
                Label(busAndRoute, systemImage: "bus")
                    .font(.subheadline)
            }
            Text(complaint.text)
                .lineLimit(showSender ? 2 : nil)
                .fixedSize(horizontal: false, vertical: true)
            if let reply = complaint.adminReply, !showSender {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Transport office replied")
                        .font(.caption.bold())
                    Text(reply)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.accentColor.opacity(0.12))
                .cornerRadius(8)
            }
            Text(complaint.createdAt, style: .date)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

struct StatusTag: View {
    let status: ComplaintStatus

    var color: Color {
        switch status {
        case .open: return .orange
        case .inReview: return .blue
        case .resolved: return .green
        }
    }

    var body: some View {
        Label(status.title, systemImage: status.icon)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(Capsule())
    }
}

// MARK: - Admin: the complaints inbox

struct AdminComplaintsView: View {
    @ObservedObject var complaintViewModel: ComplaintViewModel
    // nil shows every status.
    @State private var filter: ComplaintStatus? = .open

    var body: some View {
        List {
            Picker("Status", selection: $filter) {
                Text("All").tag(ComplaintStatus?.none)
                ForEach(ComplaintStatus.allCases) { status in
                    Text(status.title).tag(ComplaintStatus?.some(status))
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)

            ForEach(complaintViewModel.complaints(with: filter)) { complaint in
                NavigationLink {
                    ComplaintReplyView(complaint: complaint, complaintViewModel: complaintViewModel)
                } label: {
                    HStack(alignment: .top) {
                        // Blue dot: not opened yet.
                        Circle()
                            .fill(complaint.readByAdmin ? Color.clear : Color.blue)
                            .frame(width: 8, height: 8)
                            .padding(.top, 8)
                        ComplaintRow(complaint: complaint, showSender: true)
                    }
                }
            }
        }
        .overlay {
            if complaintViewModel.complaints(with: filter).isEmpty {
                ContentUnavailableView("Nothing here", systemImage: "tray",
                                       description: Text("No complaints with this status."))
            }
        }
        .navigationTitle("Complaints")
    }
}

// Admin: read one complaint, change its status and reply.
struct ComplaintReplyView: View {
    let complaint: Complaint
    @ObservedObject var complaintViewModel: ComplaintViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var status = ComplaintStatus.open
    @State private var reply = ""
    @State private var errorMessage = ""

    var body: some View {
        Form {
            Section {
                ComplaintRow(complaint: complaint, showSender: true)
                if let time = complaint.tripTime {
                    LabeledContent("When", value: time.formatted(date: .abbreviated, time: .shortened))
                }
                LabeledContent("Sent", value: complaint.createdAt.formatted(date: .abbreviated, time: .shortened))
            }
            Section(header: Text("Status")) {
                Picker("Status", selection: $status) {
                    ForEach(ComplaintStatus.allCases) { status in
                        Text(status.title).tag(status)
                    }
                }
                .pickerStyle(.segmented)
            }
            Section(header: Text("Reply"), footer: Text("The person who sent it sees this reply in My complaints.")) {
                TextField("Write a reply", text: $reply, axis: .vertical)
                    .lineLimit(3...8)
            }
            if !errorMessage.isEmpty {
                Text(errorMessage).foregroundColor(.red)
            }
        }
        .navigationTitle(complaint.category.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Save") {
                complaintViewModel.update(complaint, status: status, reply: reply) { error in
                    if let error = error {
                        errorMessage = error
                    } else {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            status = complaint.status
            reply = complaint.adminReply ?? ""
            complaintViewModel.markRead(complaint)
        }
    }
}
