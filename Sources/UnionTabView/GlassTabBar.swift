//
//  GlassTabBar.swift
//  UnionTabView
//
//  Created by Union St on 11/28/25.
//

import SwiftUI
import UIKit

protocol TabItem: Hashable, CaseIterable, RawRepresentable where RawValue == String, AllCases: RandomAccessCollection {
    var symbol: String { get }
    var actionSymbol: String { get }
    var index: Int { get }
}

extension TabItem {
    var index: Int {
        Self.allCases.firstIndex(of: self).map { Self.allCases.distance(from: Self.allCases.startIndex, to: $0) } ?? 0
    }
}

enum CustomTab: String, CaseIterable, TabItem, Sendable {
    case home = "Home"
    case notifications = "Notifications"
    case settings = "Settings"

    var symbol: String {
        switch self {
        case .home: return "house.fill"
        case .notifications: return "bell.fill"
        case .settings: return "gearshape.fill"
        }
    }

    var actionSymbol: String {
        switch self {
        case .home: return "house"
        case .notifications: return "bell"
        case .settings: return "gearshape"
        }
    }
}

@MainActor
struct SegmentedControlTabBar<Tab: TabItem>: UIViewRepresentable {
    var size: CGSize
    var barTint: Color
    @Binding var activeTab: Tab

    init(size: CGSize, barTint: Color = .gray.opacity(0.15), activeTab: Binding<Tab>) {
        self.size = size
        self.barTint = barTint
        self._activeTab = activeTab
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UISegmentedControl {
        let items = Tab.allCases.compactMap { _ in "" }
        let control = TracklessSegmentedControl(items: items)
        control.selectedSegmentIndex = activeTab.index

        control.selectedSegmentTintColor = UIColor(barTint)
        control.backgroundColor = .clear

        control.addTarget(
            context.coordinator,
            action: #selector(context.coordinator.tabSelected(_:)),
            for: .valueChanged
        )
        return control
    }

    func updateUIView(_ uiView: UISegmentedControl, context: Context) {
        if uiView.selectedSegmentIndex != activeTab.index {
            uiView.selectedSegmentIndex = activeTab.index
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UISegmentedControl, context: Context) -> CGSize? {
        return size
    }

    class Coordinator: NSObject {
        var parent: SegmentedControlTabBar

        init(parent: SegmentedControlTabBar) {
            self.parent = parent
        }

        @MainActor @objc func tabSelected(_ control: UISegmentedControl) {
            let allCases = Array(Tab.allCases)
            if control.selectedSegmentIndex < allCases.count {
                parent.activeTab = allCases[control.selectedSegmentIndex]
            }
        }
    }
}

@available(iOS 26, *)
struct GlassTabBar<Tab: TabItem, TabItemContent: View>: View {
    @Binding var activeTab: Tab
    var activeTint: Color
    var barTint: Color
    var itemWidth: CGFloat
    var itemHeight: CGFloat
    var tabItemView: (Tab, Bool) -> TabItemContent

    init(
        activeTab: Binding<Tab>,
        activeTint: Color = .primary,
        barTint: Color = .gray.opacity(0.15),
        itemWidth: CGFloat = 86,
        itemHeight: CGFloat = 58,
        @ViewBuilder tabItemView: @escaping (Tab, Bool) -> TabItemContent
    ) {
        self._activeTab = activeTab
        self.activeTint = activeTint
        self.barTint = barTint
        self.itemWidth = itemWidth
        self.itemHeight = itemHeight
        self.tabItemView = tabItemView
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(Tab.allCases), id: \.self) { tab in
                tabItemView(tab, activeTab == tab)
                    .frame(width: itemWidth, height: itemHeight)
            }
        }
        .background {
            GeometryReader { geometry in
                SegmentedControlTabBar(size: geometry.size, barTint: barTint, activeTab: $activeTab)
            }
        }
        .padding(4)
        .glassEffect(.regular.interactive(), in: .capsule)
        .contentShape(Rectangle())
    }
}

@available(iOS 26, *)
struct SimpleGlassTabBar<Tab: TabItem>: View {
    @Binding var activeTab: Tab
    var activeTint: Color
    var inactiveTint: Color
    var barTint: Color

    init(
        activeTab: Binding<Tab>,
        activeTint: Color = .primary,
        inactiveTint: Color = .secondary,
        barTint: Color = .gray.opacity(0.15)
    ) {
        self._activeTab = activeTab
        self.activeTint = activeTint
        self.inactiveTint = inactiveTint
        self.barTint = barTint
    }

    var body: some View {
        GlassTabBar(
            activeTab: $activeTab,
            activeTint: activeTint,
            barTint: barTint
        ) { tab, isSelected in
            VStack(spacing: 4) {
                Image(systemName: isSelected ? tab.symbol : tab.actionSymbol)
                    .font(.title3)
                    .foregroundStyle(isSelected ? activeTint : inactiveTint)
                
                Text(tab.rawValue)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isSelected ? activeTint : inactiveTint)
            }
        }
    }
}

@available(iOS 26, *)
struct IconOnlyGlassTabBar<Tab: TabItem>: View {
    @Binding var activeTab: Tab
    var activeTint: Color
    var inactiveTint: Color
    var barTint: Color
    var iconSize: Font

    init(
        activeTab: Binding<Tab>,
        activeTint: Color = .primary,
        inactiveTint: Color = .secondary,
        barTint: Color = .gray.opacity(0.15),
        iconSize: Font = .title2
    ) {
        self._activeTab = activeTab
        self.activeTint = activeTint
        self.inactiveTint = inactiveTint
        self.barTint = barTint
        self.iconSize = iconSize
    }

    var body: some View {
        GlassTabBar(
            activeTab: $activeTab,
            activeTint: activeTint,
            barTint: barTint,
            itemWidth: 70,
            itemHeight: 50
        ) { tab, isSelected in
            Image(systemName: isSelected ? tab.symbol : tab.actionSymbol)
                .font(iconSize)
                .foregroundStyle(isSelected ? activeTint : inactiveTint)
        }
    }
}

struct FloatingTabIndicator<Tab: TabItem>: View {
    @Binding var activeTab: Tab
    var activeTint: Color
    var size: CGFloat

    init(
        activeTab: Binding<Tab>,
        activeTint: Color = .primary,
        size: CGFloat = 55
    ) {
        self._activeTab = activeTab
        self.activeTint = activeTint
        self.size = size
    }

    var body: some View {
        ZStack {
            ForEach(Array(Tab.allCases), id: \.self) { tab in
                Image(systemName: tab.symbol)
                    .font(.title)
                    .foregroundStyle(activeTint)
                    .blurFade(activeTab == tab)
            }
        }
        .frame(width: size, height: size)
        .background(.ultraThinMaterial, in: Circle())
        .animation(.smooth(duration: 0.3), value: activeTab)
    }
}

#if DEBUG
@available(iOS 26, *)
#Preview("Simple Glass Tab Bar") {
    @Previewable @State var activeTab: CustomTab = .home
    
    VStack {
        Spacer()
        SimpleGlassTabBar(activeTab: $activeTab)
            .padding(.horizontal, 20)
    }
    .background(Color.gray.opacity(0.2))
}

@available(iOS 26, *)
#Preview("Icon Only Glass Tab Bar") {
    @Previewable @State var activeTab: CustomTab = .home
    
    VStack {
        Spacer()
        IconOnlyGlassTabBar(activeTab: $activeTab)
            .padding(.horizontal, 20)
    }
    .background(Color.gray.opacity(0.2))
}

@available(iOS 26, *)
#Preview("Custom Glass Tab Bar") {
    @Previewable @State var activeTab: CustomTab = .home
    
    VStack {
        Spacer()
        GlassTabBar(activeTab: $activeTab) { tab, isSelected in
            VStack(spacing: 2) {
                Image(systemName: isSelected ? tab.symbol : tab.actionSymbol)
                    .font(.title3)
                    .foregroundStyle(isSelected ? .blue : .gray)
                
                Circle()
                    .fill(isSelected ? .blue : .clear)
                    .frame(width: 4, height: 4)
            }
            .frame(width: 60, height: 50)
        }
        .padding(.horizontal, 20)
    }
    .background(Color.gray.opacity(0.2))
}

#Preview("Floating Tab Indicator") {
    @Previewable @State var activeTab: CustomTab = .home
    
    VStack {
        FloatingTabIndicator(activeTab: $activeTab)
        
        HStack(spacing: 20) {
            ForEach(Array(CustomTab.allCases), id: \.self) { tab in
                Button(tab.rawValue) {
                    activeTab = tab
                }
            }
        }
        .padding(.top, 20)
    }
}
#endif
