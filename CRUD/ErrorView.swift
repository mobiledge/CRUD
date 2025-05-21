import SwiftUI

struct ErrorView: View {
    let error: Error
    let retryAction: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label("Something went wrong", systemImage: "exclamationmark.triangle")
        } description: {
            VStack(spacing: 8) {
                Text(userFriendlyErrorMessage(from: error))
                    .multilineTextAlignment(.center)
                if let retry = retryAction {
                    Button("Try Again", action: retry)
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 8)
                }
            }
        }
    }
}

struct ErrorAlertModifier: ViewModifier {
    @Binding var error: Error?
    let tryAgainAction: (() -> Void)?

    private var isPresenting: Binding<Bool> {
        Binding(
            get: { error != nil },
            set: { if !$0 { error = nil } }
        )
    }

    private var alertTitle: Text {
        Text("Error")
    }

    private var alertMessage: Text {
        Text(error?.localizedDescription ?? "Something went wrong.")
    }

    private var primaryButton: Alert.Button {
        if let tryAgainAction = tryAgainAction {
            return .default(Text("Try Again"), action: tryAgainAction)
        } else {
            return .default(Text("OK"))
        }
    }

    private var secondaryButton: Alert.Button? {
        tryAgainAction != nil ? .cancel(Text("Cancel")) : nil
    }

    func body(content: Content) -> some View {
        content.alert(isPresented: isPresenting) {
            if let secondary = secondaryButton {
                return Alert(
                    title: alertTitle,
                    message: alertMessage,
                    primaryButton: primaryButton,
                    secondaryButton: secondary
                )
            } else {
                return Alert(
                    title: alertTitle,
                    message: alertMessage,
                    dismissButton: primaryButton
                )
            }
        }
    }
}

extension View {
    func errorAlert(error: Binding<Error?>, tryAgainAction: (() -> Void)? = nil) -> some View {
        self.modifier(ErrorAlertModifier(error: error, tryAgainAction: tryAgainAction))
    }
}


// Error formatting function
private func userFriendlyErrorMessage(from error: Error?) -> String {
    guard let error = error else {
        return "An internal error occurred. Please try again."
    }
    if let urlError = error as? URLError {
        switch urlError.code {
        case .notConnectedToInternet:
            return "You appear to be offline. Please check your internet connection."
        case .timedOut:
            return "The request took too long. Try again in a moment."
        case .cannotFindHost:
            return "The server could not be found."
        case .cannotConnectToHost:
            return "Unable to connect to the server."
        case .networkConnectionLost:
            return "Your connection was lost during the request."
        case .badURL, .unsupportedURL:
            return "There was an issue with the request URL."
        default:
            return "A network error occurred. Please try again."
        }
    }

    if let decodingError = error as? DecodingError {
        switch decodingError {
        case .keyNotFound(let key, _):
            return "We’re missing some data: \(key.stringValue)."
        case .typeMismatch(_, _):
            return "There was a problem with the data format."
        case .valueNotFound(_, _):
            return "Some expected data was missing."
        case .dataCorrupted(let context):
            return "Corrupted data received: \(context.debugDescription)"
        @unknown default:
            return "An unknown error occurred while reading data."
        }
    }

    return error.localizedDescription
}
