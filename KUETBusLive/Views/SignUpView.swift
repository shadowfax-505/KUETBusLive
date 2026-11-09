//
//  SignUpView.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//

import SwiftUI

struct SignUpView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var kuetId = ""
    @State private var role: UserRole = .student

    var isFormValid: Bool {
        !name.isEmpty && email.contains("@") && password.count >= 6 && !kuetId.isEmpty
    }

    // Explains what each role needs, using a switch on the enum.
    var roleHint: String {
        switch role {
        case .student:
            return String(localized: "Use your @\(KUETVerifier.studentEmailDomain) email. Your roll number must match the one in it. We'll email you a link to confirm.")
        case .teacher:
            return String(localized: "Use your KUET staff email. We'll email you a link, and the transport office checks your employee ID.")
        case .driver:
            return String(localized: "The transport office checks your driver ID before you can start trips.")
        case .admin:
            return ""
        }
    }

    var body: some View {
        Form {
            Section(header: Text("I am a")) {
                RolePicker(role: $role)
            }

            Section(header: Text("Your details"), footer: Text(roleHint)) {
                TextField("Name", text: $name)
                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                TextField(role.idLabel, text: $kuetId)
                    .keyboardType(role == .student ? .numberPad : .default)
                SecureField("Password (6+ characters)", text: $password)
            }

            if !authViewModel.errorMessage.isEmpty {
                Text(authViewModel.errorMessage)
                    .foregroundColor(.red)
            }

            Button("Sign Up") {
                authViewModel.signUp(name: name, email: email, password: password,
                                     role: role, kuetId: kuetId)
            }
            .disabled(!isFormValid)
        }
        .navigationTitle("Sign Up")
        // An old error belongs to the old role, so clear it when the role changes.
        .onChange(of: role) {
            authViewModel.errorMessage = ""
        }
    }
}

// @Binding: the picker changes the parent's role variable directly.
struct RolePicker: View {
    @Binding var role: UserRole

    var body: some View {
        Picker("Role", selection: $role) {
            ForEach(UserRole.signUpRoles, id: \.self) { role in
                Text(role.title).tag(role)
            }
        }
        .pickerStyle(.segmented)
    }
}
