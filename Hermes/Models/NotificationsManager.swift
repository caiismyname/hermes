//
//  NotificationsModel.swift
//  Hermes
//
//  Created by David Cai on 11/6/22.
//

import Foundation
import UserNotifications

class NotificationsManager {
    var reminders = [String]()
    private let reminderInterval = TimeInterval(exactly: 60.0 * 120.0) // 2hrs
    private let reminderLimit = 5.0
    private let UDKey = "reminders"
    var hasPermission = false
    // TODO: Ideas — time boundary, location triggered
    
    init() {
       
    }
    
    func setup() {
        if let savedReminders = UserDefaults.standard.stringArray(forKey: UDKey) {
            reminders = savedReminders
        } else {
            reminders = [String]() // Didn't find reminders
        }
        
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            
            if let error = error {
                print(error)
            }
            
            print("Notifications permissions is \(granted)")
            self.hasPermission = granted
        }
    }
    
    private func setReminders() {
        guard hasPermission else { return }
        for i in stride(from: 1.0, to: reminderLimit, by: 1.0) {
            createReminder(reminderIndex: i)
        }
        
        UserDefaults.standard.set(self.reminders, forKey: UDKey)
    }
    
    func resetReminders() {
        self.clearReminders()
        self.setReminders()
    }
    
    private func createReminder(reminderIndex: Double) {
        guard hasPermission else { return }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: reminderInterval! * reminderIndex, repeats: false)
        let content = UNMutableNotificationContent()
        content.title = "Vlog Update!"
        content.body = "It's been a while since you last updated the vlog. Anything new to share?"
        content.sound = UNNotificationSound.default
        
        // Create the request
        let notifID = UUID().uuidString
        let request = UNNotificationRequest(identifier: notifID, content: content, trigger: trigger)

        // Schedule the request with the system.
        UNUserNotificationCenter.current().add(request) { (error) in
           if error != nil {
               print("Error scheduling reminder: \(String(describing: error))")
           } else {
               self.reminders.append(notifID)
               print("Reminder \(notifID) scheduled")
           }
        }
    }
    
    private func clearReminders() {
        guard hasPermission else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: self.reminders)
        self.reminders = [String]()
    }
}
