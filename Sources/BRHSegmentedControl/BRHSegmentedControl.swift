// Copyright © 2025 Brad Howes. All rights reserved.

import SwiftUI

/**
 Handmade SwiftUI view that mimics a SwiftUI `Picker` with segmented syling. Colorizes the selected segment with the
 `.tint` color. It supports three ways to supply segment labels:

 - using just a `count` value that will generate `count` segments each with an integer label, from `1` to `count`
 - using a collection of `String` values
 - using a closure that returns a `View` to use for a given segment index or segment index + String value.

 This implementation strives to replicate the behavior Apple's `Picker` segmented style. It is not a pixel-perfect
 implementation but (IMO) it is very close.

 NOTE: although this now works on macOS, it does not mimic the native control as well as it does on iOS. On macOS
 it simply responds to tap events, but the native gesture highlights a segment when the segment is clicked, and
 removes the highlight if the pointer moves outside of the segment. There is no dragging of the segment indicator.
 */
public struct BRHSegmentedControl<SegmentView: View, SegmentForegroundStyle: ShapeStyle>: View {
#if swift(>=6.0)
  @Environment(\.disableAnimations) var disableAnimations
#else
  private let disableAnimations = false
#endif
  private struct VB1 { @ViewBuilder let build: (Int) -> SegmentView }
  private struct VB2 { @ViewBuilder let build: (Int, String) -> SegmentView }

  private enum Generator {
    case numeric(count: Int, builder: VB1)
    case labels([String], builder: VB2)
    var count: Int {
      switch self {
      case .numeric(let count, _): return count
      case .labels(let labels, _): return labels.count
      }
    }
  }

  private let selectedIndex: Binding<Int>
  private let generator: Generator
  private let segmentForegroundStyler: (BRHSegmentedControlSupport.SegmentState) -> SegmentForegroundStyle

  private let segmentMinHeight: CGFloat = 32.0
  private let dividerHeight: CGFloat = 18.0
  private let cornerRadius: CGFloat = 6.0
  private let touchedScalingFactor: CGFloat = 0.9
  private var indicatorAnimation: Animation { .smooth(duration: disableAnimations ? 0.0 : 0.2) }
  private var foregroundStyleAnimation: Animation { .smooth(duration: disableAnimations ? 0.0 : 0.5) }

  internal enum Dragging {
    case start      // start of a dragging gesture
    case indicator  // dragging started in the selected segment
    case nothing    // dragging started in elsewhere
    case done       // end of a dragging gesture

    // Multiplier to grow a segment's frame's height. If not dragging indicator, allow for moving out of rectangle to
    // cancel a pending change, but if dragging the indicator then there is no cancelling.
    var heightMultiplier: CGFloat {
      switch self {
      case .indicator: return 100_000.0 // Large enough so that dragging does not 'cancel'
      case .nothing: return 2.0         // Cancel pending change if distance is twice height of segemnt
      default: return 0                 // No multiple for initial hit testing
      }
    }
  }

  // The new selected segment. Updated via drag movements. Once a drag is done, the value it holds will be used to
  // update the `selectedIndex` value.
  @State internal var pendingIndex: Int
  // Would be nice to combine dragging and dragLocation into one state managed by the DragGesture, but that would
  // require combining the per-segment `dragDetector` and the `DragGesture.updating` methods into one.
  @State internal var dragging: Dragging = .done
  @GestureState private var dragLocation: CGPoint = .zero
  // or geometry changes involving the selected segment
  @Namespace private var namespace

  private var pendingIsValid: Bool { pendingIndex >= 0 && pendingIndex < generator.count }
  private var selectedIndexIsValid: Bool {
    selectedIndex.wrappedValue >= 0 && selectedIndex.wrappedValue < generator.count
  }
  // Handle initial state where nothing is selected
  private var showIndicator: Bool { pendingIsValid && (dragging != .nothing || selectedIndexIsValid) }
  private var selectedViewIndex: Int { selectedIndex.wrappedValue.asViewIndex }
  private var pendingViewIndex: Int { pendingIndex.asViewIndex }

  /**
   Construct control with N segments that show integers 1 - N inclusive. The styling of the resulting segment labels is
   close to that of Apple's segmented style.

   - parameter selectedIndex: binding to the index of the selected item
   - parameter count: the number of segments to hold
   - parameter builder: closure to call for each segment to obtain the View to show. Receives index of segment.
   - parameter styler: closure to style the foreground of the segment to show state changes
   */
  public init(
    selectedIndex: Binding<Int>,
    count: Int,
    @ViewBuilder builder: @escaping (Int) -> SegmentView = BRHSegmentedControlSupport.defaultBuilderFromIndex,
    styler: @escaping (BRHSegmentedControlSupport.SegmentState) -> SegmentForegroundStyle
    = BRHSegmentedControlSupport.defaultForegroundStyler
  ) {
    self.selectedIndex = selectedIndex
    self.pendingIndex = selectedIndex.wrappedValue
    self.segmentForegroundStyler = styler
    self.generator = .numeric(count: count, builder: VB1(build: builder))
  }

  /**
   Construct new control with given set of segment titles. The styling is close to that of Apple's segmented style.

   - parameter selectedIndex: binding to the index of the selected item
   - parameter labels: collection of values to use for segment labels
   - parameter builder: closure to call for each segment to obtain the View to show. Receives index and label value.
   - parameter styler: closure to style the foreground of the segment to show state changes
   */
  public init(
    selectedIndex: Binding<Int>,
    labels: [String],
    @ViewBuilder builder: @escaping (Int, String) -> SegmentView
    = BRHSegmentedControlSupport.defaultBuilderFromIndexLabel,
    styler: @escaping (BRHSegmentedControlSupport.SegmentState) -> SegmentForegroundStyle
    = BRHSegmentedControlSupport.defaultForegroundStyler
  ) {
    self.selectedIndex = selectedIndex
    self.pendingIndex = selectedIndex.wrappedValue
    self.segmentForegroundStyler = styler
    self.generator = .labels(labels, builder: VB2(build: builder))
  }

  public var body: some View {
    HStack(spacing: 0.0) {
      switch generator {
      case let .numeric(count, wrapper): generateViews(count: count, builder: wrapper)
      case let .labels(labels, wrapper): generateViews(labels: labels, builder: wrapper)
      }
    }
#if os(iOS) || targetEnvironment(macCatalyst)
    .gesture(makeDragGesture())
#endif
    .background {
      if showIndicator {
        selectedIndicator
      }
    }
    .background {
      RoundedRectangle(cornerRadius: cornerRadius)
        .fill(.gray.opacity(0.2))
    }
    .reactToChange(of: selectedIndex.wrappedValue, calling: selectedIndexChanged)
  }

  internal func selectedIndexChanged(newValue: Int) {
    if newValue != pendingIndex {
      withAnimation(indicatorAnimation) {
        pendingIndex = newValue
      }
    }
  }

  private func generateViews(count: Int, builder: VB1) -> some View {
    // Generate dividers between segments. All dividers have an odd index.
    ForEach(0..<max(count * 2 - 1, 0), id: \.self) { index in
      if index.isSegmentIndex {
        let segmentIndex = index.asSegmentIndex
        segmentView(index: index, content: builder.build(segmentIndex))
      } else {
        dividerView(index: index)
      }
    }
  }

  private func generateViews(labels: [String], builder: VB2) -> some View {
    // Generate dividers between segments. All dividers have an odd index.
    ForEach(0..<max(labels.count * 2 - 1, 0), id: \.self) { index in
      if index.isSegmentIndex {
        let segmentIndex = index.asSegmentIndex
        segmentView(index: index, content: builder.build(segmentIndex, labels[segmentIndex]))
      } else {
        dividerView(index: index)
      }
    }
  }

  internal func segmentedState(for index: Int) -> BRHSegmentedControlSupport.SegmentState {
    if case .nothing = dragging {
      if pendingViewIndex == index && pendingIndex != selectedIndex.wrappedValue {
        return .touched
      }
      return selectedViewIndex == index ? .selected : .none
    }
    return pendingViewIndex == index ? .selected : .none
  }

  private func segmentView(index: Int, content: some View) -> some View {
    content
      .foregroundStyle(segmentForegroundStyler(segmentedState(for: index)))
      .animation(foregroundStyleAnimation, value: pendingIndex)
      .frame(minHeight: segmentMinHeight)
      .padding(.horizontal)
      .matchedGeometryEffect(id: index, in: namespace, isSource: true)
#if os(iOS) || targetEnvironment(macCatalyst)
      .background(dragDetector(index: index))
#else
      .contentShape(Rectangle())
      .onTapGesture {
        print(index, pendingIndex)
        pendingIndex = index.asSegmentIndex
        selectedIndex.wrappedValue = index.asSegmentIndex
      }
#endif
  }

  // Mimic Apple's style by hiding the dividers that are adjacent to the active segment
  private func dividerIsHidden(index: Int) -> Bool { index == pendingViewIndex - 1 || index == pendingViewIndex + 1 }
  private func dividerColor(index: Int) -> Color { .gray.opacity(dividerIsHidden(index: index) ? 0.0 : 0.3) }

  private func dividerView(index: Int) -> some View {
    Rectangle()
      .fill(.clear)
      .background(dividerColor(index: index))
      .frame(width: 1.0, height: dividerHeight)
      .disabled(true)
  }

  private var selectedIndicator: some View {
    RoundedRectangle(cornerRadius: cornerRadius)
      .fill(.tint)
    // Mimic Apple's style by slightly shrinking the selected indicator when touched
      .scaleEffect(dragging == .indicator ? touchedScalingFactor : 1.0)
      .animation(indicatorAnimation, value: dragging)
      .matchedGeometryEffect(
        id: dragging == .nothing ? selectedViewIndex : pendingViewIndex,
        in: namespace,
        isSource: false
      )
  }

#if os(iOS) || targetEnvironment(macCatalyst)

  private func makeDragGesture() -> some Gesture {
    // The DragGesture provides the necessary functionality to replicate Apple's segmented style behavior.
    // Zero min distance so that it will start immediately upon a touch. The location is used by the `dragDetector`
    // method below to update UI state as the touch moves.
    let dragGesture = DragGesture(minimumDistance: 0.0, coordinateSpace: .global)
      .updating($dragLocation) { dragGestureUpdate(val: $0, state: &$1, trans: $2) }
      .onEnded { _ in dragGestureEnded() }
    return dragGesture
  }

  internal func dragGestureUpdate(val: DragGesture.Value, state: inout CGPoint, trans: Transaction) {
    if dragging == .done {
      withAnimation(indicatorAnimation) {
        dragging = .start
      }
    }
    state = val.location
  }

  internal func dragGestureEnded() {
    withAnimation(indicatorAnimation) {
      dragging = .done
      if pendingIsValid {
        selectedIndex.wrappedValue = pendingIndex
      }
    }
  }

  /**
   Detect when a drag change affects the view. Each segment (including dividers) will call this to determine if the
   drag is interacting with the view. There are three state changes we are interested in:

   - dragging the indicator to a new location
   - dragging in an unselected segment to dim the segment's title and make the segment's index pending
   - dragging out of an unselected segment to undim and cancel the pending index
   */
  internal func dragDetector(index: Int) -> some View {
    GeometryReader { proxy in
      let frame = proxy.frame(in: .global)
      let bounds = frame.insetBy(dx: 0, dy: -frame.height * dragging.heightMultiplier)
      let isInsideSegment = bounds.contains(dragLocation)

      Color.clear
        .reactToChange(of: isInsideSegment) { dragMovement(index: index, isInside: $0) }
    }
  }

  internal func dragMovement(index: Int, isInside: Bool) {
    guard index.isSegmentIndex, dragging != .done else { return }

    let segmentIndex = index.asSegmentIndex
    if dragging == .start && isInside {
      withAnimation(indicatorAnimation) {
        dragging = pendingIndex == segmentIndex && pendingIsValid ? .indicator : .nothing
      }
    }

    if isInside {
      if pendingIndex != segmentIndex {
        withAnimation(indicatorAnimation) {
          // This either moves the indicator or dims a segment's label depending on dragging state
          pendingIndex = segmentIndex
        }
      }
    } else if dragging == .nothing && pendingIndex == segmentIndex {
      withAnimation(indicatorAnimation) {
        // Revert an index change since the touch moved too far away from segment.
        pendingIndex = selectedIndex.wrappedValue
      }
    }
  }

#endif

}

extension View {

  @ViewBuilder
  internal func reactToChange<V: Equatable>(of value: V, calling closure: @escaping (V) -> Void) -> some View {
    if #available(iOS 17.0, tvOS 17.0, macOS 14.0, watchOS 10.0, *) {
      self.onChange(of: value) { _, newValue in closure(newValue) }
    } else {
      self.onChange(of: value, perform: closure)
    }
  }
}

// Transformations between segment and view indices
fileprivate extension Int {
  var asViewIndex: Int { self * 2 }
  var asSegmentIndex: Int { self / 2 }
  var isSegmentIndex: Bool { self % 2 == 0 }
}

#if swift(>=6.0)

extension EnvironmentValues {
  @Entry public var disableAnimations: Bool = false
}

extension BRHSegmentedControl {
  public func disableAnimations(_ value: Bool) -> some View {
    environment(\.disableAnimations, value)
  }
}

#endif

internal struct PreviewContent: View {
  let numbers = ["1", "2", "3", "4"]
  let letters = ["A", "B", "C", "D"]
  let systemImages = ["a.circle", "b.circle", "c.circle", "d.circle"]
  @State var selectedIndex: Int = 1
  @State var customTintColor: Bool = false

  var body: some View {
    VStack(spacing: 16) {
      VStack {
        header("Simple integer labels")
        BRHSegmentedControl(selectedIndex: $selectedIndex, count: numbers.count)
      }
      VStack {
        header("Strings w/ foreground styler")
        BRHSegmentedControl(selectedIndex: $selectedIndex, labels: letters, styler: styler1)
      }
      VStack {
        header("Segment builder w/ foreground styler")
        BRHSegmentedControl(selectedIndex: $selectedIndex, count: numbers.count, builder: builder, styler: styler2)
#if swift(>=6.0)
        .environment(\.disableAnimations, true)
#endif
      }
#if os(iOS) || os(tvOS) || os(macOS) || targetEnvironment(macCatalyst)
      VStack {
        header("Apple's Picker w/ segmented style")
        Picker(selection: $selectedIndex) {
          ForEach(numbers.indices, id: \.self) { index in
            Text(numbers[index])
          }
        } label: {
          Text("Picker")
        }
        .pickerStyle(SegmentedPickerStyle())
      }
#endif
      HStack() {
        Spacer()
        Toggle(isOn: $customTintColor) {
          Text("Use custom tint color")
        }
        Spacer()
      }
    }
    .tint(customTintColor ? .red : .accentColor)
    .animation(.smooth, value: customTintColor)
  }

  private func styler1(_ state: BRHSegmentedControlSupport.SegmentState) -> some ShapeStyle {
    switch state {
    case .none: return Color.indigo
    case .touched: return Color.blue
    case .selected: return Color.green
    }
  }

  private func styler2(_ state: BRHSegmentedControlSupport.SegmentState) -> some ShapeStyle {
    switch state {
    case .none: return Color.primary
    case .touched: return Color.secondary
    case .selected: return Color(light: Color.white, dark: Color.black)
    }
  }

  private func builder(_ index: Int) -> some View {
    Label(numbers[index], systemImage: systemImages[index])
      .labelStyle(.iconOnly)
  }

  private func header(_ text: String) -> some View {
    Text(text)
      .font(.footnote)
      .italic()
  }
}

struct NumericSegmentedControl_Previews: PreviewProvider {
  static var previews: some View {
    PreviewContent()
  }
}
