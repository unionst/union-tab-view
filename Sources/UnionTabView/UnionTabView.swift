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
/// Geometry of the bar, for hosts to compute the clearance they reserve.
///
/// The bar itself reserves no space: it is an overlay pinned to the bottom of
/// the screen. The host should reserve clearance once, as real UIKit safe area,
/// so every scroll surface — SwiftUI or UIKit — inherits it automatically:
///
/// ```swift
/// rootViewController.additionalSafeAreaInsets.bottom =
///     UnionTabBarMetrics.height(contentHeight: barContentHeight)
///     + breathingRoom
///     - window.safeAreaInsets.bottom
/// ```
public enum UnionTabBarMetrics {
    /// Height of the row of tab items when the host does not specify one.
    public static let contentHeight: CGFloat = 58
    /// Inset between that row and the edge of the glass capsule.
    public static let padding: CGFloat = 14.0 / 3.0
    /// Full height of the bar at rest, which is what a tab must reserve.
    public static var height: CGFloat { contentHeight + (padding * 2) }

    /// Full height of a bar built with a specific item-row height.
    ///
    /// Hosts that pass `contentHeight:` to `UnionTabView` should inset their own
    /// scroll content by this, not by ``height``, or the two disagree.
    public static func height(contentHeight: CGFloat) -> CGFloat {
        contentHeight + (padding * 2)
    }
}

public struct UnionTabView<Tab: Hashable, Content: View, TabItemContent: View>: View {
    @Binding var selection: Tab
    let tabs: [Tab]
    let minimizeProgress: Double
    let contentHeight: CGFloat
    let glassTint: Color?
    let minimizeAnimation: Animation?
    let isActionTab: (Tab) -> Bool
    let onActionTab: ((Tab) -> Void)?
    let onReselect: ((Tab) -> Void)?
    let content: Content
    let tabItemView: (Tab, Bool) -> TabItemContent

    /// Creates an adaptive tab view with custom tab item rendering.
    ///
    /// - Parameters:
    ///   - selection: A binding to the currently selected tab.
    ///   - tabs: An array of all tabs in display order.
    ///   - contentHeight: Height of the row of tab items. Defaults to
    ///     ``UnionTabBarMetrics/contentHeight``. Hosts that pass a custom value must
    ///     inset their scroll content by `UnionTabBarMetrics.height(contentHeight:)`.
    ///   - glassTint: Optional tint applied to the Liquid Glass capsule on iOS 26+,
    ///     for hosts that want the bar darker or colored in a given appearance.
    ///   - minimizeAnimation: Animation applied when `minimizeProgress` changes, so the
    ///     bar grows back rather than snapping when a tab is tapped. Pass `nil` to drive
    ///     the change yourself.
    ///   - onReselect: Called when the already-selected tab is tapped again. Reported
    ///     as its own event rather than as a write of the current selection, so a host
    ///     that pops to root or scrolls to top cannot be tricked into doing it by an
    ///     unrelated write to the binding.
    ///   - content: A view builder that provides the content for each tab. Apply `.unionTab(_:)` to each.
    ///   - item: A view builder closure called for each tab, receiving the tab value and whether it's selected.
    public init(
        selection: Binding<Tab>,
        tabs: [Tab],
        minimizeProgress: Double = 0,
        contentHeight: CGFloat = UnionTabBarMetrics.contentHeight,
        glassTint: Color? = nil,
        minimizeAnimation: Animation? = .spring(duration: 0.3),
        isActionTab: @escaping (Tab) -> Bool = { _ in false },
        onActionTab: ((Tab) -> Void)? = nil,
        onReselect: ((Tab) -> Void)? = nil,
        @ViewBuilder content: () -> Content,
        @ViewBuilder item: @escaping (Tab, Bool) -> TabItemContent
    ) {
        self._selection = selection
        self.tabs = tabs
        self.minimizeProgress = minimizeProgress
        self.contentHeight = contentHeight
        self.glassTint = glassTint
        self.minimizeAnimation = minimizeAnimation
        self.isActionTab = isActionTab
        self.onActionTab = onActionTab
        self.onReselect = onReselect
        self.content = content()
        self.tabItemView = item
    }

    /// Scale applied as the bar minimizes, so it recedes on scroll without
    /// changing the space it reserves. Tracks progress continuously rather
    /// than snapping, so a host can tie it to scroll distance.
    private var minimizeScale: CGFloat {
        let clamped = min(max(minimizeProgress, 0), 1)
        return 1 - ((1 - 152.0 / 180.0) * clamped)
    }

    private var barHeight: CGFloat { contentHeight }

    public var body: some View {
        if #available(iOS 26, *) {
            iOS26Body
        } else {
            legacyBody
        }
    }
    
    // The bar is a pure overlay pinned to the physical bottom of the screen: it
    // reserves nothing. The host owns the reservation, as real UIKit safe area
    // (additionalSafeAreaInsets on the root view controller), so UIKit scroll
    // views and SwiftUI views inherit the same clearance through one mechanism
    // instead of the bar inventing a SwiftUI-only inset that dies at every
    // representable boundary.
    @available(iOS 26, *)
    private var iOS26Body: some View {
        TabView(selection: $selection) {
            content
        }
        .overlay(alignment: .bottom) {
            // The host reserves the bar's clearance as safe area, which every
            // layout layer between here and the screen edge is entitled to
            // apply. Rather than fight those semantics, measure where the
            // overlay region actually ends and translate the bar down by the
            // real gap, so its resting place is 22pt off the physical bottom
            // no matter who insets what.
            GeometryReader { proxy in
                let gap = UIScreen.main.bounds.height - proxy.frame(in: .global).maxY
                glassTabBar
                    .padding(.horizontal, 22)
                    .padding(.bottom, 22)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .offset(y: gap)
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
    
    private var selectedIndex: Int {
        tabs.firstIndex(of: selection) ?? 0
    }

    @available(iOS 26, *)
    private var barGlass: Glass {
        let base: Glass = glassTint.map { .regular.tint($0) } ?? .regular
        return base.interactive()
    }


    @available(iOS 26, *)
    private var glassTabBar: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.element) { index, tab in
                tabItemView(tab, selectedIndex == index)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity)
                    .frame(height: barHeight)
            }
        }
        .frame(maxWidth: CGFloat(tabs.count) * 86)
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
                    itemCount: tabs.count,
                    // An action tab performs its work without becoming the
                    // selection, so the indicator must not travel to it. The
                    // control is hit-test-dead over these segments; the touch
                    // falls through to the catcher layered behind it.
                    actionIndices: Set(tabs.indices.filter { isActionTab(tabs[$0]) }),
                    canSelect: { index in
                        index < tabs.count && !isActionTab(tabs[index])
                    },
                    onRejectedTap: { index in
                        if index < tabs.count {
                            onActionTab?(tabs[index])
                        }
                    },
                    onReselect: { index in
                        if index < tabs.count {
                            onReselect?(tabs[index])
                        }
                    }
                )
            }
            // The selected indicator is the control's own bounds inset by a fixed
            // UIKit margin, so the pill only sits tighter around the icon if the
            // control does. Inset here rather than shrink the row, which would
            // move every item.
            .padding(2)
        }
        // Behind the control, so no SwiftUI gesture ever sits above UIKit's
        // recognizers (an overlay tap catcher broke the reselect gesture).
        // The control's dead zone lets action-tab touches fall through here.
        .background {
            HStack(spacing: 0) {
                ForEach(Array(tabs.enumerated()), id: \.element) { _, tab in
                    if isActionTab(tab) {
                        Color.clear
                            .contentShape(.rect)
                            .onTapGesture { onActionTab?(tab) }
                    } else {
                        Color.clear
                            .allowsHitTesting(false)
                    }
                }
            }
        }
        .padding(UnionTabBarMetrics.padding)
        .glassEffect(barGlass, in: .capsule)
        // Scaling the assembled bar keeps the shrink centred. Resizing it
        // instead would pin the change to the bottom edge, since that is where
        // the safe area inset anchors it.
        .scaleEffect(minimizeScale, anchor: .center)
        .animation(minimizeAnimation, value: minimizeProgress)
    }

    private var legacyBody: some View {
        TabView(selection: $selection) {
            content
        }
        .overlay(alignment: .bottom) {
            GeometryReader { proxy in
                let gap = UIScreen.main.bounds.height - proxy.frame(in: .global).maxY
                legacyTabBar
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .offset(y: gap)
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private var legacyTabBar: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.element) { index, tab in
                tabItemView(tab, selectedIndex == index)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity)
                    .frame(height: barHeight)
            }
        }
        .frame(maxWidth: CGFloat(tabs.count) * 86)
        .clipShape(Capsule())
        .allowsHitTesting(false)
        .padding(4)
    }
}

// Returns nil from hitTest over action segments so the control never begins
// tracking there: the indicator cannot slide toward a tab that opens a sheet,
// and the touch falls through to the catcher behind the control.
final class DeadZoneSegmentedControl: UISegmentedControl {
    var deadIndices: Set<Int> = []

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard numberOfSegments > 0, bounds.width > 0 else {
            return super.hitTest(point, with: event)
        }
        let segmentWidth = bounds.width / CGFloat(numberOfSegments)
        let index = min(numberOfSegments - 1, max(0, Int(point.x / segmentWidth)))
        if deadIndices.contains(index) {
            return nil
        }
        return super.hitTest(point, with: event)
    }
}

@MainActor
struct InteractiveSegmentedControl: UIViewRepresentable {
    var size: CGSize
    var barTint: Color
    @Binding var selectedIndex: Int
    var itemCount: Int
    var actionIndices: Set<Int> = []
    var canSelect: (Int) -> Bool = { _ in true }
    var onRejectedTap: ((Int) -> Void)? = nil
    var onReselect: ((Int) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UISegmentedControl {
        let items = (0..<itemCount).map { _ in "" }
        let control = DeadZoneSegmentedControl(items: items)
        control.deadIndices = actionIndices
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

        // valueChanged never fires when the current segment is tapped again, so
        // a re-tap would be swallowed. Hosts rely on it to pop to root or
        // scroll to top, so it is reported through a gesture instead.
        let reselect = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        reselect.cancelsTouchesInView = false
        control.addGestureRecognizer(reselect)

        return control
    }

    func updateUIView(_ uiView: UISegmentedControl, context: Context) {
        context.coordinator.parent = self
        (uiView as? DeadZoneSegmentedControl)?.deadIndices = actionIndices
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
            let index = control.selectedSegmentIndex
            guard parent.canSelect(index) else {
                // Put the indicator back before it has a chance to animate.
                UIView.performWithoutAnimation {
                    control.selectedSegmentIndex = parent.selectedIndex
                    control.layoutIfNeeded()
                }
                parent.onRejectedTap?(index)
                return
            }
            // Restoring the indicator can echo back as a change to the index the
            // control already sat on, which would reach the host as a fresh
            // selection of the tab it is already showing. Only a real move writes.
            guard index != parent.selectedIndex else { return }
            parent.selectedIndex = index
        }

        // valueChanged never fires when the current segment is tapped again, so
        // the re-tap is recognized here and reported as its own event.
        @MainActor @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let control = gesture.view as? UISegmentedControl,
                  control.numberOfSegments > 0 else { return }

            let segmentWidth = control.bounds.width / CGFloat(control.numberOfSegments)
            guard segmentWidth > 0 else { return }

            let location = gesture.location(in: control)
            let index = min(control.numberOfSegments - 1, max(0, Int(location.x / segmentWidth)))

            guard parent.canSelect(index), index == parent.selectedIndex else { return }
            parent.onReselect?(index)
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
        } else {
            self.tag(tab)
        }
    }
}
