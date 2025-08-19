//
//  RoutinaWidgetBundle.swift
//  RoutinaWidget
//
//  Created by ghadirianh on 20.04.26.
//

import WidgetKit
import SwiftUI

@main
struct RoutinaWidgetBundle: WidgetBundle {
    var body: some Widget {
        RoutinaStatsWidget()
        RoutinaFocusTimerWidget()
#if os(iOS)
        RoutinaFocusTimerLiveActivity()
#endif
        GitHubActivityWidget()
        GitLabActivityWidget()
    }
}
