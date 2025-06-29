import SwiftUI
import CoreMotion
import WatchKit
import UserNotifications

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
    @State private var showingTrashView = false
    
    var body: some View {
        VStack(spacing: 20) {
            if activityManager.isActivityConfirmed {
                VStack(spacing: 15) {
                    Text("Activity Detected!")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    
                    Text("You confirmed walking activity")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        activityManager.endActivity()
                    }) {
                        Image(systemName: "trash")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Color.red)
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            } else {
                VStack(spacing: 15) {
                    Text("Activity Monitor")
                        .font(.headline)
                    
                    Text(activityManager.isMonitoring ? "Monitoring..." : "Tap to start")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
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
        .padding()
        .onAppear {
            activityManager.requestPermissions()
        }
        .alert("Activity Detected", isPresented: $activityManager.showingActivityAlert) {
            Button("Yes") {
                activityManager.confirmActivity()
            }
            Button("No") {
                activityManager.dismissActivity()
            }
        } message: {
            Text("Are you currently walking or doing some activity?")
        }
    }
}


class ActivityManager: NSObject, ObservableObject {
    private let motionManager = CMMotionManager()
    private let pedometer = CMPedometer()
    private var backgroundTask: WKExtendedRuntimeSession?
    
    @Published var isMonitoring = false
    @Published var showingActivityAlert = false
    @Published var isActivityConfirmed = false
    
    private var stepCountThreshold: Double = 10
    private var timeWindow: TimeInterval = 30.0
    private var lastStepCount: Int = 0
    private var monitoringTimer: Timer?
    
    override init() {
        super.init()
        setupNotifications()
    }
    
    func requestPermissions() {
        // Request motion permissions
        if CMPedometer.isStepCountingAvailable() {
            // Permissions are handled automatically for pedometer
        }
        
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }
    
    func startMonitoring() {
        guard CMPedometer.isStepCountingAvailable() else {
            print("Step counting not available")
            return
        }
        
        isMonitoring = true
        startBackgroundSession()
        startStepMonitoring()
    }
    
    func stopMonitoring() {
        isMonitoring = false
        stopBackgroundSession()
        stopStepMonitoring()
    }
    
    private func startBackgroundSession() {
        backgroundTask = WKExtendedRuntimeSession()
        backgroundTask?.delegate = self
        backgroundTask?.start()
    }
    
    private func stopBackgroundSession() {
        backgroundTask?.invalidate()
        backgroundTask = nil
    }
    
    private func startStepMonitoring() {
        let now = Date()
        
        pedometer.startUpdates(from: now) { [weak self] data, error in
            guard let self = self, let data = data, error == nil else {
                print("Pedometer error: \(error?.localizedDescription ?? "Unknown")")
                return
            }
            
            DispatchQueue.main.async {
                self.processStepData(steps: data.numberOfSteps.intValue)
            }
        }
        
        // Also set up a timer to check periodically
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
        // Additional check using motion data if available
        if motionManager.isDeviceMotionAvailable && !motionManager.isDeviceMotionActive {
            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
                guard let motion = motion, error == nil else { return }
                
                let acceleration = motion.userAcceleration
                let totalAcceleration = sqrt(pow(acceleration.x, 2) + pow(acceleration.y, 2) + pow(acceleration.z, 2))
                
                // If significant movement detected
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
                content.title = "Activity Detected"
                content.body = "Are you currently walking or doing some activity?"
                content.sound = .default
                
                let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                UNUserNotificationCenter.current().add(request)
            }
            
            func confirmActivity() {
                showingActivityAlert = false
                isActivityConfirmed = true
                callMockAPI(endpoint: "activity_confirmed")
                stopStepMonitoring() // Stop monitoring once confirmed
            }
            
            func dismissActivity() {
                showingActivityAlert = false
                // Continue monitoring
            }
            
            func endActivity() {
                callMockAPI(endpoint: "activity_ended")
                isActivityConfirmed = false
                
                // Restart monitoring if it was previously active
                if isMonitoring {
                    startStepMonitoring()
                }
            }
            
            private func callMockAPI(endpoint: String) {
                // Mock API call
                let url = URL(string: "https://jsonplaceholder.typicode.com/posts")!
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                let body = [
                    "action": endpoint,
                    "timestamp": ISO8601DateFormatter().string(from: Date()),
                    "device": "apple_watch"
                ]
                
                do {
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)
                } catch {
                    print("Failed to encode request body: \(error)")
                    return
                }
                
                URLSession.shared.dataTask(with: request) { data, response, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            print("API call failed: \(error)")
                        } else {
                            print("API call successful for: \(endpoint)")
                        }
                    }
                }.resume()
            }
            
            private func setupNotifications() {
                UNUserNotificationCenter.current().delegate = self
            }
        }

        // MARK: - WKExtendedRuntimeSessionDelegate
        extension ActivityManager: WKExtendedRuntimeSessionDelegate {
            func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
                print("Background session started")
            }
            
            func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
                print("Background session will expire")
                // Try to restart if still monitoring
                if isMonitoring {
                    startBackgroundSession()
                }
            }
            
            func extendedRuntimeSession(_ extendedRuntimeSession: WKExtendedRuntimeSession, didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason, error: Error?) {
                print("Background session invalidated: \(reason)")
                if let error = error {
                    print("Error: \(error)")
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
