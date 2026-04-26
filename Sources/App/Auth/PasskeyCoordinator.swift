import AuthenticationServices
import Foundation
import FoundationKit

/// Bridges the `ASAuthorizationController` delegate pattern into Swift concurrency.
///
/// Call `PasskeyCoordinator.performAssertion(challenge:)` from an async context.
/// It presents the system passkey picker and returns the assertion once the user
/// approves, or throws `PasskeyCoordinator.Error.canceled` if they dismiss it.
@MainActor
final class PasskeyCoordinator: NSObject, ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding
{
    enum Error: Swift.Error { case canceled, failed(Swift.Error) }

    struct AssertionResult {
        let challengeId: String
        let response: PasskeyAssertionResponse
    }

    private var continuation: CheckedContinuation<AssertionResult, Swift.Error>?
    private var challengeId = ""

    static func performAssertion(challenge: PasskeyChallenge) async throws -> AssertionResult {
        let coordinator = PasskeyCoordinator()
        return try await coordinator.run(challenge: challenge)
    }

    private func run(challenge: PasskeyChallenge) async throws -> AssertionResult {
        challengeId = challenge.challengeId
        guard let rpId = challenge.options.rpId else {
            throw Error.failed(URLError(.badURL))
        }
        let challengeData = Data(base64URLEncoded: challenge.options.challenge) ?? Data()
        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: rpId)
        let request = provider.createCredentialAssertionRequest(challenge: challengeData)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self

        return try await withCheckedThrowingContinuation { cont in
            continuation = cont
            controller.performRequests()
        }
    }

    // MARK: - ASAuthorizationControllerDelegate

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard
            let credential = authorization.credential
                as? ASAuthorizationPlatformPublicKeyCredentialAssertion
        else {
            continuation?.resume(throwing: Error.failed(URLError(.unknown)))
            return
        }

        let response = PasskeyAssertionResponse(
            id: credential.credentialID.base64URLEncodedString(),
            rawId: credential.credentialID.base64URLEncodedString(),
            type: "public-key",
            response: AssertionResponseData(
                clientDataJSON: credential.rawClientDataJSON.base64URLEncodedString(),
                authenticatorData: credential.rawAuthenticatorData.base64URLEncodedString(),
                signature: credential.signature.base64URLEncodedString(),
                userHandle: credential.userID?.base64URLEncodedString()
            )
        )
        continuation?.resume(returning: AssertionResult(challengeId: challengeId, response: response))
        continuation = nil
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Swift.Error
    ) {
        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
            continuation?.resume(throwing: Error.canceled)
        } else {
            continuation?.resume(throwing: Error.failed(error))
        }
        continuation = nil
    }

    // MARK: - ASAuthorizationControllerPresentationContextProviding

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .compactMap { $0.keyWindow }
            .first ?? ASPresentationAnchor()
    }
}
