import SwiftUI
import WidgetKit

struct KPCREntry: TimelineEntry {
    let date: Date
    let nowPlaying: KPCRNowPlaying
}

struct KPCRProvider: TimelineProvider {
    func placeholder(in context: Context) -> KPCREntry {
        KPCREntry(date: .now, nowPlaying: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (KPCREntry) -> Void) {
        completion(KPCREntry(date: .now, nowPlaying: .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<KPCREntry>) -> Void) {
        Task {
            let nowPlaying = await KPCRNowPlaying.fetch() ?? .placeholder
            let entry = KPCREntry(date: .now, nowPlaying: nowPlaying)
            // Shows change on the hour or half hour; the watch app also asks for
            // a reload whenever it sees the show change.
            completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(15 * 60))))
        }
    }
}

struct KPCRComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: KPCREntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 1) {
                    Image("catEyesMark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 26)
                    Image(systemName: "play.fill")
                        .font(.system(size: 12, weight: .black))
                }
            }
            .widgetLabel("KPCR")
        case .accessoryCorner:
            Image(systemName: "radio.fill")
                .font(.system(size: 20, weight: .bold))
                .widgetLabel("KPCR · \(entry.nowPlaying.headline)")
        case .accessoryInline:
            Label("KPCR · \(entry.nowPlaying.headline)", systemImage: "radio")
        default:
            HStack(spacing: 8) {
                ZStack {
                    Circle().fill(.tint)
                    Image(systemName: "play.fill")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(.black)
                }
                .frame(width: 30, height: 30)
                VStack(alignment: .leading, spacing: 0) {
                    Text("PIRATE CAT RADIO")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(.tint)
                    Text(entry.nowPlaying.headline)
                        .font(.headline)
                        .lineLimit(1)
                    Text(entry.nowPlaying.detail ?? "Tap to listen live")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

@main
struct KPCRComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "KPCRLiveRadio", provider: KPCRProvider()) { entry in
            KPCRComplicationView(entry: entry)
                .containerBackground(.black, for: .widget)
                .widgetURL(KPCRStation.playURL)
                .tint(Color(red: 1.0, green: 0.82, blue: 0.32))
        }
        .configurationDisplayName("Pirate Cat Radio")
        .description("See what's on and tap to play KPCR.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular, .accessoryInline])
    }
}
