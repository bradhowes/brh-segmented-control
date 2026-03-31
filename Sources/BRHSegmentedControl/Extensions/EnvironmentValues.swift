// Copyright © 2026 Brad Howes. All rights reserved.

import SwiftUI

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
