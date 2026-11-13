//
//  AppCache.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  Data & storage in Settings: how much the app keeps in its caches (saved road
//  routes and map responses, temporary files) and a button to clear it. Nothing
//  here is the rider's own data: places, ride history and settings are kept.
//

import Foundation

enum AppCache {
    static var cachesDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    }

    // Bytes in a folder and everything under it.
    static func size(of folder: URL) -> Int64 {
        guard let files = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        var total: Int64 = 0
        for case let file as URL in files {
            total += Int64((try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        return total
    }

    // The network cache plus the caches and temporary folders.
    static func currentSize() -> Int64 {
        Int64(URLCache.shared.currentDiskUsage)
            + size(of: cachesDirectory)
            + size(of: FileManager.default.temporaryDirectory)
    }

    static func sizeText(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    // Empties a folder but keeps the folder itself.
    static func empty(_ folder: URL) {
        let fileManager = FileManager.default
        let items = (try? fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        for item in items {
            try? fileManager.removeItem(at: item)
        }
    }

    static func clear() {
        URLCache.shared.removeAllCachedResponses()
        empty(cachesDirectory)
        empty(FileManager.default.temporaryDirectory)
    }
}

// Appearance in Settings: the live map as a plain map or as satellite photos.
enum MapStyleChoice: String, CaseIterable, Identifiable {
    case standard, satellite

    static let storageKey = "mapStyle"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: return String(localized: "Standard")
        case .satellite: return String(localized: "Satellite")
        }
    }
}
