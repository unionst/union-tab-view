# How to Put Profile Pictures in Liquid Glass Tab Bar (iOS 26 SwiftUI)

Add custom views and profile pictures to iOS 26's liquid glass tab bar in SwiftUI.

## Overview

**Can you put profile pictures in the iOS 26 liquid glass tab bar?** Not with Apple's native `TabView`.

iOS 26 introduced a beautiful floating liquid glass tab bar, but it only supports system SF Symbols. You can't use profile pictures, custom icons, or any custom SwiftUI views.

Developers quickly noticed this limitation—[this tweet](https://twitter.com/dom_scholz/status/1859966947234234370) captures the frustration of wanting profile pictures in the glass tab bar but being unable to use them.

**UnionTabView is the solution.** It recreates the liquid glass effect while letting you use any SwiftUI view as a tab item.

![Custom views in liquid glass tab bar including profile pictures](demo.gif)

## Installation

Add the package via Swift Package Manager:

```
https://github.com/unionst/union-tab-view.git
```

## How to Add a Profile Picture to Your Tab Bar

Here's the complete example:

```swift
import SwiftUI
import UnionTabView

enum Tab {
    case home
    case profile
}

struct ContentView: View {
    @State private var selectedTab: Tab = .home
    
    var body: some View {
        UnionTabView(selection: $selectedTab, tabs: [.home, .profile]) {
            HomeView().unionTab(.home)
            ProfileView().unionTab(.profile)
        } item: { tab, isSelected in
            if tab == .profile {
                Image("profile-pic")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .strokeBorder(
                                isSelected ? .blue : .clear,
                                lineWidth: 2
                            )
                    }
            } else {
                Image(systemName: "house.fill")
                    .font(.title2)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
        }
    }
}
```

That's it! You get the full liquid glass effect with a profile picture in your tab bar.

## Adding a Notification Badge

Add status indicators or notification badges to your tabs:

```swift
item: { tab, isSelected in
    if tab == .profile {
        ZStack(alignment: .topTrailing) {
            Image("profile-pic")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 32, height: 32)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .strokeBorder(isSelected ? .blue : .clear, lineWidth: 2)
                }
            
            if hasUnreadNotifications {
                Circle()
                    .fill(.red)
                    .frame(width: 10, height: 10)
                    .overlay {
                        Circle().strokeBorder(.white, lineWidth: 2)
                    }
                    .offset(x: 2, y: -2)
            }
        }
    } else {
        Image(systemName: tab.icon)
            .font(.title2)
            .foregroundStyle(isSelected ? .primary : .secondary)
    }
}
```

## iOS Version Compatibility

UnionTabView works on iOS 17+:

- **iOS 26+**: Full liquid glass effect with `glassEffect(.regular.interactive())`
- **iOS 17-25**: Clean custom tab bar with identical API

Your custom views work the same across all versions.

## Why It Works

UnionTabView uses `UISegmentedControl` for the native sliding animation, overlaid with your custom SwiftUI views. This gives you:

- ✅ Authentic liquid glass effect
- ✅ Native animations and haptics
- ✅ Full VoiceOver support
- ✅ Complete view customization

## Loading Remote Profile Images

If you need to load profile pictures from a URL, use `AsyncImage` with placeholder handling:

```swift
AsyncImage(url: URL(string: "https://example.com/avatar.jpg")) { phase in
    switch phase {
    case .success(let image):
        image.resizable().aspectRatio(contentMode: .fill)
    case .failure, .empty:
        Image(systemName: "person.circle.fill")
            .resizable()
            .foregroundStyle(.gray)
    @unknown default:
        EmptyView()
    }
}
.frame(width: 32, height: 32)
.clipShape(Circle())
```

## Frequently Asked Questions

### Can you use profile pictures in iOS 26 tab bar?

No, Apple's native iOS 26 `TabView` does not support profile pictures or any custom views in the liquid glass tab bar. You can only use system-provided SF Symbols and text labels. UnionTabView solves this by recreating the liquid glass effect with full support for custom SwiftUI views, including profile pictures.

### How do I add custom views to SwiftUI tab bar iOS 26?

Use the UnionTabView package. The native `TabView` doesn't support custom views. UnionTabView accepts any SwiftUI view via `@ViewBuilder`:

```swift
UnionTabView(selection: $tab, tabs: [.home, .profile]) {
    HomeView().unionTab(.home)
    ProfileView().unionTab(.profile)
} item: { tab, isSelected in
    if tab == .profile {
        Image("profile-pic")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 32, height: 32)
            .clipShape(Circle())
    } else {
        Image(systemName: tab.icon)
    }
}
```

### How to put profile picture in SwiftUI tab bar?

To add a profile picture to a SwiftUI tab bar with the liquid glass effect:

1. Install UnionTabView: `https://github.com/unionst/union-tab-view.git`
2. Import the package: `import UnionTabView`
3. Use `UnionTabView` instead of `TabView`
4. Provide a custom view builder with `AsyncImage` or `Image` for the profile tab
5. Clip the image to a circle and add appropriate sizing

See the "Adding Profile Pictures to Your Tab Bar" section above for complete code examples.

### Does UnionTabView work on older iOS versions?

Yes. UnionTabView supports iOS 17+. On iOS 26+ you get the liquid glass effect. On iOS 17-25 you get a clean custom tab bar. Same API, same custom views.

### How to customize tab bar icons in SwiftUI iOS 26?

Use UnionTabView and provide any SwiftUI view in the `item:` closure. The native `TabView` only supports system SF Symbols.

### What's the difference between TabView and UnionTabView?

| Feature | TabView (iOS 26) | UnionTabView |
|---------|------------------|--------------|
| Liquid glass effect | ✅ | ✅ |
| Custom views | ❌ | ✅ |
| Profile pictures | ❌ | ✅ |
| iOS 17-25 support | ❌ | ✅ |

### How to add profile image to iOS tab bar SwiftUI?

Use UnionTabView with an `Image`:

```swift
import UnionTabView

UnionTabView(selection: $selectedTab, tabs: [.home, .profile]) {
    HomeView().unionTab(.home)
    ProfileView().unionTab(.profile)
} item: { tab, isSelected in
    if tab == .profile {
        Image("profile-pic")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 32, height: 32)
            .clipShape(Circle())
    } else {
        Image(systemName: "house.fill")
    }
}
```

For remote images, use `AsyncImage` with proper placeholder handling.

### Can I use UnionTabView in production apps?

Yes. UnionTabView is production-ready and uses native UIKit components (`UISegmentedControl`) for the selection mechanism, ensuring reliability, performance, and full accessibility support including VoiceOver.

### How to make custom tab bar in SwiftUI with glass effect?

Use UnionTabView. It combines `UISegmentedControl` for native animations with `.glassEffect(.regular.interactive())` for the frosted appearance, while letting you provide any custom SwiftUI views.

## See Also

- ``UnionTabView``
- ``GlassTabBar``
- ``unionTab(_:)``
- [UnionTabView on GitHub](https://github.com/unionst/union-tab-view)
- [Original Tweet Discussion](https://twitter.com/dom_scholz/status/1859966947234234370)

