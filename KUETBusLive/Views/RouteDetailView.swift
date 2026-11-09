//
//  RouteDetailView.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//

import SwiftUI

struct RouteDetailView: View {
    let route: BusRoute
    @EnvironmentObject var authViewModel: AuthViewModel

    func isMyStop(_ stop: Stop) -> Bool {
        authViewModel.profile?.favoriteStopName == stop.name
    }

    var body: some View {
        List {
            ForEach(route.stops, id: \.self) { stop in
                HStack {
                    Image(systemName: isMyStop(stop) ? "star.fill" : "mappin.circle")
                        .foregroundColor(isMyStop(stop) ? .yellow : .blue)
                    Text(stop.name)
                    Spacer()
                    if !isMyStop(stop) {
                        Button("Set as my stop") {
                            authViewModel.saveFavoriteStop(stop)
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)
                    }
                }
            }
        }
        .navigationTitle(route.name)
    }
}
