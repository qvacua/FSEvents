//
//  EonilFSEventStreamIllogicalErrorLog.swift
//  EonilFSEvents
//
//  Created by Hoon H. on 2016/10/02.
//
//

import Foundation
import os

/// An error that is very unlikely to happen if this library code is properly written.
///
public struct EonilFSEventsIllogicalErrorLog: Sendable {
  public var code: EonilFSEventsCriticalErrorCode
  public var message: String?

  init(code: EonilFSEventsCriticalErrorCode) {
    self.code = code
  }

  init(code: EonilFSEventsCriticalErrorCode, message: String) {
    self.code = code
    self.message = message
  }

  func cast() {
    EonilFSEventsIllogicalErrorLog.handler(self)
  }

  /// Can be called at any thread.
  public static var handler: @Sendable (EonilFSEventsIllogicalErrorLog) -> Void {
    get {
      lock.withLock {
        self._handler
      }
    }
    set {
      lock.withLock {
        self._handler = newValue
      }
    }
  }

  private nonisolated(unsafe) static var _handler: @Sendable (EonilFSEventsIllogicalErrorLog)
    -> Void = { assertionFailure("EonilFSEvents: \($0)") }
}

public enum EonilFSEventsCriticalErrorCode: Sendable {
  case missingContextRawPointerValue
  case unexpectedPathValueType
  case unmatchedEventParameterCounts
}

private let lock = OSAllocatedUnfairLock()
