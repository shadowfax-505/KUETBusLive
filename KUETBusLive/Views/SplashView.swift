//
//  SplashView.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  The screen shown at launch. It plays the logo intro once and then hands
//  over to the app.
//

import SwiftUI

struct SplashView: View {
    let onFinished: () -> Void

    var body: some View {
        IntroAnimationView(onFinished: onFinished)
    }
}
