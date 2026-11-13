//
//  ProfilePhoto.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  The person's profile photo. It is kept on this iPhone only, never uploaded:
//  the picked photo is cut to a centred square, made 256 × 256 pixels and saved
//  as a small JPEG (about 20 KB) in the app's own folder, one file per account.
//  The screens clip it to a circle.
//

import SwiftUI
import UIKit

final class ProfilePhotoStore: ObservableObject {
    static let shared = ProfilePhotoStore()
    static let side: CGFloat = 256

    @Published private(set) var image: UIImage?
    private var uid: String?

    // Load the photo of the account that is signed in.
    func load(uid: String?) {
        self.uid = uid
        image = uid.flatMap { try? Data(contentsOf: Self.fileURL(uid: $0)) }.flatMap(UIImage.init(data:))
    }

    // Square it, shrink it and save it. Returns false if the data wasn't a picture.
    @discardableResult
    func save(_ data: Data) -> Bool {
        guard let uid = uid, let picked = UIImage(data: data),
              let jpeg = Self.squareJPEG(picked, side: Self.side) else { return false }
        do {
            let url = Self.fileURL(uid: uid)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try jpeg.write(to: url, options: [.atomic, .completeFileProtection])
            image = UIImage(data: jpeg)
            return true
        } catch {
            return false
        }
    }

    func remove() {
        guard let uid = uid else { return }
        try? FileManager.default.removeItem(at: Self.fileURL(uid: uid))
        image = nil
    }

    // The largest centred square of the picture, drawn at side × side, as JPEG.
    static func squareJPEG(_ picture: UIImage, side: CGFloat, quality: CGFloat = 0.8) -> Data? {
        let size = picture.size
        guard size.width > 0, size.height > 0 else { return nil }
        let scale = side / min(size.width, size.height)
        let drawn = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
        let square = renderer.image { _ in
            picture.draw(in: CGRect(x: (side - drawn.width) / 2, y: (side - drawn.height) / 2,
                                    width: drawn.width, height: drawn.height))
        }
        return square.jpegData(compressionQuality: quality)
    }

    static func fileURL(uid: String) -> URL {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return folder.appendingPathComponent("ProfilePhotos", isDirectory: true)
            .appendingPathComponent("\(uid).jpg")
    }
}

// The round photo, or the person's initials on black (light grey in dark mode) when there is none.
struct ProfileAvatar: View {
    let image: UIImage?
    let name: String
    var size: CGFloat = 64

    var initials: String {
        name.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined().uppercased()
    }

    var body: some View {
        ZStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Circle().fill(MapTheme.buttonFill)
                Text(initials.isEmpty ? "?" : initials)
                    .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
                    .foregroundStyle(MapTheme.buttonText)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(.white.opacity(0.8), lineWidth: 2))
        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
        .accessibilityHidden(true)
    }
}
