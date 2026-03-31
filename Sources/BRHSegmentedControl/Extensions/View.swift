// Copyright © 2026 Brad Howes. All rights reserved.

import SwiftUI

extension View {

  @ViewBuilder
  func reactToChange<V: Equatable>(of value: V, calling closure: @escaping (V) -> Void) -> some View {
    if #available(iOS 17.0, tvOS 17.0, macOS 14.0, watchOS 10.0, *) {
      self.onChange(of: value) { _, newValue in closure(newValue) }
    } else {
      self.onChange(of: value, perform: closure)
    }
  }
}
