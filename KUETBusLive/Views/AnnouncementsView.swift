//
//  AnnouncementsView.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  News from the transport office. Everyone sees the list, newest first.
//  The admin also gets a "+" button to post and can swipe to delete.
//

import SwiftUI

struct AnnouncementsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var announcementViewModel: AnnouncementViewModel
    @State private var showCompose = false

    var isAdmin: Bool {
        authViewModel.profile?.role == .admin
    }

    var body: some View {
        List {
            ForEach(announcementViewModel.announcements) { announcement in
                AnnouncementRow(announcement: announcement)
            }
            .onDelete { offsets in
                guard isAdmin else { return }
                for index in offsets {
                    announcementViewModel.delete(announcementViewModel.announcements[index])
                }
            }
            .deleteDisabled(!isAdmin)
        }
        .overlay {
            if announcementViewModel.announcements.isEmpty {
                ContentUnavailableView("No announcements",
                                       systemImage: "megaphone",
                                       description: Text("News from the KUET transport office will appear here."))
            }
        }
        .navigationTitle("Announcements")
        .toolbar {
            if isAdmin {
                Button {
                    showCompose = true
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .accessibilityLabel("New announcement")
            }
        }
        .sheet(isPresented: $showCompose) {
            ComposeAnnouncementView()
        }
        // Looking at the list counts as reading it.
        .onAppear {
            announcementViewModel.markAllRead()
        }
        .onChange(of: announcementViewModel.announcements.count) {
            announcementViewModel.markAllRead()
        }
    }
}

struct AnnouncementRow: View {
    let announcement: Announcement

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(announcement.title)
                .font(.headline)
            Text(announcement.body)
                .font(.body)
            HStack {
                if let route = announcement.routeName {
                    Label(route, systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                }
                Spacer()
                Text("\(announcement.postedBy) · \(announcement.timeText)")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

// Admin: write a new announcement.
struct ComposeAnnouncementView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var announcementViewModel: AnnouncementViewModel
    @StateObject private var routeViewModel = RouteViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var message = ""
    @State private var routeName = ""   // "" means all routes
    @State private var errorMessage = ""
    @State private var isPosting = false

    var canPost: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
            && !message.trimmingCharacters(in: .whitespaces).isEmpty
            && !isPosting
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title, e.g. Normal-2 is late", text: $title)
                    TextField("Message", text: $message, axis: .vertical)
                        .lineLimit(3...8)
                }
                Section {
                    Picker("Route", selection: $routeName) {
                        Text("All routes").tag("")
                        ForEach(routeViewModel.routes) { route in
                            Text(route.name).tag(route.name)
                        }
                    }
                }
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
            }
            .navigationTitle("New announcement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post", action: post)
                        .disabled(!canPost)
                }
            }
        }
        .onAppear { routeViewModel.startListening() }
        .onDisappear { routeViewModel.stopListening() }
    }

    func post() {
        isPosting = true
        announcementViewModel.post(title: title.trimmingCharacters(in: .whitespaces),
                                   body: message.trimmingCharacters(in: .whitespaces),
                                   routeName: routeName.isEmpty ? nil : routeName,
                                   postedBy: authViewModel.profile?.name ?? "Transport office") { error in
            isPosting = false
            if let error = error {
                errorMessage = "Could not post: \(error)"
            } else {
                dismiss()
            }
        }
    }
}

// The latest announcement as a banner on the student home (map) screen.
struct AnnouncementBanner: View {
    let announcement: Announcement
    let onOpen: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "megaphone.fill")
                .foregroundColor(.orange)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(announcement.title)
                    .font(.subheadline.bold())
                Text(announcement.body)
                    .font(.caption)
                    .lineLimit(2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
            }
            .accessibilityLabel("Close announcement")
        }
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens all announcements")
    }
}
