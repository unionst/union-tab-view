# UnionTabBar

A beautiful, adaptive tab bar package for iOS that automatically provides a stunning glass-effect floating tab bar on iOS 26+ while gracefully falling back to a clean custom tab bar on earlier versions.

## Features

- **Adaptive Design**: Automatically uses iOS 26's `glassEffect` API when available, falls back gracefully on iOS 17-25
- **Native Sliding Animation**: Uses `UISegmentedControl` under the hood for buttery-smooth selection animations
- **Fully Customizable**: Complete control over tab item appearance via `@ViewBuilder` closures
- **Simple API**: Drop-in replacement for `TabView` with minimal code changes
- **Safe Area Aware**: Properly handles safe area insets on all device types

## Requirements

- iOS 17.0+
- Swift 6.0+
- Xcode 16+

## Installation

Add this package to your Xcode project using Swift Package Manager:

```
https://github.com/unionst/union-tab-bar.git
```

## Usage

### Basic Usage with UnionTabView

The primary component is `UnionTabView`, which wraps your tab content and provides the adaptive tab bar:

```swift
import SwiftUI
import UnionTabBar

enum RootTab: Hashable {
    case home, explore, settings
    
    var title: String {
        switch self {
        case .home: "Home"
        case .explore: "Explore"
        case .settings: "Settings"
        }
    }
    
    var icon: String {
        switch self {
        case .home: "house.fill"
        case .explore: "safari.fill"
        case .settings: "gearshape.fill"
        }
    }
}

struct ContentView: View {
    @State private var selectedTab: RootTab = .home
    
    var body: some View {
        UnionTabView(
            selection: $selectedTab,
            tabs: [.home, .explore, .settings]
        ) {
            NavigationStack { HomeView() }
                .unionTab(RootTab.home)
            
            NavigationStack { ExploreView() }
                .unionTab(RootTab.explore)
            
            NavigationStack { SettingsView() }
                .unionTab(RootTab.settings)
        } item: { tab, isSelected in
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                
                Text(tab.title)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(isSelected ? .primary : .secondary)
        }
    }
}
```

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `selection` | `Binding<Tab>` | Required | Binding to the currently selected tab |
| `tabs` | `[Tab]` | Required | Array of all tabs in display order |
| `barTint` | `Color` | `.gray.opacity(0.15)` | Tint color for the sliding selection indicator |
| `content` | `@ViewBuilder` | Required | The tab content views |
| `item` | `@ViewBuilder` | Required | Closure to render each tab item |

### The `.unionTab()` Modifier

Apply this modifier to each tab's content view:

```swift
NavigationStack { HomeView() }
    .unionTab(RootTab.home)
```

On iOS 26+, this modifier:
- Hides the system tab bar
- Adds proper safe area spacing for the floating tab bar

On iOS 17-25, it simply applies the `.tag()` modifier.

## Customization Examples

### Icon-Only Tab Bar

```swift
UnionTabView(selection: $selectedTab, tabs: RootTab.allCases) {
    // content...
} item: { tab, isSelected in
    Image(systemName: tab.icon)
        .font(.title2)
        .foregroundStyle(isSelected ? .blue : .gray)
}
```

### Animated Selection with Symbol Effects

```swift
UnionTabView(selection: $selectedTab, tabs: RootTab.allCases) {
    // content...
} item: { tab, isSelected in
    VStack(spacing: 6) {
        Image(systemName: tab.icon)
            .font(.system(size: 22))
            .symbolEffect(.bounce, value: isSelected)
        
        Circle()
            .fill(isSelected ? .blue : .clear)
            .frame(width: 5, height: 5)
    }
    .foregroundStyle(isSelected ? .blue : .secondary)
}
```

### Custom Pill Selection Style

```swift
UnionTabView(selection: $selectedTab, tabs: RootTab.allCases) {
    // content...
} item: { tab, isSelected in
    HStack(spacing: 6) {
        Image(systemName: tab.icon)
            .font(.system(size: 18, weight: .semibold))
        
        if isSelected {
            Text(tab.title)
                .font(.system(size: 14, weight: .semibold))
        }
    }
    .foregroundStyle(isSelected ? .white : .secondary)
    .padding(.horizontal, isSelected ? 16 : 12)
    .padding(.vertical, 10)
    .background {
        if isSelected {
            Capsule().fill(.blue.gradient)
        }
    }
}
```

## Additional Components

### TabItem Protocol

For more structured tab definitions, conform to the `TabItem` protocol:

```swift
enum MyTab: String, CaseIterable, TabItem {
    case home = "Home"
    case settings = "Settings"
    
    var symbol: String {
        switch self {
        case .home: "house.fill"
        case .settings: "gearshape.fill"
        }
    }
    
    var actionSymbol: String {
        switch self {
        case .home: "house"
        case .settings: "gearshape"
        }
    }
}
```

### GlassTabBar (iOS 26+ Only)

For standalone glass tab bar usage outside of `UnionTabView`:

```swift
@available(iOS 26, *)
GlassTabBar(activeTab: $selectedTab) { tab, isSelected in
    VStack(spacing: 4) {
        Image(systemName: isSelected ? tab.symbol : tab.actionSymbol)
            .font(.title3)
        Text(tab.rawValue)
            .font(.system(size: 10, weight: .medium))
    }
    .foregroundStyle(isSelected ? .primary : .secondary)
}
.padding(.horizontal, 20)
```

### View Modifiers

#### `.blurFade(_:)`

Applies a blur and fade effect based on a boolean:

```swift
Image(systemName: "star.fill")
    .blurFade(isVisible)
```

## Architecture

The package uses a `UISegmentedControl` as the underlying selection mechanism, which provides:

1. **Native sliding animation** - The selection indicator slides smoothly between segments
2. **Haptic feedback** - System haptics on selection
3. **Accessibility support** - Full VoiceOver compatibility

The segmented control is styled to be invisible (empty string segments, clear background) while the custom tab item views are rendered on top with `allowsHitTesting(false)`, allowing touch events to pass through to the control.

## License

MIT

## Author

Union St
