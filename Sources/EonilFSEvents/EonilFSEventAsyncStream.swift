//
//  EonilFSEventAsyncStream.swift
//  EonilFSEvents
//
//  Created by Tae Won Ha on 2026/04/03.
//

import Foundation
import os

public final class EonilFSEventAsyncStream: Sendable {
  private let fsStream: EonilFSEventStream
  private let stoppedLock = OSAllocatedUnfairLock(initialState: false) // alreadyStopped = false
  private let continuation: AsyncStream<EonilFSEventsEvent>.Continuation

  public let asyncStream: AsyncStream<EonilFSEventsEvent>

  public init(
    pathsToWatch: [String],
    sinceWhen: EonilFSEventsEventID = .now,
    latency: TimeInterval = 0,
    flags: EonilFSEventsCreateFlags = [],
    queue: DispatchQueue = .global(qos: .background)
  ) throws {
    let (asyncStream, continuation) = AsyncStream.makeStream(of: EonilFSEventsEvent.self)
    self.asyncStream = asyncStream
    self.continuation = continuation

    self.fsStream = try EonilFSEventStream(
      pathsToWatch: pathsToWatch,
      sinceWhen: sinceWhen,
      latency: latency,
      flags: flags
    ) { event in
      continuation.yield(event)
    }
    self.fsStream.setDispatchQueue(queue)
    
    do {
      try self.fsStream.start()
    } catch {
      // deinit won't be called since init fails here.
      continuation.finish()
      
      // fsStream is fully init'ed and it seems that we have to call invalidate since we set
      // the DispatchQueue.
      // https://developer.apple.com/documentation/coreservices/1446990-fseventstreaminvalidate
      self.fsStream.invalidate()
      
      throw error
    }
  }

  deinit {
    stop()
  }

  public func stop() {
    // The doc does not specify what happens when stopping an already stopped FSEventStream.
    stoppedLock.withLock { alreadyStopped in
      if alreadyStopped { return }
      alreadyStopped = true
      
      self.continuation.finish()
      self.fsStream.stop()
      self.fsStream.invalidate()
    }
  }
}
