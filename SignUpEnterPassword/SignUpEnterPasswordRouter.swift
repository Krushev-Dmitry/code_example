import Foundation

protocol SignUpEnterPasswordRouterProtocol: RouterProtocol {
    func showInvalidEmailScreen(data: ParameterProtocol?)
}

class SignUpEnterPasswordRouter: BaseRouter, SignUpEnterPasswordRouterProtocol {

    func showInvalidEmailScreen(data: ParameterProtocol?) {
        self.showViewModel(InvalidEmailViewModel.self, with: data, flow: nil, completion: nil)
    }
}
