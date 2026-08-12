import WidgetKit
import SwiftUI

// MARK: - Shared constants

private let kAppGroup = "group.com.gitpulse.companion"

// MARK: - Helpers

private func ud(_ key: String) -> String {
    UserDefaults(suiteName: kAppGroup)?.string(forKey: key) ?? ""
}

private func groupImage(_ key: String) -> UIImage? {
    guard let url = FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: kAppGroup)?
        .appendingPathComponent("\(key).png"),
          let data = try? Data(contentsOf: url) else { return nil }
    return UIImage(data: data)
}

// MARK: - Design tokens

private let kAccent    = Color(red: 0.38, green: 0.40, blue: 0.95)
private let kBg        = Color(red: 0.06, green: 0.08, blue: 0.11)
private let kSurface   = Color(red: 0.10, green: 0.13, blue: 0.18)
private let kText      = Color.white
private let kSubtext   = Color.white.opacity(0.55)

// containerBackground helper — required on iOS 17+
extension View {
    @ViewBuilder
    func gitPulseWidgetBackground() -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            self.containerBackground(for: .widget) { kBg }
        } else {
            self
        }
    }
}

// MARK: - 1. Trending Widget

struct TrendingEntry: TimelineEntry {
    let date: Date
    let name: String
    let desc: String
    let stars: String
    let lang: String

    static var placeholder: TrendingEntry {
        TrendingEntry(date: .now,
                      name: "flutter/flutter",
                      desc: "Flutter makes it easy and fast to build beautiful apps",
                      stars: "165k",
                      lang: "Dart")
    }
}

struct TrendingProvider: TimelineProvider {
    func placeholder(in context: Context) -> TrendingEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (TrendingEntry) -> Void) {
        completion(context.isPreview ? .placeholder : live())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TrendingEntry>) -> Void) {
        let refresh = Calendar.current.date(byAdding: .minute, value: 30, to: .now)!
        completion(Timeline(entries: [live()], policy: .after(refresh)))
    }

    private func live() -> TrendingEntry {
        TrendingEntry(date: .now,
                      name: ud("repo_name"),
                      desc: ud("repo_desc"),
                      stars: ud("repo_stars"),
                      lang: ud("repo_lang"))
    }
}

struct TrendingWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: TrendingEntry

    var body: some View {
        ZStack {
            kBg
            VStack(alignment: .leading, spacing: 0) {
                // Badge
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(kAccent)
                    Text("TRENDING")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundColor(kAccent)
                        .tracking(1.5)
                }
                Spacer(minLength: 6)

                // Repo name
                Text(entry.name.isEmpty ? "—" : entry.name)
                    .font(.system(size: family == .systemSmall ? 13 : 15, weight: .bold))
                    .foregroundColor(kText)
                    .lineLimit(2)
                    .padding(.bottom, 4)

                // Description
                Text(entry.desc.isEmpty ? "Open GitPulse to load data" : entry.desc)
                    .font(.system(size: family == .systemSmall ? 10 : 11))
                    .foregroundColor(kSubtext)
                    .lineLimit(family == .systemSmall ? 2 : 3)

                Spacer()

                // Footer
                HStack {
                    Label {
                        Text(entry.stars.isEmpty ? "–" : entry.stars)
                    } icon: {
                        Image(systemName: "star.fill")
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.yellow)

                    Spacer()

                    if !entry.lang.isEmpty {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(kAccent)
                                .frame(width: 7, height: 7)
                            Text(entry.lang)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(kSubtext)
                        }
                    }
                }
            }
            .padding(12)
        }
        .gitPulseWidgetBackground()
    }
}

struct GitPulseTrendingWidget: Widget {
    static let kind = "GitPulseTrending"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: TrendingProvider()) { entry in
            TrendingWidgetView(entry: entry)
        }
        .configurationDisplayName("Trending Repo")
        .description("The latest trending GitHub repository.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - 2. Image-backed widgets (Overview, TopRepo, Contribution, Language)

struct ImageEntry: TimelineEntry {
    let date: Date
    let image: UIImage?

    static func placeholder(key: String) -> ImageEntry { ImageEntry(date: .now, image: groupImage(key)) }
}

struct ImageProvider: TimelineProvider {
    let key: String

    func placeholder(in context: Context) -> ImageEntry { .placeholder(key: key) }

    func getSnapshot(in context: Context, completion: @escaping (ImageEntry) -> Void) {
        completion(ImageEntry(date: .now, image: groupImage(key)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ImageEntry>) -> Void) {
        let refresh = Calendar.current.date(byAdding: .minute, value: 15, to: .now)!
        completion(Timeline(entries: [ImageEntry(date: .now, image: groupImage(key))], policy: .after(refresh)))
    }
}

struct ImageWidgetView: View {
    let entry: ImageEntry
    let fallbackIcon: String
    let fallbackLabel: String

    var body: some View {
        ZStack {
            kBg
            if let uiImage = entry.image {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .clipped()
            } else {
                VStack(spacing: 10) {
                    Image(systemName: fallbackIcon)
                        .font(.system(size: 30))
                        .foregroundColor(kAccent)
                    Text(fallbackLabel)
                        .font(.system(size: 11))
                        .multilineTextAlignment(.center)
                        .foregroundColor(kSubtext)
                }
                .padding()
            }
        }
        .gitPulseWidgetBackground()
    }
}

struct GitPulseOverviewWidget: Widget {
    static let kind = "GitPulseOverview"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: ImageProvider(key: "overview_image")) { entry in
            ImageWidgetView(entry: entry,
                            fallbackIcon: "person.crop.circle",
                            fallbackLabel: "Open GitPulse\nto load profile")
        }
        .configurationDisplayName("Profile Overview")
        .description("Your GitHub profile stats at a glance.")
        .supportedFamilies([.systemSmall])
    }
}

struct GitPulseTopRepoWidget: Widget {
    static let kind = "GitPulseTopRepo"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: ImageProvider(key: "toprepo_image")) { entry in
            ImageWidgetView(entry: entry,
                            fallbackIcon: "star.fill",
                            fallbackLabel: "Open GitPulse\nto load top repo")
        }
        .configurationDisplayName("Top Repository")
        .description("Your highest-starred repository.")
        .supportedFamilies([.systemMedium])
    }
}

struct GitPulseContributionWidget: Widget {
    static let kind = "GitPulseContribution"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: ImageProvider(key: "contrib_image")) { entry in
            ImageWidgetView(entry: entry,
                            fallbackIcon: "chart.bar.fill",
                            fallbackLabel: "Open GitPulse\nto load contributions")
        }
        .configurationDisplayName("Contributions")
        .description("Your total GitHub stars and forks.")
        .supportedFamilies([.systemLarge])
    }
}

struct GitPulseLanguageWidget: Widget {
    static let kind = "GitPulseLanguage"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: ImageProvider(key: "lang_image")) { entry in
            ImageWidgetView(entry: entry,
                            fallbackIcon: "chevron.left.forwardslash.chevron.right",
                            fallbackLabel: "Open GitPulse\nto load language stats")
        }
        .configurationDisplayName("Language Stats")
        .description("Your top programming languages.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Widget Bundle Entry Point

@main
struct GitPulseWidgetBundle: WidgetBundle {
    var body: some Widget {
        GitPulseTrendingWidget()
        GitPulseOverviewWidget()
        GitPulseTopRepoWidget()
        GitPulseContributionWidget()
        GitPulseLanguageWidget()
    }
}
