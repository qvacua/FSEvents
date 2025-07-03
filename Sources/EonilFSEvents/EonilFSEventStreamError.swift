//
//  EonilFSEventStreamError.swift
//  EonilFSEvents
//
//  Created by Hoon H. on 2016/10/02.
//
//

public struct EonilFSEventsError: Error, Sendable {
  public var code: EonilFSEventsErrorCode
  public var message: String?
  init(code: EonilFSEventsErrorCode) {
    self.code = code
  }

  init(code: EonilFSEventsErrorCode, message: String) {
    self.code = code
    self.message = message
  }
}

public enum EonilFSEventsErrorCode: Sendable {
  case cannotCreateStream
  case cannotStartStream
}
