import Foundation
import LocalAuthentication

struct DeviceAuthenticationStatus: Equatable, Sendable {
    var isAvailable: Bool
    var methodDescription: String
    var unavailableReason: String?

    static let unavailable = DeviceAuthenticationStatus(
        isAvailable: false,
        methodDescription: DeviceAuthenticationClient.defaultMethodDescription,
        unavailableReason: "Device authentication is unavailable."
    )
}

enum DeviceAuthenticationResult: Equatable, Sendable {
    case success
    case failure(String)
}

struct DeviceAuthenticationClient: Sendable {
    var status: @Sendable () -> DeviceAuthenticationStatus
    var authenticate: @Sendable (_ reason: String) async -> DeviceAuthenticationResult
}

extension DeviceAuthenticationClient {
    static let live = DeviceAuthenticationClient(
        status: {
            let context = LAContext()
            var error: NSError?
            let isAvailable = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
            return DeviceAuthenticationStatus(
                isAvailable: isAvailable,
                methodDescription: methodDescription(for: context),
                unavailableReason: isAvailable ? nil : unavailableReason(from: error)
            )
        },
        authenticate: { reason in
            let context = LAContext()
            var error: NSError?

            guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
                return .failure(unavailableReason(from: error))
            }

            do {
                let authenticated = try await context.evaluatePolicy(
                    .deviceOwnerAuthentication,
                    localizedReason: reason
                )
                return authenticated
                    ? .success
                    : .failure("Authentication failed. Try again.")
            } catch let laError as LAError {
                return .failure(failureMessage(for: laError))
            } catch {
                let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                return .failure(
                    message.isEmpty
                        ? "Authentication failed. Try again."
                        : message
                )
            }
        }
    )

    static let noop = DeviceAuthenticationClient(
        status: { .unavailable },
        authenticate: { _ in
            .failure("Device authentication is unavailable.")
        }
    )

    static var defaultMethodDescription: String {
        #if os(macOS)
        "Touch ID or your Mac password"
        #else
        "Face ID, Touch ID, or your device passcode"
        #endif
    }

    private static func methodDescription(for context: LAContext) -> String {
        switch context.biometryType {
        case .faceID:
            return "Face ID or your device passcode"
        case .touchID:
            #if os(macOS)
            return "Touch ID or your Mac password"
            #else
            return "Touch ID or your device passcode"
            #endif
        default:
            #if os(macOS)
            return "your Mac password"
            #else
            return "your device passcode"
            #endif
        }
    }

    private static func unavailableReason(from error: NSError?) -> String {
        guard let laError = error as? LAError else {
            return "Set up device authentication before enabling app lock."
        }

        switch laError.code {
        case .passcodeNotSet:
            #if os(macOS)
            return "Set up a Mac password before enabling app lock."
            #else
            return "Set up a device passcode before enabling app lock."
            #endif
        case .biometryNotAvailable, .touchIDNotAvailable:
            return "Biometric authentication is unavailable on this device right now."
        case .biometryNotEnrolled, .touchIDNotEnrolled:
            #if os(macOS)
            return "Set up Touch ID or use your Mac password to enable app lock."
            #else
            return "Set up Face ID or Touch ID first, or make sure a device passcode is available."
            #endif
        case .notInteractive:
            return "Device authentication isn't available right now."
        default:
            let message = laError.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            return message.isEmpty
                ? "Set up device authentication before enabling app lock."
                : message
        }
    }

    private static func failureMessage(for error: LAError) -> String {
        switch error.code {
        case .authenticationFailed:
            return "Authentication failed. Try again."
        case .userCancel, .systemCancel, .appCancel:
            return "Authentication was canceled."
        case .biometryLockout, .touchIDLockout:
            return "Biometrics are locked. Unlock the device and try again."
        case .passcodeNotSet:
            #if os(macOS)
            return "Set up a Mac password before enabling app lock."
            #else
            return "Set up a device passcode before enabling app lock."
            #endif
        default:
            let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            return message.isEmpty
                ? "Authentication failed. Try again."
                : message
        }
    }
}
