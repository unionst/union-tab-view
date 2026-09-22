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

    /// Distance the bar rests above the physical bottom of the screen. A host
    /// stacking its own chrome on top of the bar needs this to work out how far
    /// the whole assembly has to travel to clear the screen.
    public static let restingBottomInset: CGFloat = 22
}

public struct UnionTabView<Tab: Hashable, Content: View, TabItemContent: View>: View {
    @Binding var selection: Tab
    let tabs: [Tab]
    let minimizeProgress: Double
    let hideOffset: CGFloat
    let motion: UnionTabBarMotion?
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
    ///   - motion: A source the bar follows for its travel off the bottom, for
    ///     hosts that write the offset at frame rate. Routed through this object
    ///     each write invalidates only the bar's own offset wrapper; supplied,
    ///     it takes precedence over `hideOffset`.
    ///   - hideOffset: Points to translate the bar down by, for hosts that would
    ///     rather send it off the bottom of the screen than shrink it in place.
    ///     A host with its own chrome stacked above the bar passes the same value
    ///     to both so the whole assembly leaves together. Independent of
    ///     `minimizeProgress`; pass 0 to that to suppress the shrink entirely.
    public init(
        selection: Binding<Tab>,
        tabs: [Tab],
        minimizeProgress: Double = 0,
        hideOffset: CGFloat = 0,
        motion: UnionTabBarMotion? = nil,
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
        self.hideOffset = hideOffset
        self.motion = motion
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
                BarTravel(motion: motion, staticOffset: hideOffset, animation: minimizeAnimation, bar: glassTabBar)
                    .padding(.horizontal, 22)
                    .padding(.bottom, UnionTabBarMetrics.restingBottomInset)
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


    /// Where the centre slot opens: after the first half of the tabs, so an
    /// even count splits evenly and an odd one leaves the larger half leading.
    private var centerSlotIndex: Int { (tabs.count + 1) / 2 }

    @available(iOS 26, *)
    private var glassTabBar: some View {
        CenterSlotRow(motion: motion) { slotWidth in
            glassTabBar(slotWidth: slotWidth)
        }
    }

    /// The bar with its centre slot held open by `slotWidth`. The slot is a
    /// gap in the row of items that a host can fill with chrome of its own,
    /// such as the sleeve of what is playing once its dock has stepped aside;
    /// its frame is reported back through the motion source so the host can
    /// land something on it exactly. A hairline stands in when it is shut so
    /// the item row and the control behind it always agree on the layout.
    @available(iOS 26, *)
    private func glassTabBar(slotWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.element) { index, tab in
                if index == centerSlotIndex {
                    centerSlot(width: slotWidth)
                }
                tabItemView(tab, selectedIndex == index)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity)
                    .frame(height: barHeight)
            }
        }
        .frame(maxWidth: CGFloat(tabs.count) * 86 + slotWidth)
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
                    slotIndex: motion == nil ? nil : centerSlotIndex,
                    slotWidth: slotWidth,
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
        }
        // Behind the control, so no SwiftUI gesture ever sits above UIKit's
        // recognizers (an overlay tap catcher broke the reselect gesture).
        // The control's dead zone lets action-tab touches fall through here.
        .background {
            HStack(spacing: 0) {
                ForEach(Array(tabs.enumerated()), id: \.element) { index, tab in
                    if index == centerSlotIndex {
                        Color.clear
                            .frame(width: slotWidth)
                            .allowsHitTesting(false)
                    }
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

    @available(iOS 26, *)
    private func centerSlot(width: CGFloat) -> some View {
        Color.clear
            .frame(width: width, height: barHeight)
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .global)
            } action: { frame in
                motion?.centerSlotFrame = frame
            }
    }

    private var legacyBody: some View {
        TabView(selection: $selection) {
            content
        }
        .overlay(alignment: .bottom) {
            GeometryReader { proxy in
                let gap = UIScreen.main.bounds.height - proxy.frame(in: .global).maxY
                BarTravel(motion: motion, staticOffset: hideOffset, animation: minimizeAnimation, bar: legacyTabBar)
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

/// A per-frame motion source for the bar's travel off the bottom of the
/// screen. A host following a finger writes `hideOffset` as often as every
/// frame; routed through this object, each write invalidates only the bar's
/// own offset wrapper. Passed through the host's body as a plain value, the
/// same writes re-evaluate the host's entire scene at the display's refresh
/// rate -- which is how the bar's travel was costing whole-app relayouts.
@MainActor
@Observable
public final class UnionTabBarMotion {
    public var hideOffset: CGFloat = 0

    /// How wide the gap in the middle of the item row stands. Zero keeps the
    /// row as it was; a host opening the slot writes this at frame rate the
    /// same way it writes `hideOffset`, and the items make room.
    public var centerSlotWidth: CGFloat = 0

    /// Where the centre slot sits on screen, in global coordinates, written by
    /// the bar as it lays out. A host lands its own chrome on this frame.
    public var centerSlotFrame: CGRect = .zero

    public init() {}
}

/// The one view that observes the slot width, so a frame-rate write reshapes
/// the item row and re-evaluates nothing above it. Shut, the slot is a
/// hairline rather than nothing: the row and the control behind it lay out
/// the same segments either way, so nothing shifts the moment it opens.
private struct CenterSlotRow<Row: View>: View {
    let motion: UnionTabBarMotion?
    let row: (CGFloat) -> Row

    var body: some View {
        row(motion.map { max(0.5, $0.centerSlotWidth) } ?? 0)
    }
}

/// The one view that observes the motion source, so a frame-rate write moves
/// the bar and touches nothing else.
private struct BarTravel<Bar: View>: View {
    let motion: UnionTabBarMotion?
    let staticOffset: CGFloat
    let animation: Animation?
    let bar: Bar

    var body: some View {
        let offset = motion?.hideOffset ?? staticOffset
        bar
            .offset(y: offset)
            .animation(animation, value: offset)
    }
}

// Returns nil from hitTest over action segments so the control never begins
// tracking there: the indicator cannot slide toward a tab that opens a sheet,
// and the touch falls through to the catcher behind the control.
final class DeadZoneSegmentedControl: TracklessSegmentedControl {
    var deadIndices: Set<Int> = []
    var onReselect: ((Int) -> Void)?

    // The selection commits on touch down, as a tab bar's does. The glass
    // around the control has a press gesture of its own, and on iOS 27 it
    // claims a quick touch before the control's own touch-up selection runs:
    // the capsule flashed and the indicator stayed put. Nothing that happens
    // to the touch after this point can take the switch back.
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first, numberOfSegments > 0, bounds.width > 0 {
            let index = segmentIndex(atX: touch.location(in: self).x)
            if !deadIndices.contains(index) {
                if index != selectedSegmentIndex {
                    selectedSegmentIndex = index
                    sendActions(for: .valueChanged)
                } else {
                    onReselect?(index)
                }
            }
        }
        super.touchesBegan(touches, with: event)
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard numberOfSegments > 0, bounds.width > 0 else {
            return super.hitTest(point, with: event)
        }
        if deadIndices.contains(segmentIndex(atX: point.x)) {
            return nil
        }
        return super.hitTest(point, with: event)
    }

    /// The segment under an x position, honouring fixed widths: a segment
    /// given a width keeps it and the rest share what is left, exactly as the
    /// control lays them out.
    func segmentIndex(atX x: CGFloat) -> Int {
        let count = numberOfSegments
        guard count > 0 else { return 0 }
        let fixed = (0..<count).map { widthForSegment(at: $0) }
        let fixedTotal = fixed.reduce(0, +)
        let autoCount = fixed.filter { $0 == 0 }.count
        let autoWidth = autoCount > 0 ? max(0, bounds.width - fixedTotal) / CGFloat(autoCount) : 0
        var cursor: CGFloat = 0
        for index in 0..<count {
            let width = fixed[index] == 0 ? autoWidth : fixed[index]
            if x < cursor + width { return index }
            cursor += width
        }
        return count - 1
    }
}

@MainActor
struct InteractiveSegmentedControl: UIViewRepresentable {
    var size: CGSize
    var barTint: Color
    @Binding var selectedIndex: Int
    var itemCount: Int
    // The centre slot is one more segment, fixed to the slot's width and dead
    // to touches, so the indicator and the hit regions stay aligned with the
    // items around the gap. Item indices are the host's; the control's own
    // indices step over the slot.
    var slotIndex: Int? = nil
    var slotWidth: CGFloat = 0
    var actionIndices: Set<Int> = []
    var canSelect: (Int) -> Bool = { _ in true }
    var onRejectedTap: ((Int) -> Void)? = nil
    var onReselect: ((Int) -> Void)? = nil

    private var segmentCount: Int { itemCount + (slotIndex == nil ? 0 : 1) }

    func controlIndex(forItem item: Int) -> Int {
        guard let slotIndex else { return item }
        return item >= slotIndex ? item + 1 : item
    }

    func itemIndex(forControl index: Int) -> Int? {
        guard let slotIndex else { return index }
        if index == slotIndex { return nil }
        return index > slotIndex ? index - 1 : index
    }

    private var deadControlIndices: Set<Int> {
        var dead = Set(actionIndices.map(controlIndex(forItem:)))
        if let slotIndex { dead.insert(slotIndex) }
        return dead
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UISegmentedControl {
        let items = (0..<segmentCount).map { _ in "" }
        let control = DeadZoneSegmentedControl(items: items)
        control.deadIndices = deadControlIndices
        if let slotIndex {
            control.setWidth(max(0.5, slotWidth), forSegmentAt: slotIndex)
        }
        control.selectedSegmentIndex = controlIndex(forItem: selectedIndex)

        control.selectedSegmentTintColor = UIColor(barTint)
        control.backgroundColor = .clear
        
        control.addTarget(
            context.coordinator,
            action: #selector(Coordinator.segmentChanged(_:)),
            for: .valueChanged
        )

        // valueChanged never fires when the current segment is touched again,
        // so the control reports the re-tap itself. Hosts rely on it to pop to
        // root or scroll to top.
        control.onReselect = { [coordinator = context.coordinator] index in
            coordinator.reselected(controlIndex: index)
        }

        return control
    }

    func updateUIView(_ uiView: UISegmentedControl, context: Context) {
        context.coordinator.parent = self
        (uiView as? DeadZoneSegmentedControl)?.deadIndices = deadControlIndices
        if let slotIndex, slotIndex < uiView.numberOfSegments {
            let width = max(0.5, slotWidth)
            if abs(uiView.widthForSegment(at: slotIndex) - width) > 0.01 {
                // A write inside an animated transaction is the slot settling
                // to one end, and the indicator has to arrive with the items
                // around it rather than ahead of them. Every other write is a
                // finger mid-scroll, and follows it exactly.
                if context.transaction.animation != nil {
                    UIView.animate(springDuration: 0.2, bounce: 0) {
                        uiView.setWidth(width, forSegmentAt: slotIndex)
                        uiView.layoutIfNeeded()
                    }
                } else {
                    UIView.performWithoutAnimation {
                        uiView.setWidth(width, forSegmentAt: slotIndex)
                        uiView.layoutIfNeeded()
                    }
                }
            }
        }
        let selected = controlIndex(forItem: selectedIndex)
        if uiView.selectedSegmentIndex != selected {
            uiView.selectedSegmentIndex = selected
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
            let index = parent.itemIndex(forControl: control.selectedSegmentIndex)
            guard let index, parent.canSelect(index) else {
                // Put the indicator back before it has a chance to animate.
                UIView.performWithoutAnimation {
                    control.selectedSegmentIndex = parent.controlIndex(forItem: parent.selectedIndex)
                    control.layoutIfNeeded()
                }
                if let index { parent.onRejectedTap?(index) }
                return
            }
            // Restoring the indicator can echo back as a change to the index the
            // control already sat on, which would reach the host as a fresh
            // selection of the tab it is already showing. Only a real move writes.
            guard index != parent.selectedIndex else { return }
            parent.selectedIndex = index
        }

        @MainActor func reselected(controlIndex: Int) {
            guard let index = parent.itemIndex(forControl: controlIndex),
                  parent.canSelect(index), index == parent.selectedIndex else { return }
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
