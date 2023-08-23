import RxSwift
import RxRelay
import RxCocoa

class SignUpEnterPasswordViewModel: BaseViewModel {

    enum ErrorType {
        case security
        case match
    }

    var router: SignUpEnterPasswordRouterProtocol!

    private let credentialsManager = CredentialsManager.shared
    private var userCredentials: CredentialsManager.Credentials?

    private let registerService: RegisterNetworkServiceProtocol = NetworkManagerServices.shared.registerService
    private let userPropertiesService: UserPropertiesNetworkServiceProtocol = NetworkManagerServices.shared.userPropertiesService

    private var sectionViewModels = BehaviorRelay<[SectionViewModel]>(value: [])
    var sectionViewModelsDriver: Driver<[SectionViewModel]> {
        return sectionViewModels.asDriver()
    }

    private let isValid = BehaviorRelay<Bool>(value: false)
    var isValidDriver: Driver<Bool> { return  isValid.asDriver()}
    
    let isError = BehaviorRelay<Bool>(value: false)
    var isErrorDriver: Driver<Bool> { return  isError.asDriver()}
    let isConfirmationError = BehaviorRelay<Bool>(value: false)
    var isConfirmationErrorDriver: Driver<Bool> { return  isConfirmationError.asDriver()}

    // MARK: - In

    let password = BehaviorRelay<String>(value: "")
    let confirmPassword = BehaviorRelay<String>(value: "")
    var tempPassword = ""
    var tempConfirmPassword = ""

    let error = BehaviorRelay<String>(value: "")
    let isSelect = BehaviorRelay<Bool>(value: true)
    let submitEmail = PublishRelay<Void>()
    let closeCommand = PublishRelay<Void>()
    let showPasswordRequirements = BehaviorRelay<Bool>.init(value: false)

    // MARK: - Out
    let sendButtonTitle = BehaviorRelay<String>(value: "common_continue".localized())
    let requirements = BehaviorRelay<String>(value: "sign_up_password_step_requirements".localized())

    @Localized var cancelButtonTitle = "common_close"

    var titleRow: TwoTitleRowViewModel {
        get {
            let rowTitle = BehaviorRelay<String>(value: "sign_up_password_step_title".localized("Set a password"))
            let rowSecondTitle = BehaviorRelay<String>(value: "sign_up_password_step_second_title".localized("Set a password..."))
            let row = TwoTitleRowViewModel(title: rowTitle, second: rowSecondTitle)
            return row
        }
    }

    private(set) lazy var passwordRow: UserInfoItemPlaceholderRowViewModel = {
        let row = UserInfoItemPlaceholderRowViewModel(customInfo: UserInfoItemPlaceholderRowViewModel.CustomInfo(
                                                        name: "",
                                                        placeHolder: "sign_up_password_step_password_hint".localized(),
                                                        inputType: .password,
                                                        value: password.value,
                                                        isError: isErrorDriver),
                                                      warningMessage: nil,
                                                      validation: .init())
        row.validationAction = { [unowned self] input -> Bool in
            self.password.accept(input)
            switch (self.showPasswordRequirements.value, input.count) {
            case (false, 0):
                self.showPasswordRequirements.accept(false)
            case ( _, 8... ):
                self.showPasswordRequirements.accept(!input.checkPasswordRequirements())
            default:
                self.showPasswordRequirements.accept(true)
            }
            return true
        }
        return row
    }()

    private(set) lazy var confirmPasswordRow: UserInfoItemPlaceholderRowViewModel = {
        let row = UserInfoItemPlaceholderRowViewModel(customInfo: UserInfoItemPlaceholderRowViewModel.CustomInfo(
                                                        name: "",
                                                        placeHolder: "sign_up_password_step_confirm_password_hint".localized(),
                                                        inputType: .password,
                                                        value: confirmPassword.value,
                                                        isError: isConfirmationErrorDriver),
                                          warningMessage: error)
            row.validationAction = { [weak self] input -> Bool in
                self?.confirmPassword.accept(input)
            return true
        }
        return row
    }()
    
    private(set) lazy var passwordRequirementsRow: PasswordRequirementsRowViewModel = {
        let row = PasswordRequirementsRowViewModel(title: requirements)
        return row
    }()

    // MARK: Setup

    init(router: SignUpEnterPasswordRouterProtocol) {
        self.router = router
        super.init()
        
        #if DEBUG && DEV_TARGET
        password.accept("Welcome1!")
        confirmPassword.accept("Welcome1!")
        isSelect.accept(true)
        isValid.accept(true)
        #endif
    }
    
    override func prepare(with parameter: ParameterProtocol?) {
        if let credentials = parameter as? CredentialsManager.Credentials {
            self.userCredentials = credentials
        }
        self.setupViewModels()
    }
    
    func setupRows(needError: Bool) {
        var rows: [BaseRowViewModel] = [titleRow,
                                        passwordRow,
                                        confirmPasswordRow,
                                        passwordRequirementsRow]
        
        let section = SectionViewModel(viewModels: rows)
        var sections: [SectionViewModel] = []
        sections.append(section)
        sectionViewModels.accept(sections)
    }

    func setupViewModels() {
        self.setupRows(needError: false)
        
        closeCommand.subscribe(onNext: { [weak self] in
            guard let self = self else { return }
            self.router.breakFlow(self)
        }).disposed(by: disposeBag)

        submitEmail.subscribe(onNext: { [weak self] in
            Event.logClickEvent("next")
            guard let self = self else { return }
            self.sendPassword()
        }).disposed(by: disposeBag)
        
        showPasswordRequirements
            .withPrevious()
            .subscribe(onNext: { [weak self] previous, new in
            if previous != new {
                self?.passwordRequirementsRow.hideCell(!new)
            }
        }).disposed(by: disposeBag)
                
        Observable.combineLatest(password, confirmPassword)
            .subscribe(onNext: { [weak self] password, confirmPassword in
                guard let self = self else { return }
                if self.isConfirmationError.value,
                   self.tempPassword != password
                    || self.tempConfirmPassword != confirmPassword {
                    self.isError.accept(false)
                }

                self.isValid.accept(password.count >= 8
                                    && confirmPassword.count >= 1
                                    && password.checkPasswordRequirements()
                                    && !self.isConfirmationError.value)
                self.tempPassword = password
                self.tempConfirmPassword = confirmPassword
            }).disposed(by: disposeBag)
        
        isError.subscribe(onNext: { [weak self] isError in
            self?.isConfirmationError.accept(isError)
        }).disposed(by: disposeBag)
        
        isConfirmationError.subscribe(onNext: { [weak self] isError in
            guard let self = self, isError else { return }
            self.isValid.accept(false)
        }).disposed(by: disposeBag)
    }

    func sendPassword() {
        if password.value != confirmPassword.value {
            self.showError(.match)
            return
        }

        if let email = self.userCredentials?.email {
            self.isBlockingLoading.accept(true)
            self.registerService.createUser(email: email,
                                            password: self.password.value) { [weak self]  result in
                guard let self = self else { return }
                self.isBlockingLoading.accept(false)
                switch result {
                case .success(let response):
                    SessionManager.shared.set(response: response)
                    let loginParameters = LoginParameters(email: email,
                                                          password: self.password.value,
                                                          backButtonIsHidden: true)
                    AppManager.shared.observeNotificationsStatus(needUpdateStatus: true)
                    self.updateUserLanguagePropertie(completion: { [weak self] in
                        guard let self = self else { return }
                        self.router.next(self, with: loginParameters)
                    })
                case .failure(let error):
                    if let alviereError = error.alviere {
                        switch alviereError.reasonCode {
                        case "5", "6":
                            /// checking for duplicate account
                            /// move to auth screen with notification
                            let signUpState = SignUpState(userEmail: email,
                                                          isExistingUser: true)
                            self.router.next(self, with: signUpState)
                            
                        case "8":
                            let params = InvalidEmailParams { [weak self] in
                                guard let self = self else { return }
                                self.router.remove(self)
                            }
                            self.router.showInvalidEmailScreen(data: params)
                            
                        case "9", "11":
                            ///checking for invalid password
                            self.showError(.security)
                            
                        default:
                            self.displayInfoError.accept(.init(error: error))
                        }
                    } else {
                        self.displayInfoError.accept(.init(error: error))
                    }
                }
            }
        }
    }

    func showError(_ errorType: ErrorType) {
        switch errorType {
        case .security:
            self.error.accept("sign_up_password_step_security_error".localized())
            self.isError.accept(true)
        case .match:
            self.error.accept("sign_up_password_step_not_match_error".localized())
            self.isConfirmationError.accept(true)
        }
    }

    private func updateUserLanguagePropertie(completion: @escaping () -> Void) {
        guard let userUuid = SessionManager.shared.userData?.userUuid else { return }
        let language = LocalizationManager.shared.localeKey

        self.isBlockingLoading.accept(true)
        self.userPropertiesService.updateUserPropertiesEx(userUuid: userUuid,
                                                          language: language) { [weak self] result in
            self?.isBlockingLoading.accept(false)
            switch result {
            case .success(let response):
                SessionManager.shared.setUserProperties(response?.userProperties)
            case .failure: break
            }
            completion()
        }
    }
}
