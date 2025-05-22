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
