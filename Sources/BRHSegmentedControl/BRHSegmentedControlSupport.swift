// Copyright © 2026 Brad Howes. All rights reserved.

import SwiftUI

public enum BRHSegmentedControlSupport {

  /**
   The UI state of a segment. Determines the foreground styling of the segement's view.

   - `selected` - the segment is currently selected/active
   - `touched` - the segment is not selected/active but is being touched
   - `none` - the segment has a normal appearance
   */
  public enum SegmentState {
    case selected
    case touched
    case none
  }

  /**
   Create a View from a segment index value

   - parameter index: the segment index
   - returns: a View to use for the segment
   */
  @ViewBuilder
  public static func defaultBuilderFromIndex(_ index: Int) -> some View {
    Text("\(index + 1)")
      .font(.footnote)
      .fontWeight(.medium)
      .lineLimit(1)
  }

  /**
   Create a View from a segment index value and a string value

   - parameter index the segment index
   - parameter label the string value for the segment
   - returns a View to use for the segment
   */
  @ViewBuilder
  public static func defaultBuilderFromIndexLabel(_ index: Int, _ label: String) -> some View {
    Text(label)
      .font(.footnote)
      .fontWeight(.medium)
      .lineLimit(1)
  }

  /**
   Obtain foreground styling for a SegmentState value.

   - parameter state to style for
   - returns: Color to use for the foreground styling of the segment's view
   */
  public static func defaultForegroundStyler(_ state: SegmentState) -> some ShapeStyle {
    // Mimic Apple's style by dimming content of a non-selected segment when touch position enters it; undim when
    // it leaves.
    switch state {
    case .none: return Color.primary
    case .touched: return Color.secondary
    case .selected: return Color.primary
    }
  }
}
