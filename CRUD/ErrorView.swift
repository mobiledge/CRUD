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

    private func userFriendlyErrorMessage(from error: Error) -> String {
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
}

