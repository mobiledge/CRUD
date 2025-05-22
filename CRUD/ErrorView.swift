import SwiftUI

struct ErrorView: View {
    typealias ReentryAction = () -> Void
    
    let title: LocalizedStringKey
    let systemImage: String
    let description: LocalizedStringKey?
    let retryAction: ReentryAction?
    
    init(
        title: LocalizedStringKey = "Something went wrong",
        systemImage: String = "exclamationmark.triangle",
        description: LocalizedStringKey? = nil,
        retryAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.systemImage = systemImage
        self.description = description
        self.retryAction = retryAction
    }
    
    init(error: Error, retryAction: ReentryAction?) {
        self.init(
            title: error.displayTitle,
            systemImage: error.displaySystemImageName,
            description: error.displayDescription,
            retryAction: retryAction
        )
    }
    
    var body: some View {
        ContentUnavailableView {
            Label("Something went wrong", systemImage: "exclamationmark.triangle")
        } description: {
            VStack(spacing: 8) {
                Text(title)
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

extension Error {
    var displayTitle: LocalizedStringKey {
        if let urlError = self as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return "No Internet Connection"
            default:
                return "A Network Issue Occurred"
            }
        }
        return "Something Went Wrong"
    }
    
    var displaySystemImageName: String {
        if let urlError = self as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return "wifi.slash"
            default:
                return "exclamationmark.icloud"
            }
        }
        return "exclamationmark.triangle"
    }
    
    var displayDescription: LocalizedStringKey {
        if let urlError = self as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return "Looks like you're not connected to the internet. Check your connection and try again."
            case .timedOut:
                return "That took longer than expected. Give it another try in a moment."
            case .cannotFindHost:
                return "Having trouble reaching our servers. Check your connection and try again."
            case .cannotConnectToHost:
                return "Can't connect right now. We might be having some issues—try again in a bit."
            case .networkConnectionLost:
                return "Your connection dropped while we were loading. Please try again."
            case .badURL, .unsupportedURL:
                return "Something's wrong with this link. Let us know if you keep seeing this."
            case .cancelled:
                return "No worries, you cancelled that."
            case .userCancelledAuthentication:
                return "You cancelled signing in. No problem—try again whenever you're ready."
            case .userAuthenticationRequired:
                return "You'll need to sign in first."
            case .secureConnectionFailed:
                return "We're having trouble making a secure connection. Try again in a moment."
            case .serverCertificateHasBadDate, .serverCertificateUntrusted,
                    .serverCertificateHasUnknownRoot, .serverCertificateNotYetValid:
                return "There's a security issue on our end. Try again later or let us know if it keeps happening."
            case .cannotLoadFromNetwork, .dataNotAllowed:
                return "Can't access the network right now. Check your settings and try again."
            default:
                return "Something went wrong with your connection. Please try again."
            }
        }
        
        if let decodingError = self as? DecodingError {
            switch decodingError {
            case .keyNotFound:
                return "We didn't get all the info we needed. Please try again."
            case .typeMismatch:
                return "Something looks different than we expected. Please try again."
            case .valueNotFound:
                return "Some information seems to be missing. Please try again."
            case .dataCorrupted:
                return "The information got scrambled somehow. Please try again."
            @unknown default:
                return "We're having trouble understanding the response. Please try again."
            }
        }
        
        if let encodingError = self as? EncodingError {
            switch encodingError {
            case .invalidValue:
                return "Something doesn't look right with what you entered. Double-check and try again."
            @unknown default:
                return "We're having trouble with your request. Please try again."
            }
        }
        
        return "Something unexpected happened. Try again, or reach out if it keeps happening."
    }
}

struct UserFriendlyErrorDisplayInfo {
    static let defaultDisplayTitle: LocalizedStringKey = "Something Went Wrong"
    static let defaultDisplaySystemImageName: String = "exclamationmark.triangle"
    static let defaultDisplayDescription: LocalizedStringKey = "Something unexpected happened. Try again, or reach out if it keeps happening."
    
    let displayTitle: LocalizedStringKey
    let displaySystemImageName: String
    let displayDescription: LocalizedStringKey

    init(
        displayTitle: LocalizedStringKey = Self.defaultDisplayTitle,
        displaySystemImageName: String = Self.defaultDisplaySystemImageName,
        displayDescription: LocalizedStringKey = Self.defaultDisplayDescription
    ) {
        self.displayTitle = displayTitle
        self.displaySystemImageName = displaySystemImageName
        self.displayDescription = displayDescription
    }
}

extension Error {
    var userFriendlyDisplayInfo: UserFriendlyErrorDisplayInfo {
        if let urlError = self as? URLError {
            return UserFriendlyErrorDisplayInfo(urlError: urlError)
        }
        if let decodingError = self as? DecodingError {
            return UserFriendlyErrorDisplayInfo(decodingError: decodingError)
        }
        if let encodingError = self as? EncodingError {
            return UserFriendlyErrorDisplayInfo(encodingError: encodingError)
        }
        return UserFriendlyErrorDisplayInfo()
    }
}

extension UserFriendlyErrorDisplayInfo {
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
        self.init(displayTitle: title, displaySystemImageName: imageName, displayDescription: description)
    }
}

extension UserFriendlyErrorDisplayInfo {
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
        self.init(displayDescription: description)
    }
}

extension UserFriendlyErrorDisplayInfo {
    init(encodingError: EncodingError) {
        
        let description: LocalizedStringKey

        switch encodingError {
        case .invalidValue:
            description = "Something doesn't look right with what you entered. Double-check and try again."
        @unknown default:
            description = "We're having trouble with your request. Please try again."
        }
        self.init(displayDescription: description)
    }
}
