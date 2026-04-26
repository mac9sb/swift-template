import SwiftUI
import AuthenticationServices
import FoundationKit

struct AuthView: View {
    @Environment(SessionStore.self) private var session
    @State private var email = ""
    @State private var phase: Phase = .idle

    private let auth = AuthService(client: APIClient(baseURL: Config.baseURL))

    enum Phase {
        case idle, sending, sent, error(String)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 32) {
                    VStack(spacing: 8) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(.tint)
                        Text("Welcome back")
                            .font(.title2.weight(.semibold))
                        Text("Sign in or create an account.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if case .sent = phase {
                        sentView
                    } else {
                        formView
                    }
                }
                .padding(.horizontal, 32)

                Spacer()
            }
            .navigationBarHidden(true)
        }
    }

    private var formView: some View {
        VStack(spacing: 16) {
            // Magic link
            VStack(spacing: 12) {
                TextField("Email address", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)

                Button {
                    Task { await sendMagicLink() }
                } label: {
                    Group {
                        if case .sending = phase {
                            ProgressView()
                        } else {
                            Text("Send sign-in link")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(email.isEmpty || phase == .sending)
            }

            divider

            // Sign in with Apple
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                Task { await handleAppleResult(result) }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .cornerRadius(8)

            divider

            // Passkey
            Button {
                Task { await loginWithPasskey() }
            } label: {
                Label("Sign in with a passkey", systemImage: "person.badge.key.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            if case .error(let msg) = phase {
                Text(msg)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var sentView: some View {
        VStack(spacing: 16) {
            Image(systemName: "envelope.badge.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("Check your inbox")
                .font(.headline)
            Text("A sign-in link is on its way to \(email).")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Use a different email") {
                phase = .idle
                email = ""
            }
            .buttonStyle(.borderless)
        }
    }

    private var divider: some View {
        HStack {
            Rectangle().frame(height: 1).foregroundStyle(.separator)
            Text("or").font(.footnote).foregroundStyle(.secondary)
            Rectangle().frame(height: 1).foregroundStyle(.separator)
        }
    }

    // MARK: - Actions

    private func sendMagicLink() async {
        guard !email.isEmpty else { return }
        phase = .sending
        do {
            try await auth.sendMagicLink(email: email)
            phase = .sent
        } catch APIError.tooManyRequests {
            phase = .error("Too many requests. Please wait before trying again.")
        } catch {
            phase = .error("Something went wrong. Please try again.")
        }
    }

    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let auth):
            guard
                let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken
            else {
                phase = .error("Sign in with Apple failed.")
                return
            }
            do {
                try await self.auth.signInWithApple(identityToken: tokenData)
                await session.refresh()
            } catch {
                phase = .error("Sign in with Apple failed.")
            }
        case .failure(let error as ASAuthorizationError) where error.code == .canceled:
            break
        case .failure:
            phase = .error("Sign in with Apple failed.")
        }
    }

    private func loginWithPasskey() async {
        do {
            let challenge = try await auth.beginPasskeyLogin()
            let assertion = try await PasskeyCoordinator.performAssertion(challenge: challenge)
            try await auth.finishPasskeyLogin(
                challengeId: assertion.challengeId,
                response: assertion.response
            )
            await session.refresh()
        } catch PasskeyCoordinator.Error.canceled {
            // user dismissed — no error shown
        } catch {
            phase = .error("Passkey sign-in failed.")
        }
    }
}
