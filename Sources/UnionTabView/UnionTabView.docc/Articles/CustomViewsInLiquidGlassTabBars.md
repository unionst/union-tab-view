# How to Put Profile Pictures in Liquid Glass Tab Bar

Apple's iOS 26 liquid glass tab bar doesn't support custom views—you can only use system SF Symbols. This means no profile pictures, no custom icons, and no custom layouts in the native `TabView`.

UnionTabView solves this by recreating the liquid glass effect while letting you use any SwiftUI view.

![Custom views in liquid glass tab bar including profile pictures](demo.gif)

## Installation

Add via Swift Package Manager:

```
https://github.com/unionst/union-tab-view.git
```

## Basic Example

Here's how to add a profile picture to your tab bar:

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

That's it! You get the liquid glass effect with a profile picture.

## With Notification Badge

You can add any SwiftUI view—here's a notification indicator:

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

## Remote Images

For loading profile pictures from a URL, use `AsyncImage`:

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

## Full-Width Tab Bar

By default, the tab bar sizes to fit its content and centers on screen. To create a full-width tab bar, apply `.frame(maxWidth: .infinity)` to your tab item views:

```swift
UnionTabView(selection: $selectedTab, tabs: tabs) {
    // content...
} item: { tab, isSelected in
    VStack {
        Image(systemName: tab.icon)
        Text(tab.title)
    }
    .frame(maxWidth: .infinity) // Makes tab bar full-width
}
```

## Compatibility

UnionTabView works on iOS 17+. On iOS 26+ you get the liquid glass effect. On iOS 17-25 you get a clean custom tab bar. Same code, same API.

## See Also

- ``UnionTabView``
- ``unionTab(_:)``

