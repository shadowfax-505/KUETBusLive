//
//  SplashView.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  A short opening animation: the logo springs in while a dotted route
//  draws itself underneath, then the app fades in.
//

import SwiftUI

struct SplashView: View {
    @State private var logoScale = 0.6
    @State private var logoOpacity = 0.0
    @State private var routeProgress = 0.0
    let onFinished: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.05, green: 0.54, blue: 0.37),
                                    Color(red: 0.04, green: 0.16, blue: 0.33)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Image("AppLogo")
                    .resizable()
                    .frame(width: 140, height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 32))
                    .shadow(color: .black.opacity(0.3), radius: 16, y: 10)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)

                Text("KUET Bus Live")
                    .font(.largeTitle)
                    .fontWeight(.heavy)
                    .foregroundColor(.white)
                    .opacity(logoOpacity)

                // A dotted line that draws from left to right, like a route on a map.
                Capsule()
                    .stroke(style: StrokeStyle(lineWidth: 6, lineCap: .round, dash: [1, 14]))
                    .frame(height: 6)
                    .foregroundColor(.yellow)
                    .mask(alignment: .leading) {
                        GeometryReader { geometry in
                            Rectangle().frame(width: geometry.size.width * routeProgress)
                        }
                    }
                    .frame(width: 200)
            }
        }
        // .task (not .onAppear) waits until the app has finished launching,
        // so the animation is actually seen and not played behind a busy start.
        .task {
            try? await Task.sleep(for: .milliseconds(100))
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                logoScale = 1
                logoOpacity = 1
            }
            withAnimation(.easeInOut(duration: 1.0).delay(0.2)) {
                routeProgress = 1
            }
            // Let the animation play, then hand over to the app.
            try? await Task.sleep(for: .seconds(1.4))
            onFinished()
        }
    }
}
