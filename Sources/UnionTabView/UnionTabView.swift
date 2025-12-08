//
//  UnionTabView.swift
//  UnionTabView
//
//  Created by Union St on 11/28/25.
//

import SwiftUI

/// An adaptive tab view that renders a Liquid Glass floating tab bar on iOS 26+ with fully custom tab item views.
///
/// On iOS 26, Apple's standard `TabView` only supports system-provided tab items. `UnionTabView` gives you
/// the beautiful floating glass effect while allowing **any custom SwiftUI view** for each tab—icons, labels,
/// badges, animations, whatever you want.
///
/// On iOS 17-25, falls back to a clean custom tab bar with the same API.
///
/// ```swift
/// enum Tab { case home, settings }
///
/// struct ContentView: View {
///     @State private var tab: Tab = .home
///
///     var body: some View {
///         UnionTabView(selection: $tab, tabs: [.home, .settings]) {
///             Text("Home").unionTab(Tab.home)
///             Text("Settings").unionTab(Tab.settings)
///         } item: { tab, isSelected in
///             Image(systemName: tab == .home ? "house.fill" : "gear")
///                 .foregroundStyle(isSelected ? .primary : .secondary)
///         }
///     }
/// }
/// ```
public struct UnionTabView<Tab: Hashable, Content: View, TabItemContent: View>: View {
    @Binding var selection: Tab
    let tabs: [Tab]
    let content: Content
    let tabItemView: (Tab, Bool) -> TabItemContent

    @State private var bottomInsets: CGFloat = 0

    /// Creates an adaptive tab view with custom tab item rendering.
    ///
    /// - Parameters:
    ///   - selection: A binding to the currently selected tab.
    ///   - tabs: An array of all tabs in display order.
    ///   - content: A view builder that provides the content for each tab. Apply `.unionTab(_:)` to each.
    ///   - item: A view builder closure called for each tab, receiving the tab value and whether it's selected.
    public init(
        selection: Binding<Tab>,
        tabs: [Tab],
        @ViewBuilder content: () -> Content,
        @ViewBuilder item: @escaping (Tab, Bool) -> TabItemContent
    ) {
        self._selection = selection
        self.tabs = tabs
        self.content = content()
        self.tabItemView = item
    }

    public var body: some View {
        if #available(iOS 26, *) {
            iOS26Body
        } else {
            legacyBody
        }
    }
    
    @available(iOS 26, *)
    private var iOS26Body: some View {
        TabView(selection: $selection) {
            content
        }
        .safeAreaInset(edge: .bottom) {
            glassTabBar
                .ignoresSafeArea()
                .padding(.horizontal, 20)
                .padding(.bottom, -bottomInsets + 21)
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.safeAreaInsets.bottom
                } action: { value in
                    bottomInsets = value
                }
        }
    }
    
    private var selectedIndex: Int {
        tabs.firstIndex(of: selection) ?? 0
    }
    
    @available(iOS 26, *)
    private var glassTabBar: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.element) { index, tab in
                tabItemView(tab, selectedIndex == index)
                    .padding(.vertical, 4)
                    .frame(minWidth: 86)
                    .frame(height: 58)
            }
        }
        .clipShape(Capsule())
        .allowsHitTesting(false)
        .background {
            GeometryReader { geometry in
                InteractiveSegmentedControl(
                    size: geometry.size,
                    barTint: .gray.opacity(0.15),
                    selectedIndex: Binding(
                        get: { selectedIndex },
                        set: { newIndex in
                            if newIndex < tabs.count {
                                selection = tabs[newIndex]
                            }
                        }
                    ),
                    itemCount: tabs.count
                )
            }
        }
        .padding(4)
        .glassEffect(.regular.interactive(), in: .capsule)
    }
    
    private var legacyBody: some View {
        TabView(selection: $selection) {
            content
        }
        .safeAreaInset(edge: .bottom) {
            legacyTabBar
                .ignoresSafeArea()
                .padding(.horizontal, 20)
                .padding(.bottom, -bottomInsets + 28)
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.safeAreaInsets.bottom
                } action: { value in
                    bottomInsets = value
                }
        }
    }

    private var legacyTabBar: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.element) { index, tab in
                tabItemView(tab, selectedIndex == index)
                    .padding(.vertical, 4)
                    .frame(minWidth: 86)
                    .frame(height: 58)
            }
        }
        .clipShape(Capsule())
        .allowsHitTesting(false)
        .padding(4)
    }
}

@MainActor
struct InteractiveSegmentedControl: UIViewRepresentable {
    var size: CGSize
    var barTint: Color
    @Binding var selectedIndex: Int
    var itemCount: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UISegmentedControl {
        let items = (0..<itemCount).map { _ in "" }
        let control = UISegmentedControl(items: items)
        control.selectedSegmentIndex = selectedIndex

        DispatchQueue.main.async {
            for subview in control.subviews {
                if subview is UIImageView && subview != control.subviews.last {
                    subview.alpha = 0
                }
            }
        }

        control.selectedSegmentTintColor = UIColor(barTint)
        control.backgroundColor = .clear
        
        control.addTarget(
            context.coordinator,
            action: #selector(Coordinator.segmentChanged(_:)),
            for: .valueChanged
        )
        
        return control
    }

    func updateUIView(_ uiView: UISegmentedControl, context: Context) {
        if uiView.selectedSegmentIndex != selectedIndex {
            uiView.selectedSegmentIndex = selectedIndex
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UISegmentedControl, context: Context) -> CGSize? {
        return size
    }

    class Coordinator: NSObject {
        var parent: InteractiveSegmentedControl

        init(parent: InteractiveSegmentedControl) {
            self.parent = parent
        }

        @MainActor @objc func segmentChanged(_ control: UISegmentedControl) {
            parent.selectedIndex = control.selectedSegmentIndex
        }
    }
}

public extension View {
    /// Marks this view as the content for a specific tab.
    ///
    /// Apply this to each tab's content view inside `UnionTabView`:
    ///
    /// ```swift
    /// UnionTabView(selection: $selectedTab, tabs: [.home, .profile]) {
    ///     HomeView().unionTab(.home)
    ///     ProfileView().unionTab(.profile)
    /// } item: { tab, isSelected in
    ///     // custom tab item view
    /// }
    /// ```
    ///
    /// - Parameter tab: The tab value this content represents.
    @ViewBuilder
    public func unionTab<Tab: Hashable>(_ tab: Tab) -> some View {
        if #available(iOS 26, *) {
            self
                .toolbarVisibility(.hidden, for: .tabBar)
                .tag(tab)
                .safeAreaBar(edge: .bottom) {
                    Text(".")
                        .blendMode(.destinationOver)
                        .frame(height: 55)
                }
        } else {
            self.tag(tab)
        }
    }
}
