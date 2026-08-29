import WidgetKit
import SwiftUI

@main
struct PKPMusicWidgetBundle: WidgetBundle {
    var body: some Widget {
        MusicPlayerWidget()
        ServerMonitorWidget()
        QuickLauncherWidget()
    }
}
