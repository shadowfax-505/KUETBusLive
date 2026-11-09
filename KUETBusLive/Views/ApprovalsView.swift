//
//  ApprovalsView.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  The admin checks each teacher's employee ID and each driver's ID before approving.
//

import SwiftUI

struct ApprovalsView: View {
    @StateObject private var adminViewModel = AdminViewModel()

    var body: some View {
        NavigationStack {
            List(adminViewModel.pendingUsers) { user in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(user.name)
                            .font(.headline)
                        Spacer()
                        Text(user.role.title)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text(user.email)
                        .font(.subheadline)
                    Text("\(user.role.idLabel): \(user.kuetId ?? "not given")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack {
                        Button("Approve") {
                            adminViewModel.approve(user)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)

                        Spacer()

                        Button("Reject") {
                            adminViewModel.reject(user)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                }
                .padding(.vertical, 4)
            }
            .overlay {
                if adminViewModel.pendingUsers.isEmpty {
                    Text("No one is waiting for approval")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Approvals")
        }
        .onAppear {
            adminViewModel.startListening()
        }
        .onDisappear {
            adminViewModel.stopListening()
        }
    }
}
