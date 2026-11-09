//
//  KUETBusWidgetBundle.swift
//  KUETBusWidget
//
//  Created by Muttakin Rahman Shoscho.
//
//  Entry point of the widget extension. It lists every widget the extension provides.
//

import WidgetKit
import SwiftUI

@main
struct KUETBusWidgetBundle: WidgetBundle {
    var body: some Widget {
        KUETBusWidget()
        BusLiveActivity()
    }
}
