//
//  LoginView.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var logoScale = 0.7

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image("AppLogo")
                    .resizable()
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .shadow(radius: 8)
                    .scaleEffect(logoScale)
                    .onAppear {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) {
                            logoScale = 1
                        }
                    }

                Text("KUET Bus Live")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)

                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                if !authViewModel.errorMessage.isEmpty {
                    Text(authViewModel.errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                }

                Button {
                    authViewModel.signIn(email: email, password: password)
                } label: {
                    Text("Sign In")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(email.isEmpty || password.isEmpty)

                NavigationLink("Create an account") {
                    SignUpView()
                }
            }
            .padding()
        }
    }
}
