//
//  Log.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  The system log, in place of print(). Messages show in Xcode and Console.app, and
//  anything interpolated is private by default, so an error that holds an email or a
//  user ID is redacted on a user's phone instead of sitting in the device log.
//

import os

enum Log {
    private static let subsystem = "KUETBusLive"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let auth = Logger(subsystem: subsystem, category: "auth")
    static let data = Logger(subsystem: subsystem, category: "firestore")
    static let network = Logger(subsystem: subsystem, category: "network")
    static let push = Logger(subsystem: subsystem, category: "push")
}
