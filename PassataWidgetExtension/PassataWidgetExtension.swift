import SwiftUI
import WidgetKit

@main
struct PassataWidgetExtension: WidgetBundle {
    var body: some Widget {
        PassataPlaceholderWidget()
    }
}

private struct PassataPlaceholderWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PassataWidget", provider: Provider()) { _ in
            Text("Widget")
        }
        .configurationDisplayName("Passata")
        .description("Passata Live Activity placeholder")
    }
}

private struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry { Entry(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) { completion(Entry(date: .now)) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        completion(Timeline(entries: [Entry(date: .now)], policy: .never))
    }
}

private struct Entry: TimelineEntry {
    let date: Date
}
