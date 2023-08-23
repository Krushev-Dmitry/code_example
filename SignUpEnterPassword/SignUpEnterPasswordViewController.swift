import UIKit

class SignUpEnterPasswordViewController: BoostViewController<SignUpEnterPasswordViewModel> {

    override var screenName: String? { "omni-onboarding-password" }
    
    private var buttonConstraint: NSLayoutConstraint?
    
    private lazy var tableView: MVVMTableView = {
        let table = MVVMTableView(frame: .zero, style: .grouped)
        table.backgroundColor = .clear
        table.separatorStyle = .none
        
        table.register(UserInfoItemTableViewCell.self, forCellReuseIdentifier: UserInfoItemRowViewModel.className)
        table.register(UserInfoItemPlaceholderTableViewCell.self, forCellReuseIdentifier: UserInfoItemPlaceholderRowViewModel.className)
        table.register(PasswordRequirementsTableViewCell.self, forCellReuseIdentifier: PasswordRequirementsRowViewModel.className)
        table.register(WarningUnderTextFieldTableViewCell.self, forCellReuseIdentifier: WarningUnderTextFieldRowViewModel.className)
        table.register(SettingsSwitchTableViewCell.self, forCellReuseIdentifier: SettingsSwithRowViewModel.className)
        table.register(TwoTitleTableViewCell.self, forCellReuseIdentifier: TwoTitleRowViewModel.className)
        table.register(ErrorTableViewCell.self, forCellReuseIdentifier: ErrorRowViewModel.className)
        table.register(SignInSwitchRowTableViewCell.self, forCellReuseIdentifier: SignInSwitchRowViewModel.className)
        
        table.sectionHeaderHeight = 0.1
        table.shouldIgnoreContentInsetAdjustment = true
        return table
    }()

    private lazy var cancelButtomItem: UIBarButtonItem = {
        let item = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        item.tintColor = ColorManager.navigationBarTintColor
        return item
    }()

    private lazy var nextButton: RoundedButton = {
        let button = RoundedButton()
        return button
    }()
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewModel.passwordRow.cellTapRelay.accept(())
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.view.endEditing(true)
    }
  
    override func setupUI() {
        super.setupUI()
        
        view.backgroundColor = ColorManager.systemBackground
        self.tableView.tableFooterView = UIView(frame: CGRect(x: 0,
                                                              y: 0,
                                                              width: UIScreen.main.bounds.width,
                                                              height: 1))
        view.add(tableView, nextButton)
        tableView.makeLayout {
            $0.top.equalToSuperView()
            $0.leading.equalToSuperView()
            $0.trailing.equalToSuperView()
            $0.bottom.equalTo(nextButton.sl.top).offset(8)
        }
        let size = UIScreen.main.bounds
        let buttonHeight = size.height * 0.06
        
        nextButton.makeLayout {
            self.buttonConstraint = $0.bottom.equalToSuperView().offset(Constants.bottomPadding).getConstraint()
            $0.trailing.equalToSuperView().offset(Constants.trailingPadding)
            $0.leading.equalToSuperView().offset(Constants.leadingPadding)
            $0.height.equalTo(buttonHeight)
        }
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillShow(_:)),
                                               name: UIResponder.keyboardWillShowNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillHide(_:)),
                                               name: UIResponder.keyboardWillHideNotification,
                                               object: nil)
   
    }

    override func setupBinding() {
        super.setupBinding()
        
        // MARK: appearance
        viewModel.sectionViewModelsDriver.drive(tableView.dataSourceMVVM).disposed(by: disposeBag)
        viewModel.$cancelButtonTitle.drive(cancelButtomItem.rx.title).disposed(by: disposeBag)
        viewModel.sendButtonTitle.asDriver().drive(nextButton.rx.title()).disposed(by: disposeBag)
        
        // MARK: input
        viewModel.isValidDriver.drive(onNext: { [weak self] newValue in
            guard let self = self else { return }
            self.nextButton.isEnabled = newValue
        }).disposed(by: disposeBag)
        cancelButtomItem.rx.tap.bind(to: viewModel.closeCommand).disposed(by: disposeBag)
        nextButton.rx.tap.asDriver().drive(onNext: { [weak self] _ in
            self?.view.endEditing(true)
            self?.viewModel.submitEmail.accept(())
        }).disposed(by: disposeBag)
    }

    @objc func keyboardWillShow(_ notification: Notification) {
        let userInfo = notification.userInfo
        guard let keyboardSize = userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        let keyboardHeight = keyboardSize.cgRectValue.height
        buttonConstraint?.constant = -8 - keyboardHeight

        guard let animationDuration = userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }
        UIView.animate(withDuration: animationDuration) {
            self.view.layoutIfNeeded()
        }
    }

    @objc func keyboardWillHide(_ notification: Notification) {
        buttonConstraint?.constant = -Constants.bottomPadding

        let userInfo = notification.userInfo
        guard let animationDuration = userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }
        UIView.animate(withDuration: animationDuration) {
            self.view.layoutIfNeeded()
        }
    }
}
