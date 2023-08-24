import CoreLocation
import UIKit

protocol LocationManagerDelegate: AnyObject {
    func locationManager(_ manager: LocationManagerProtocol, didChangeAuthorizationStatus granted: Bool)
    func locationManager(_ manager: LocationManagerProtocol, didChangeLocation location: Location)
    func locationManager(_ manager: LocationManagerProtocol, failWithError error: Error)
    func locationManager(presentingControllerFor locationManager: LocationManagerProtocol) -> UIViewController?
}

protocol LocationManagerProtocol: AnyObject {
    typealias CompletionBlock = (Location?, Error?) -> Void

    var delegate: LocationManagerDelegate? { get set }
    var location: Location? { get }
    var statusGranted: Bool { get }

    func startMonitoringLocation(notification: Bool)
    func stopMonitoringLocation()
    func registerLocationListener(with key: AnyObject, listener: @escaping CompletionBlock)
}

class LocationManager: NSObject, LocationManagerProtocol {
    enum Constants {
        static let locationStorageKey = "LocationManagerLocationStorageKey"
    }

    private class ClosureStorage {
        let closure: CompletionBlock

        init(closure: @escaping CompletionBlock) {
            self.closure = closure
        }
    }

    weak var delegate: LocationManagerDelegate?

    private let locationManager = CLLocationManager()
    private let settingsPath = UIApplication.openSettingsURLString
    private let storage: StorageProtocol

    private let blocksMapTable = NSMapTable<AnyObject, ClosureStorage>.weakToStrongObjects()

    private var locationListeners: [CompletionBlock] {
        if let enumerator = blocksMapTable.objectEnumerator() {
            return enumerator.allObjects.compactMap { object -> CompletionBlock? in
                if let storage = object as? ClosureStorage {
                    return storage.closure
                } else {
                    return nil
                }
            }
        }

        return []
    }

    var location: Location? {
        if let location = locationManager.location?.coordinate {
            return .init(latitude: location.latitude, longitude: location.longitude)
        } else if let location = storedLocation {
            return location
        }

        return nil
    }

    var storedLocation: Location? {
        get {
            try? storage.retrieve(for: Constants.locationStorageKey)
        }
        set {
            if let value = newValue {
                try? storage.save(data: value, key: Constants.locationStorageKey)
            } else {
                storage.reset(key: Constants.locationStorageKey)
            }
        }
    }

    var statusGranted: Bool {
        switch CLLocationManager.authorizationStatus() {
        case .authorizedAlways, .authorizedWhenInUse:
            return true
        default:
            return false
        }
    }

    // MARK: - Initialization

    init(storage: StorageProtocol) {
        self.storage = storage
        super.init()

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    // MARK: - LocationManagerProtocol

    func startMonitoringLocation(notification: Bool) {
        switch CLLocationManager.authorizationStatus() {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.startMonitoringSignificantLocationChanges()
            locationManager.requestLocation()
            notifyDelegate(with: CLLocationManager.authorizationStatus())
        case .denied:
            if notification {
                showOpenSettingsAlert()
            }
        case .restricted:
            if notification {
                showRestrictAlert()
            }
        @unknown default:
            fatalError("Not implemented")
        }
    }

    func stopMonitoringLocation() {
        locationManager.stopMonitoringSignificantLocationChanges()
    }

    func openSettings() {
        guard let url = URL(string: settingsPath) else {
            return
        }

        UIApplication.shared.open(url, options: [:], completionHandler: { _ in })
    }

    func registerLocationListener(with key: AnyObject, listener: @escaping CompletionBlock) {
        if let location = location {
            listener(location, nil)
        } else {
            blocksMapTable.setObject(ClosureStorage(closure: listener), forKey: key)
        }
    }
}

extension LocationManager {
    // MARK: - Private

    private func showOpenSettingsAlert() {
        guard let controller = delegate?.locationManager(presentingControllerFor: self) else {
            return
        }

        let alert = AlertController()
        alert.data = AlertData(title: L10n.Location.alertDeniedStatusTitle, message: L10n.Location.alertDeniedStatusMessage)

        alert.addActions(
            [
                AlertAction(title: L10n.Alert.buttonNo, style: .default, handler: { [weak self] in
                    self?.notifyDelegate(with: CLLocationManager.authorizationStatus())
                }),
                AlertAction(title: L10n.Alert.buttonYes, style: .default, handler: { [weak  self] in
                    self?.openSettings()
                })
            ]
        )

        controller.present(alert, animated: true)
    }

    private func showRestrictAlert() {
        guard let controller = delegate?.locationManager(presentingControllerFor: self) else {
            return
        }

        let alert = AlertController()
        alert.data = AlertData(title: L10n.Location.alertRestrictStatusTitle, message: L10n.Location.alertRestrictStatusMessage)

        alert.addActions(
            [
                AlertAction(title: L10n.Alert.buttonAccessibly, style: .default, handler: nil),
            ]
        )

        controller.present(alert, animated: true)
    }

    private func notifyDelegate(with status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            delegate?.locationManager(self, didChangeAuthorizationStatus: true)
        case .denied, .restricted:
            delegate?.locationManager(self, didChangeAuthorizationStatus: false)
        default:
            break
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        log.debug("Location manager change authorization status")
        AnalyticsManager.updateUserData()

        if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.startMonitoringSignificantLocationChanges()
            locationManager.requestLocation()
        }

        notifyDelegate(with: status)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else {
            return
        }

        let location = Location(coordinate)
        storedLocation = location

        locationListeners.forEach {
            $0(location, nil)
        }

        blocksMapTable.removeAllObjects()
        delegate?.locationManager(self, didChangeLocation: location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationListeners.forEach {
            $0(nil, error)
        }

        blocksMapTable.removeAllObjects()
        delegate?.locationManager(self, failWithError: error)
    }
}
