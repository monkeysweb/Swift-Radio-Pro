//
//  AppDelegate.swift
//  Swift Radio
//
//  Created by Matthew Fecher on 7/2/15.
//  Copyright (c) 2015 MatthewFecher.com. All rights reserved.
//

import UIKit
import UserNotifications

@main
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    private let audioService = AudioSetupService.shared
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        // Setup all audio-related configurations at app launch
        audioService.setupFRadioPlayer()
        audioService.setupAudioSession()
        audioService.setupRemoteCommandCenter()
        KPCRWatchBridge.shared.activate()
        UNUserNotificationCenter.current().delegate = self
        // Refresh the push token each launch if the listener already allowed alerts.
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            DispatchQueue.main.async { application.registerForRemoteNotifications() }
        }
        
        return true
    }
    
    // MARK: UISceneSession Lifecycle
    
    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        if connectingSceneSession.role == .carTemplateApplication {
            let config = UISceneConfiguration(name: "CarPlay Configuration", sessionRole: connectingSceneSession.role)
            config.delegateClass = CarPlaySceneDelegate.self
            return config
        }
        
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    func application(_ application: UIApplication,
                     didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    }

    // MARK: Push notifications

    static let pushTokenKey = "kpcr.push.deviceToken"
    static let pushTokenDidChange = Notification.Name("kpcrPushTokenDidChange")
    static let playLiveRequested = Notification.Name("kpcrPlayLiveRequested")

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(token, forKey: Self.pushTokenKey)
        NotificationCenter.default.post(name: Self.pushTokenDidChange, object: token)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("[push] registration failed: \(error.localizedDescription)")
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    // Tapping a "show is live" alert starts the live stream.
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let kpcr = response.notification.request.content.userInfo["kpcr"] as? [String: Any]
        if kpcr?["action"] as? String == "play-live" {
            DispatchQueue.main.async { NotificationCenter.default.post(name: Self.playLiveRequested, object: nil) }
        }
        completionHandler()
    }
}
