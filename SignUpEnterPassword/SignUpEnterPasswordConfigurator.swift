import Foundation

struct InvalidEmailParams: ParameterProtocol {
    let callback: (() -> Void)?
}

final class SignUpEnterPasswordConfigurator: ConfiguratorProtocol {
    
    func configure(withData: ParameterProtocol?, navigationService: NavigationServiceProtocol?, flow: FlowProtocol?) -> MVVMPair {
        let viewController = SignUpEnterPasswordViewController()
        let router = SignUpEnterPasswordRouter(navigationService: navigationService!, flow: flow)
        let viewModel = SignUpEnterPasswordViewModel(router: router)
        viewModel.prepare(with: withData)
        viewController.setup(viewModel: viewModel)
        return (viewController, viewModel)
    }
}
