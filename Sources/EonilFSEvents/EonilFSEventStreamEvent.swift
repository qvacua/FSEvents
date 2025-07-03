//
//  EonilFSEventStreamEvent.swift
//  EonilFSEvents
//
//  Created by Hoon H. on 2016/10/02.
//
//

public struct EonilFSEventsEvent: Sendable {
  public var path: String
  public var flag: EonilFSEventsEventFlags?
  public var ID: EonilFSEventsEventID?
}
