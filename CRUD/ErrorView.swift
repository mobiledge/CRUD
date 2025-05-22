import SwiftUI

struct ErrorView: View {
    typealias ReentryAction = () -> Void
    
    private let vm: ErrorViewModel
    private let retryAction: ReentryAction?
    
    init(vm: ErrorViewModel, retryAction: ReentryAction? = nil) {
        self.vm = vm
        self.retryAction = retryAction
    }
    
    init(error: Error, retryAction: ReentryAction? = nil) {
        self.vm = ErrorViewModel(error: error)
        self.retryAction = retryAction
    }
    
    var body: some View {
        ContentUnavailableView {
            Label(vm.title, systemImage: vm.systemImageName)
        } description: {
            VStack(spacing: 8) {
                Text(vm.description)
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

#Preview("notConnectedToInternet") {
    ErrorView(
        error: URLError(.notConnectedToInternet),
        retryAction: {})
}

#Preview("timedOut") {
    ErrorView(
        error: URLError(.timedOut),
        retryAction: {})
}

#Preview("decodingKeyNotFound") {
    ErrorView(
        error: DecodingError.keyNotFound(
            CodingKeys.someKey, // Example CodingKey
            DecodingError.Context(
                codingPath: [],
                debugDescription: "Preview: Expected to find key 'someKey' but it was missing."
            )
        ),
        retryAction: {}
    )
}

#Preview("encodingInvalidValue") {
    ErrorView(
        error: EncodingError.invalidValue(
            "Invalid Character", // Example invalid value
            EncodingError.Context(
                codingPath: [CodingKeys.someKey], // Example CodingKey
                debugDescription: "Preview: An invalid value was provided for encoding."
            )
        ),
        retryAction: {}
    )
}

#Preview("httpErrorBadHTTPResponse") {
    ErrorView(
        error: HTTPError.badHTTPResponse,
        retryAction: {})
}

#Preview("httpErrorBadStatusCode404") {
    ErrorView(
        error: HTTPError.badStatusCode(404),
        retryAction: {})
}

#Preview("httpErrorBadStatusCode500") {
    ErrorView(
        error: HTTPError.badStatusCode(500),
        retryAction: {})
}

// Helper CodingKey for DecodingError and EncodingError previews
enum CodingKeys: String, CodingKey {
    case someKey
    case anotherKey
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

// MARK: - ErrorViewModel
struct ErrorViewModel {
    var title: LocalizedStringKey = "Something Went Wrong"
    var systemImageName: String = "exclamationmark.triangle"
    var description: LocalizedStringKey = "Something unexpected happened. Try again, or reach out if it keeps happening."
}

// MARK: - ErrorViewModel + Error & like
extension ErrorViewModel {
    init(error: Error) {
        if let urlError = error as? URLError {
            self = ErrorViewModel(urlError: urlError)
        } else if let decodingError = error as? DecodingError {
            self = ErrorViewModel(decodingError: decodingError)
        } else if let encodingError = error as? EncodingError {
            self = ErrorViewModel(encodingError: encodingError)
        } else if let httpError = error as? HTTPError {
            self = ErrorViewModel(httpError: httpError)
        } else {
            self = ErrorViewModel()
        }
    }
}

extension ErrorViewModel {
    init(urlError: URLError) {
        let title: LocalizedStringKey
        let imageName: String
        let description: LocalizedStringKey
        
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost:
            title = "No Internet Connection"
            imageName = "wifi.slash"
        default:
            title = "A Network Issue Occurred"
            imageName = "exclamationmark.icloud"
        }
        
        switch urlError.code {
        case .notConnectedToInternet:
            description = "Looks like you're not connected to the internet. Check your connection and try again."
        case .timedOut:
            description = "That took longer than expected. Give it another try in a moment."
        case .cannotFindHost:
            description = "Having trouble reaching our servers. Check your connection and try again."
        case .cannotConnectToHost:
            description = "Can't connect right now. We might be having some issues—try again in a bit."
        case .networkConnectionLost:
            description = "Your connection dropped while we were loading. Please try again."
        case .badURL, .unsupportedURL:
            description = "Something's wrong with this link. Let us know if you keep seeing this."
        case .cancelled:
            description = "No worries, you cancelled that."
        case .userCancelledAuthentication:
            description = "You cancelled signing in. No problem—try again whenever you're ready."
        case .userAuthenticationRequired:
            description = "You'll need to sign in first."
        case .secureConnectionFailed:
            description = "We're having trouble making a secure connection. Try again in a moment."
        case .serverCertificateHasBadDate, .serverCertificateUntrusted,
                .serverCertificateHasUnknownRoot, .serverCertificateNotYetValid:
            description = "There's a security issue on our end. Try again later or let us know if it keeps happening."
        case .cannotLoadFromNetwork, .dataNotAllowed:
            description = "Can't access the network right now. Check your settings and try again."
        default:
            description = "Something went wrong with your connection. Please try again."
        }
        self.init(title: title, systemImageName: imageName, description: description)
    }
}

extension ErrorViewModel {
    init(decodingError: DecodingError) {
        let description: LocalizedStringKey
        switch decodingError {
        case .keyNotFound:
            description = "We didn't get all the info we needed. Please try again."
        case .typeMismatch:
            description = "Something looks different than we expected. Please try again."
        case .valueNotFound:
            description = "Some information seems to be missing. Please try again."
        case .dataCorrupted:
            description = "The information got scrambled somehow. Please try again."
        @unknown default:
            description = "We're having trouble understanding the response. Please try again."
        }
        self.init(description: description)
    }
}

extension ErrorViewModel {
    init(encodingError: EncodingError) {
        let description: LocalizedStringKey
        switch encodingError {
        case .invalidValue:
            description = "Something doesn't look right with what you entered. Double-check and try again."
        @unknown default:
            description = "We're having trouble with your request. Please try again."
        }
        self.init(description: description)
    }
}

extension ErrorViewModel {
    init(httpError: HTTPError) {
        let imageName = "exclamationmark.icloud"
        let description: LocalizedStringKey

        switch httpError {
        case .badHTTPResponse:
            description = "We received an unexpected response from the server. Please try again, and if the problem continues, let us know."
        
        case .badStatusCode(let statusCode):
            switch statusCode {
            // 4xx Client Errors
            case 400:
                description = "Hmm, something wasn't quite right with that request. Could you try that again, perhaps checking for any typos?"
            case 401:
                description = "Looks like you need to be signed in for this. Please sign in and give it another go!"
            case 403:
                description = "It seems you don't have access to this particular spot. If you think this is a mistake, feel free to reach out to us."
            case 404:
                description = "Oops! We couldn't find what you were looking for. Maybe try searching again or double-check the link?"
            case 408:
                description = "That took a bit longer than expected. Your internet might be a bit slow, or our servers are busy. Please try again in a moment."
            case 429:
                description = "Whoa there! Looks like you're doing a lot at once. Please take a short break and then try again."
            
            // 5xx Server Errors
            case 500:
                description = "Uh oh, something went wrong on our side. We're already looking into it! Please try again in a little bit."
            case 501:
                description = "It seems the action you're trying to perform isn't available right now. We're always working on new things, so maybe check back later?"
            case 502:
                description = "We're having a little trouble connecting to one of our services. Please give it another try in a moment."
            case 503:
                description = "Our servers are a bit busy or undergoing maintenance right now. We should be back up shortly. Please try again soon!"
            case 504:
                description = "It seems we're waiting a long time for a response from our servers. This might be a temporary hiccup. Please try again in a moment."
            
            // Default for other client or server errors based on status code
            default:
                if (400..<500).contains(statusCode) {
                    description = "It looks like there was an issue with your request. Please double-check and try again. (Error code: \(statusCode))"
                } else if (500..<600).contains(statusCode) {
                    description = "We've hit a snag on our end. We're looking into it! Please try again later. (Error code: \(statusCode))"
                } else {
                    description = "An unexpected issue occurred while trying to connect. Please try again. (Error code: \(statusCode))"
                }
            }
        }
        self.init(systemImageName: imageName, description: description)
    }
}
