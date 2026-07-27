//
//  AdaptiveTabBar.swift
//  UnionTabView
//
//  Created by Union St on 11/28/25.
//

import SwiftUI

struct AdaptiveTabBar<Tab: TabItem, Content: View, TabItemContent: View>: View {
    @Binding var selection: Tab
    var activeTint: Color
    var inactiveTint: Color
    var barTint: Color
    var tabBarHeight: CGFloat
    var content: () -> Content
    var tabItemView: (Tab, Bool) -> TabItemContent
    
    init(
        selection: Binding<Tab>,
        activeTint: Color = .primary,
        inactiveTint: Color = .secondary,
        barTint: Color = .gray.opacity(0.15),
        tabBarHeight: CGFloat = 55,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder tabItemView: @escaping (Tab, Bool) -> TabItemContent
    ) {
        self._selection = selection
        self.activeTint = activeTint
        self.inactiveTint = inactiveTint
        self.barTint = barTint
        self.tabBarHeight = tabBarHeight
        self.content = content
        self.tabItemView = tabItemView
    }
    
    var body: some View {
        if #available(iOS 26, *) {
            iOS26TabBar
        } else {
            legacyTabBar
        }
    }
    
    @available(iOS 26, *)
    private var iOS26TabBar: some View {
        TabView(selection: $selection) {
            content()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            GlassTabBar(
                activeTab: $selection,
                activeTint: activeTint,
                barTint: barTint
            ) { tab, isSelected in
                tabItemView(tab, isSelected)
            }
            .padding(.horizontal, 20)
        }
    }
    
    private var legacyTabBar: some View {
        TabView(selection: $selection) {
            content()
        }
    }
}

extension AdaptiveTabBar where TabItemContent == DefaultTabItemView<Tab> {
    init(
        selection: Binding<Tab>,
        activeTint: Color = .primary,
        inactiveTint: Color = .secondary,
        barTint: Color = .gray.opacity(0.15),
        tabBarHeight: CGFloat = 55,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self._selection = selection
        self.activeTint = activeTint
        self.inactiveTint = inactiveTint
        self.barTint = barTint
        self.tabBarHeight = tabBarHeight
        self.content = content
        self.tabItemView = { tab, isSelected in
            DefaultTabItemView(
                tab: tab,
                isSelected: isSelected,
                activeTint: activeTint,
                inactiveTint: inactiveTint
            )
        }
    }
}

struct DefaultTabItemView<Tab: TabItem>: View {
    let tab: Tab
    let isSelected: Bool
    let activeTint: Color
    let inactiveTint: Color
    
    init(
        tab: Tab,
        isSelected: Bool,
        activeTint: Color,
        inactiveTint: Color
    ) {
        self.tab = tab
        self.isSelected = isSelected
        self.activeTint = activeTint
        self.inactiveTint = inactiveTint
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: isSelected ? tab.symbol : tab.actionSymbol)
                .font(.title3)
            Text(tab.rawValue)
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(isSelected ? activeTint : inactiveTint)
    }
}

@available(iOS 26, *)
struct GlassTabBarSpacer: View {
    var height: CGFloat
    
    init(height: CGFloat? = nil) {
        self.height = height ?? Self.systemTabBarHeight
    }
    
    var body: some View {
        Text(".")
            .blendMode(.destinationOver)
            .frame(height: height)
    }
    
    private static var systemTabBarHeight: CGFloat {
        if #available(iOS 26, *) {
            return 49
        } else {
            let tabBar = UITabBar()
            tabBar.sizeToFit()
            return tabBar.frame.height
        }
    }
}

extension View {
    @ViewBuilder
    func glassTabBarContentPadding(height: CGFloat? = nil) -> some View {
        if #available(iOS 26, *) {
            self.safeAreaBar(edge: .bottom, spacing: 0) {
                GlassTabBarSpacer(height: height)
            }
            .toolbarVisibility(.hidden, for: .tabBar)
        } else {
            self
        }
    }
}

#if DEBUG
@available(iOS 26, *)
#Preview("Adaptive Tab Bar - Default") {
    @Previewable @State var selectedTab: CustomTab = .home
    
    AdaptiveTabBar(selection: $selectedTab) {
        ScrollView(.vertical) {
            VStack(spacing: 10) {
                ForEach(1...50, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 15)
                        .fill(.red.gradient)
                        .frame(height: 50)
                }
            }
            .padding(15)
        }
        .glassTabBarContentPadding()
        .tabItem { Label("Home", systemImage: "house") }
        .tag(CustomTab.home)
        
        Text("Notifications Content")
            .glassTabBarContentPadding()
            .tabItem { Label("Notifications", systemImage: "bell") }
            .tag(CustomTab.notifications)
        
        Text("Settings Content")
            .glassTabBarContentPadding()
            .tabItem { Label("Settings", systemImage: "gearshape") }
            .tag(CustomTab.settings)
    }
}

@available(iOS 26, *)
#Preview("Adaptive Tab Bar - Custom") {
    @Previewable @State var selectedTab: CustomTab = .home
    
    AdaptiveTabBar(selection: $selectedTab) {
        Text("Home Content")
            .glassTabBarContentPadding()
            .tabItem { Label("Home", systemImage: "house") }
            .tag(CustomTab.home)
        
        Text("Notifications Content")
            .glassTabBarContentPadding()
            .tabItem { Label("Notifications", systemImage: "bell") }
            .tag(CustomTab.notifications)
        
        Text("Settings Content")
            .glassTabBarContentPadding()
            .tabItem { Label("Settings", systemImage: "gearshape") }
            .tag(CustomTab.settings)
    } tabItemView: { tab, isSelected in
        VStack(spacing: 2) {
            Image(systemName: isSelected ? tab.symbol : tab.actionSymbol)
                .font(.title2)
            Circle()
                .fill(isSelected ? .blue : .clear)
                .frame(width: 4, height: 4)
        }
        .foregroundStyle(isSelected ? .blue : .gray)
    }
}
#endif
