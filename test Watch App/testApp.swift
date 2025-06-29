import SwiftUI
import CoreMotion
import WatchKit
import UserNotifications
import CoreLocation
import MapKit

@main
struct ActivityDetectorApp: App {
    @StateObject private var activityManager = ActivityManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(activityManager)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var activityManager: ActivityManager
    
    var body: some View {
        VStack(spacing: 15) {
            if activityManager.showingSummary {
                SummaryView()
                    .environmentObject(activityManager)
            } else if activityManager.isActivityConfirmed {
                ActiveSessionView()
                    .environmentObject(activityManager)
            } else {
                MonitoringView()
                    .environmentObject(activityManager)
            }
        }
        .padding()
        .onAppear {
            activityManager.requestPermissions()
        }
        .alert("Wykryto Aktywność", isPresented: $activityManager.showingActivityAlert) {
            Button("Start") {
                activityManager.confirmActivity()
            }
            Button("Anuluj") {
                activityManager.dismissActivity()
            }
        } message: {
            Text("Czy chcesz rozpocząć aktywność?")
        }
    }
}

struct MonitoringView: View {
    @EnvironmentObject var activityManager: ActivityManager
    
    var body: some View {
        VStack(spacing: 15) {
            Text("Monitor Aktywności")
                .font(.headline)
            
            Text(activityManager.isMonitoring ? "Monitorowanie..." : "Dotknij aby rozpocząć")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Show background session status
            if activityManager.isMonitoring {
                Text("Status: \(activityManager.backgroundSessionStatus)")
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                if activityManager.isMonitoring {
                    activityManager.stopMonitoring()
                } else {
                    activityManager.startMonitoring()
                }
            }) {
                Image(systemName: activityManager.isMonitoring ? "stop.circle" : "play.circle")
                    .font(.title)
                    .foregroundColor(activityManager.isMonitoring ? .red : .green)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

struct ActiveSessionView: View {
    @EnvironmentObject var activityManager: ActivityManager
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Aktywność")
                .font(.headline)
                .foregroundColor(.green)
            
            // Stats Display
            HStack(spacing: 20) {
                VStack {
                    Text(String(format: "%.0f m", activityManager.totalDistance))
                        .font(.title3)
                        .bold()
                    Text("Dystans")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text(activityManager.formattedDuration)
                        .font(.title3)
                        .bold()
                    Text("Czas")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Trash Counter - Simple layout with just number and trash can with plus
            HStack(spacing: 10) {
                Text("\(activityManager.trashCount)")
                    .font(.title2)
                    .bold()
                
                Button(action: {
                    activityManager.incrementTrash()
                }) {
                    ZStack {
                        Image(systemName: "trash.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                        
                        Image(systemName: "plus")
                            .font(.caption)
                            .foregroundColor(.white)
                            .offset(x: 0, y: -2)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Control Buttons
            HStack(spacing: 15) {
                Button(action: {
                    activityManager.pauseActivity()
                }) {
                    Image(systemName: activityManager.isPaused ? "play.circle" : "pause.circle")
                        .font(.title2)
                        .foregroundColor(.orange)
                }
                
                Button(action: {
                    activityManager.endActivity()
                }) {
                    Image(systemName: "stop.circle")
                        .font(.title2)
                        .foregroundColor(.red)
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

struct SummaryView: View {
    @EnvironmentObject var activityManager: ActivityManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("Podsumowanie")
                    .font(.headline)
                    .foregroundColor(.blue)
                
                // Stats Grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    StatCard(
                        title: "Kroki",
                        value: "\(activityManager.totalSteps)",
                        icon: "figure.walk",
                        color: .blue
                    )
                    
                    StatCard(
                        title: "Dystans",
                        value: String(format: "%.0f m", activityManager.totalDistance),
                        icon: "location",
                        color: .green
                    )
                    
                    StatCard(
                        title: "Czas",
                        value: activityManager.formattedDuration,
                        icon: "clock",
                        color: .orange
                    )
                    
                    StatCard(
                        title: "Śmieci",
                        value: "\(activityManager.trashCount)",
                        icon: "trash",
                        color: .red
                    )
                }
                
                // Map View
                if !activityManager.pathPoints.isEmpty {
                    VStack(spacing: 6) {
                        Text("Twoja trasa")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        RouteMapView(
                            pathPoints: activityManager.pathPoints,
                            trashLocations: activityManager.trashLocations
                        )
                        .frame(height: 120)
                        .cornerRadius(8)
                    }
                }
                
                // Action Buttons
                HStack(spacing: 20) {
                    Button("Nowa Aktywność") {
                        activityManager.startNewActivity()
                    }
                    .font(.caption)
                    .foregroundColor(.green)
                    
                    Button("Powrót") {
                        activityManager.closeSummary()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            
            Text(value)
                .font(.caption)
                .bold()
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(6)
    }
}

struct RouteMapView: View {
    let pathPoints: [CLLocationCoordinate2D]
    let trashLocations: [CLLocationCoordinate2D]
    
    var body: some View {
        Map(coordinateRegion: .constant(mapRegion), annotationItems: annotations) { item in
            MapAnnotation(coordinate: item.coordinate) {
                if item.isTrash {
                    Image(systemName: "trash.fill")
                        .foregroundColor(.red)
                        .font(.caption2)
                } else {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 4, height: 4)
                }
            }
        }
        .disabled(true) // Disable interaction on small watch screen
    }
    
    private var mapRegion: MKCoordinateRegion {
        guard !pathPoints.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
        
        let latitudes = pathPoints.map { $0.latitude }
        let longitudes = pathPoints.map { $0.longitude }
        
        let minLat = latitudes.min() ?? 0
        let maxLat = latitudes.max() ?? 0
        let minLon = longitudes.min() ?? 0
        let maxLon = longitudes.max() ?? 0
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        let span = MKCoordinateSpan(
            latitudeDelta: max(maxLat - minLat, 0.01) * 1.2,
            longitudeDelta: max(maxLon - minLon, 0.01) * 1.2
        )
        
        return MKCoordinateRegion(center: center, span: span)
    }
    
    private var annotations: [MapAnnotationItem] {
        var items: [MapAnnotationItem] = []
        
        // Add path points
        for (index, point) in pathPoints.enumerated() {
            items.append(MapAnnotationItem(
                id: "path_\(index)",
                coordinate: point,
                isTrash: false
            ))
        }
        
        // Add trash locations
        for (index, trash) in trashLocations.enumerated() {
            items.append(MapAnnotationItem(
                id: "trash_\(index)",
                coordinate: trash,
                isTrash: true
            ))
        }
        
        return items
    }
}

struct MapAnnotationItem: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let isTrash: Bool
}

class ActivityManager: NSObject, ObservableObject {
    private let motionManager = CMMotionManager()
    private let pedometer = CMPedometer()
    private let locationManager = CLLocationManager()
    private var backgroundTask: WKExtendedRuntimeSession?
    
    @Published var isMonitoring = false
    @Published var showingActivityAlert = false
    @Published var isActivityConfirmed = false
    @Published var isPaused = false
    @Published var showingSummary = false
    
    // Activity metrics
    @Published var totalDistance: Double = 0.0
    @Published var totalSteps: Int = 0
    @Published var trashCount: Int = 0
    @Published var sessionStartTime: Date?
    @Published var sessionDuration: TimeInterval = 0
    @Published var formattedDuration: String = "00:00"
    @Published var backgroundSessionStatus: String = "Aktywne"
    
    // Location tracking
    @Published var pathPoints: [CLLocationCoordinate2D] = []
    @Published var trashLocations: [CLLocationCoordinate2D] = []
    
    private var stepCountThreshold: Double = 10
    private var timeWindow: TimeInterval = 30.0
    private var lastStepCount: Int = 0
    private var monitoringTimer: Timer?
    private var durationTimer: Timer?
    private var lastLocation: CLLocation?
    
    override init() {
        super.init()
        setupNotifications()
        setupLocationManager()
    }
    
    func requestPermissions() {
        // Request motion permissions
        if CMPedometer.isStepCountingAvailable() {
            // Permissions are handled automatically for pedometer
        }
        
        // Request location permissions
        locationManager.requestWhenInUseAuthorization()
        
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
        
        // Check if background app refresh is enabled
        checkBackgroundAppRefreshStatus()
    }
    
    private func checkBackgroundAppRefreshStatus() {
        // On watchOS, we can't directly check background refresh status
        // but we can inform the user through console logs
        print("Make sure Background App Refresh is enabled for this app in Watch Settings")
        print("Watch Settings > General > Background App Refresh > [Your App Name]")
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func startMonitoring() {
        guard CMPedometer.isStepCountingAvailable() else {
            print("Step counting not available")
            return
        }
        
        isMonitoring = true
        
        // Try to start background session, but don't fail if it doesn't work
        startBackgroundSession()
        
        // Always start step monitoring regardless of background session status
        startStepMonitoring()
    }
    
    func stopMonitoring() {
        isMonitoring = false
        stopBackgroundSession()
        stopStepMonitoring()
    }
    
    private func startBackgroundSession() {
        // Check if we can create a background session
        guard backgroundTask == nil else {
            print("Background session already exists")
            backgroundSessionStatus = "Już aktywne"
            return
        }
        
        backgroundSessionStatus = "Uruchamianie..."
        
        backgroundTask = WKExtendedRuntimeSession()
        backgroundTask?.delegate = self
        
        // Start the session - the newer API doesn't take a completion handler
        backgroundTask?.start()
        
        // The delegate methods will handle success/failure
        print("Background session start requested")
        backgroundSessionStatus = "Żądanie wysłane..."
    }
    
    private func stopBackgroundSession() {
        backgroundTask?.invalidate()
        backgroundTask = nil
        backgroundSessionStatus = "Aktywne"
    }
    
    private func startStepMonitoring() {
        let startDate: Date = Date() // Explicit type annotation to fix conversion error
        
        pedometer.startUpdates(from: startDate) { [weak self] data, error in
            guard let self = self, let data = data, error == nil else {
                print("Pedometer error: \(error?.localizedDescription ?? "Unknown")")
                return
            }
            
            DispatchQueue.main.async {
                // Update step count
                self.totalSteps = data.numberOfSteps.intValue
                
                if let distance = data.distance?.doubleValue {
                    // Only update if activity is confirmed and not paused
                    if self.isActivityConfirmed && !self.isPaused {
                        self.totalDistance = distance
                    }
                }
                self.processStepData(steps: data.numberOfSteps.intValue)
            }
        }
        
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: timeWindow, repeats: true) { [weak self] _ in
            self?.checkForActivityPattern()
        }
    }
    
    private func stopStepMonitoring() {
        pedometer.stopUpdates()
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }
    
    private func processStepData(steps: Int) {
        let stepsDifference = steps - lastStepCount
        
        if stepsDifference >= Int(stepCountThreshold) && !showingActivityAlert && !isActivityConfirmed {
            detectActivity()
        }
        
        lastStepCount = steps
    }
    
    private func checkForActivityPattern() {
        if motionManager.isDeviceMotionAvailable && !motionManager.isDeviceMotionActive {
            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
                guard let motion = motion, error == nil else { return }
                
                let acceleration = motion.userAcceleration
                let totalAcceleration = sqrt(pow(acceleration.x, 2) + pow(acceleration.y, 2) + pow(acceleration.z, 2))
                
                if totalAcceleration > 0.1 && !(self?.showingActivityAlert ?? true) && !(self?.isActivityConfirmed ?? true) {
                    self?.detectActivity()
                }
            }
        }
    }
    
    private func detectActivity() {
        DispatchQueue.main.async {
            self.showingActivityAlert = true
            self.sendNotification()
        }
    }
    
    private func sendNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Wykryto Aktywność"
        content.body = "Czy chcesz rozpocząć aktywność?"
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    func confirmActivity() {
        showingActivityAlert = false
        isActivityConfirmed = true
        isPaused = false
        sessionStartTime = Date()
        totalDistance = 0.0
        totalSteps = 0
        trashCount = 0
        pathPoints.removeAll()
        trashLocations.removeAll()
        
        startLocationTracking()
        startDurationTimer()
        stopStepMonitoring()
        
        // Restart step monitoring for distance tracking
        startStepMonitoring()
    }
    
    func dismissActivity() {
        showingActivityAlert = false
    }
    
    func pauseActivity() {
        isPaused.toggle()
        
        if isPaused {
            stopDurationTimer()
            locationManager.stopUpdatingLocation()
            // Note: API doesn't have pause endpoint, so we'll just stop tracking locally
        } else {
            startDurationTimer()
            startLocationTracking()
            // Resume tracking locally
        }
    }
    
    func endActivity() {
        // Show summary instead of resetting immediately
        showingSummary = true
        
        stopDurationTimer()
        locationManager.stopUpdatingLocation()
        
        // Don't reset data yet - keep it for summary view
    }
    
    func startNewActivity() {
        // Reset all data and start monitoring again
        resetActivityData()
        showingSummary = false
        
        if isMonitoring {
            startStepMonitoring()
        }
    }
    
    func closeSummary() {
        // Just close summary and reset data
        resetActivityData()
        showingSummary = false
    }
    
    private func resetActivityData() {
        isActivityConfirmed = false
        isPaused = false
        totalDistance = 0.0
        totalSteps = 0
        trashCount = 0
        sessionDuration = 0
        sessionStartTime = nil
        lastLocation = nil
        pathPoints.removeAll()
        trashLocations.removeAll()
        formattedDuration = "00:00"
    }
    
    func incrementTrash() {
        trashCount += 1
        
        // Add trash location to local storage only
        if let currentLoc = lastLocation {
            trashLocations.append(currentLoc.coordinate)
        }
    }
    
    func decrementTrash() {
        if trashCount > 0 {
            trashCount -= 1
            // Remove last trash location if available
            if !trashLocations.isEmpty {
                trashLocations.removeLast()
            }
        }
    }
    
    private func startLocationTracking() {
        if CLLocationManager.locationServicesEnabled() {
            locationManager.startUpdatingLocation()
        }
    }
    
    private func startDurationTimer() {
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self,
                  let startTime = self.sessionStartTime, // Safe unwrapping
                  !self.isPaused else { return }
            
            let currentTime = Date() // Explicit Date() for clarity
            self.sessionDuration = currentTime.timeIntervalSince(startTime)
            
            let minutes = Int(self.sessionDuration) / 60
            let seconds = Int(self.sessionDuration) % 60
            self.formattedDuration = String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
    }
    
    private func setupNotifications() {
        UNUserNotificationCenter.current().delegate = self
    }
}

extension ActivityManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last, isActivityConfirmed, !isPaused else { return }
        
        // Always add to path points for mapping
        pathPoints.append(newLocation.coordinate)
        
        if let lastLoc = lastLocation {
            let distance = newLocation.distance(from: lastLoc)
            if distance > 5 { // Only count significant movements (>5m)
                totalDistance += distance
            }
        }
        
        lastLocation = newLocation
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error)")
    }
}

// MARK: - WKExtendedRuntimeSessionDelegate
extension ActivityManager: WKExtendedRuntimeSessionDelegate {
    func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        print("Background session started")
        DispatchQueue.main.async {
            self.backgroundSessionStatus = "Aktywne"
        }
    }
    
    func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        print("Background session will expire")
        // Clean up the current session
        backgroundTask = nil
        
        if isMonitoring {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.startBackgroundSession()
            }
        }
    }
    
    func extendedRuntimeSession(_ extendedRuntimeSession: WKExtendedRuntimeSession, didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason, error: Error?) {
        print("Background session invalidated: \(reason)")
        if let error = error {
            print("Invalidation error: \(error.localizedDescription)")
        }
        
        // Clean up
        DispatchQueue.main.async {
            self.backgroundTask = nil
            self.backgroundSessionStatus = "Aktywne"
        }
        
        // Don't automatically restart - let the user manually restart monitoring if needed
        switch reason {
        case .error:
            print("Session resigned - app went to background")
        case .suppressedBySystem:
            print("Background app refresh disabled")
        @unknown default:
            print("Unknown invalidation reason")
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension ActivityManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            DispatchQueue.main.async {
                self.showingActivityAlert = true
            }
        }
        completionHandler()
    }
}
