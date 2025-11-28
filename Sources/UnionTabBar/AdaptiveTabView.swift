//
//  AdaptiveTabView.swift
//  UnionTabBar
//
//  Created by Union St on 11/28/25.
//

import SwiftUI

public struct AdaptiveTabView<Tab: Hashable, Content: View, TabItemContent: View>: View {
    @Binding var selection: Tab
    let tabs: [Tab]
    let barTint: Color
    let content: Content
    let tabItemView: (Tab, Bool) -> TabItemContent

    @State private var bottomInsets: CGFloat = 0

    public init(
        selection: Binding<Tab>,
        tabs: [Tab],
        barTint: Color = .gray.opacity(0.15),
        @ViewBuilder content: () -> Content,
        @ViewBuilder tabItemView: @escaping (Tab, Bool) -> TabItemContent
    ) {
        self._selection = selection
        self.tabs = tabs
        self.barTint = barTint
        self.content = content()
        self.tabItemView = tabItemView
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
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
        }
        .frame(height: 54)
        .clipShape(Capsule())
        .allowsHitTesting(false)
        .background {
            GeometryReader { geometry in
                InteractiveSegmentedControl(
                    size: geometry.size,
                    barTint: barTint,
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
    @ViewBuilder
    func adaptiveTab<Tab: Hashable>(_ tab: Tab) -> some View {
        if #available(iOS 26, *) {
            self
                .toolbarVisibility(.hidden, for: .tabBar)
                .tag(tab)
        } else {
            self.tag(tab)
        }
    }
    
    @ViewBuilder
    func adaptiveTab<Tab: Hashable>(_ tab: Tab, title: String, systemImage: String) -> some View {
        if #available(iOS 26, *) {
            self
                .toolbarVisibility(.hidden, for: .tabBar)
                .tag(tab)
        } else {
            self
                .tabItem {
                    Label(title, systemImage: systemImage)
                }
                .tag(tab)
        }
    }
}
