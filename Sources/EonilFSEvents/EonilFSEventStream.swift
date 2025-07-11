//
//  EonilFSEventStream.swift
//  FSEventStreamWrapper
//
//  Created by Hoon H. on 2016/10/02.
//
//

import CoreServices
import Foundation

/// Replicate `FSEventStream`'s features and interface as close as possible in Swift-y interface.
/// Apple can provide official wrapper in future release, and the name of the future wrapper type
/// is likely to be `FSEventStream`. So this wrapper suffixes name with `~UnofficialWrapper` to
/// avoid
/// potential future name conflict.
///
/// - TODO: Device watching support.
///
public final class EonilFSEventStream: @unchecked Sendable {
  // This must be a non-nil value if an instance of this class has been created successfully.
  private var rawref: FSEventStreamRef!
  private let handler: @Sendable (EonilFSEventsEvent) -> Void

  /*
   *  FSEventStreamCreate()
   *
   *  Discussion:
   *    Creates a new FS event stream object with the given parameters.
   *    In order to start receiving callbacks you must also call
   *    FSEventStreamScheduleWithRunLoop() and FSEventStreamStart().
   *
   *  Parameters:
   *
   *    allocator:
   *      The CFAllocator to be used to allocate memory for the stream.
   *      Pass NULL or kCFAllocatorDefault to use the current default
   *      allocator.
   *
   *    callback:
   *      An FSEventStreamCallback which will be called when FS events
   *      occur.
   *
   *    context:
   *      A pointer to the FSEventStreamContext structure the client
   *      wants to associate with this stream.  Its fields are copied out
   *      into the stream itself so its memory can be released after the
   *      stream is created.  Passing NULL is allowed and has the same
   *      effect as passing a structure whose fields are all set to zero.
   *
   *    pathsToWatch:
   *      A CFArray of CFStringRefs, each specifying a path to a
   *      directory, signifying the root of a filesystem hierarchy to be
   *      watched for modifications.
   *
   *    sinceWhen:
   *      The service will supply events that have happened after the
   *      given event ID. To ask for events "since now" pass the constant
   *      kFSEventStreamEventIdSinceNow. Often, clients will supply the
   *      highest-numbered FSEventStreamEventId they have received in a
   *      callback, which they can obtain via the
   *      FSEventStreamGetLatestEventId() accessor. Do not pass zero for
   *      sinceWhen, unless you want to receive events for every
   *      directory modified since "the beginning of time" -- an unlikely
   *      scenario.
   *
   *    latency:
   *      The number of seconds the service should wait after hearing
   *      about an event from the kernel before passing it along to the
   *      client via its callback. Specifying a larger value may result
   *      in more effective temporal coalescing, resulting in fewer
   *      callbacks and greater overall efficiency.
   *
   *    flags:
   *      Flags that modify the behavior of the stream being created. See
   *      FSEventStreamCreateFlags.
   *
   *  Result:
   *    A valid FSEventStreamRef.
   *
   *  Availability:
   *    Mac OS X:         in version 10.5 and later in CoreServices.framework
   *    CarbonLib:        not available
   *    Non-Carbon CFM:   not available
   */
  public init(
    pathsToWatch: [String],
    sinceWhen: EonilFSEventsEventID,
    latency: TimeInterval,
    flags: EonilFSEventsCreateFlags,
    handler: @escaping @Sendable (EonilFSEventsEvent) -> Void
  ) throws {
    // `CoreServices.FSEventStreamCallback` is C callback and follows
    // C convention. Which means it cannot capture any external value.
    let callback: CoreServices.FSEventStreamCallback = { (
      _: ConstFSEventStreamRef,
      _ clientCallBackInfo: UnsafeMutableRawPointer?,
      _ numEvents: Int,
      _ eventPaths: UnsafeMutableRawPointer,
      _ eventFlags: UnsafePointer<FSEventStreamEventFlags>,
      _ eventIds: UnsafePointer<FSEventStreamEventId>
    ) in
      guard let clientCallBackInfo1 = clientCallBackInfo else {
        EonilFSEventsIllogicalErrorLog(code: .missingContextRawPointerValue).cast()
        return
      }
      let eventPaths1: CFArray = Unmanaged.fromOpaque(eventPaths).takeUnretainedValue()
      guard let eventPaths2 = eventPaths1 as NSArray as? [NSString] as [String]? else {
        EonilFSEventsIllogicalErrorLog(
          code: .unexpectedPathValueType,
          message: "Cannot convert `\(eventPaths1)` into [String]."
        ).cast()
        return
      }
      guard numEvents == eventPaths2.count else {
        EonilFSEventsIllogicalErrorLog(
          code: .unmatchedEventParameterCounts,
          message: "Event count is `\(numEvents)`, but path count is `\(eventPaths2.count)`"
        ).cast()
        return
      }
      let unmanagedPtr: Unmanaged<EonilFSEventStream> = Unmanaged.fromOpaque(clientCallBackInfo1)
      let self1 = unmanagedPtr.takeUnretainedValue()
      for i in 0..<numEvents {
        let eventPath = eventPaths2[i]
        let eventFlag = eventFlags[i]
        let eventFlag1 = EonilFSEventsEventFlags(rawValue: eventFlag)
        let eventId = eventIds[i]
        let eventId1 = EonilFSEventsEventID(rawValue: eventId)
        let event = EonilFSEventsEvent(
          path: eventPath,
          flag: eventFlag1,
          ID: eventId1
        )
        self1.handler(event)
      }
    }
    self.handler = handler
    let unmanagedPtr = Unmanaged.passUnretained(self)
    var context = FSEventStreamContext(
      version: 0,
      info: unmanagedPtr.toOpaque(),
      retain: nil,
      release: nil,
      copyDescription: nil
    )
    func getPtr<T>(value: UnsafeMutablePointer<T>) -> UnsafeMutablePointer<T> {
      value
    }
    // Get pointer to a value on stack.
    // Stream creation function will copy the value, so it's safe to keep it
    // on stack.
    let context1: UnsafeMutablePointer<FSEventStreamContext>? = getPtr(value: &context)
    let pathsToWatch1: CFArray = pathsToWatch as [NSString] as NSArray as CFArray
    let sinceWhen1: FSEventStreamEventId = sinceWhen.rawValue
    let latency1: CFTimeInterval = latency as CFTimeInterval
    // Always use CF types to avoid copying cost. But I am pretty sure that this
    // ultimately trigger copying inside of the system framework...
    let flags1: FSEventStreamCreateFlags = flags.union(.useCFTypes).rawValue
    guard let newRawref = FSEventStreamCreate(
      nil,
      callback,
      context1,
      pathsToWatch1,
      sinceWhen1,
      latency1,
      flags1
    ) else {
      throw EonilFSEventsError(code: .cannotCreateStream)
    }
    self.rawref = newRawref
  }

  deinit {
    // It seems `rawref` does not get deallocated according to Instruments:
    // Run EonilFSEventsDemoGUI via Instruments with "Leaks" and close the main window.
    FSEventStreamRelease(self.rawref)
  }
}

/*
 *  Accessors
 */
public extension EonilFSEventStream {
  /*
   *  FSEventStreamGetLatestEventId()
   *
   *  Discussion:
   *    Fetches the sinceWhen property of the stream.  Upon receiving an
   *    event (and just before invoking the client's callback) this
   *    attribute is updated to the highest-numbered event ID mentioned
   *    in the event.
   *
   *  Parameters:
   *
   *    streamRef:
   *      A valid stream.
   *
   *  Result:
   *    The sinceWhen attribute of the stream.
   *
   *  Availability:
   *    Mac OS X:         in version 10.5 and later in CoreServices.framework
   *    CarbonLib:        not available
   *    Non-Carbon CFM:   not available
   */

  func getLatestEventID() -> EonilFSEventsEventID {
    let eventId = FSEventStreamGetLatestEventId(rawref)
    let eventID1 = EonilFSEventsEventID(rawValue: eventId)
    return eventID1
  }

  /*
   *  FSEventStreamCopyPathsBeingWatched()
   *
   *  Discussion:
   *    Fetches the paths supplied when the stream was created via one of
   *    the FSEventStreamCreate...() functions.
   *
   *  Parameters:
   *
   *    streamRef:
   *      A valid stream.
   *
   *  Result:
   *    A CFArray of CFStringRefs corresponding to those supplied when
   *    the stream was created. Ownership follows the Copy rule.
   *
   *  Availability:
   *    Mac OS X:         in version 10.5 and later in CoreServices.framework
   *    CarbonLib:        not available
   *    Non-Carbon CFM:   not available
   */
  func copyPathsBeingWatched() -> [String] {
    let ret = FSEventStreamCopyPathsBeingWatched(rawref)
    guard let paths = ret as NSArray as? [NSString] as [String]? else {
      EonilFSEventsIllogicalErrorLog(
        code: .unexpectedPathValueType,
        message: "Cannot convert retrieved object `\(ret)` into `[String]`."
      ).cast()
      // Unrecoverable.
      fatalError()
    }
    return paths
  }
}

/*
 *  ScheduleWithRunLoop, UnscheduleFromRunLoop, Invalidate
 */
public extension EonilFSEventStream {
  /*
   *  FSEventStreamSetDispatchQueue()
   *
   *  Discussion:
   *    This function schedules the stream on the specified dispatch
   *    queue. The caller is responsible for ensuring that the stream is
   *    scheduled on a dispatch queue and that the queue is started. If
   *    there is a problem scheduling the stream on the queue an error
   *    will be returned when you try to Start the stream. To start
   *    receiving events on the stream, call FSEventStreamStart(). To
   *    remove the stream from the queue on which it was scheduled, call
   *    FSEventStreamSetDispatchQueue() with a NULL queue parameter or
   *    call FSEventStreamInvalidate() which will do the same thing.
   *    Note: you must eventually call FSEventStreamInvalidate() and it
   *    is an error to call FSEventStreamInvalidate() without having the
   *    stream either scheduled on a runloop or a dispatch queue, so do
   *    not set the dispatch queue to NULL before calling
   *    FSEventStreamInvalidate().
   *
   *  Parameters:
   *
   *    streamRef:
   *      A valid stream.
   *
   *    q:
   *      The dispatch queue to use to receive events (or NULL to to stop
   *      receiving events from the stream).
   *
   *  Availability:
   *    Mac OS X:         in version 10.6 and later in CoreServices.framework
   *    CarbonLib:        not available
   *    Non-Carbon CFM:   not available
   */
  func setDispatchQueue(_ q: DispatchQueue?) {
    FSEventStreamSetDispatchQueue(self.rawref, q)
  }

  /*
   *  FSEventStreamInvalidate()
   *
   *  Discussion:
   *    Invalidates the stream, like CFRunLoopSourceInvalidate() does for
   *    a CFRunLoopSourceRef.  It will be unscheduled from any runloops
   *    or dispatch queues upon which it had been scheduled.
   *    FSEventStreamInvalidate() can only be called on the stream after
   *    you have called FSEventStreamScheduleWithRunLoop() or
   *    FSEventStreamSetDispatchQueue().
   *
   *  Parameters:
   *
   *    streamRef:
   *      A valid stream.
   *
   *  Availability:
   *    Mac OS X:         in version 10.5 and later in CoreServices.framework
   *    CarbonLib:        not available
   *    Non-Carbon CFM:   not available
   */
  func invalidate() {
    FSEventStreamInvalidate(self.rawref)
  }
}

/*
 *  Start, Flush, Stop
 */
public extension EonilFSEventStream {
  /*
   *  FSEventStreamStart()
   *
   *  Discussion:
   *    Attempts to register with the FS Events service to receive events
   *    per the parameters in the stream. FSEventStreamStart() can only
   *    be called once the stream has been scheduled on at least one
   *    runloop, via FSEventStreamScheduleWithRunLoop(). Once started,
   *    the stream can be stopped via FSEventStreamStop().
   *
   *  Parameters:
   *
   *    streamRef:
   *      A valid stream.
   *
   *  Result:
   *    True if it succeeds, otherwise False if it fails.  It ought to
   *    always succeed, but in the event it does not then your code
   *    should fall back to performing recursive scans of the directories
   *    of interest as appropriate.
   *
   *  Availability:
   *    Mac OS X:         in version 10.5 and later in CoreServices.framework
   *    CarbonLib:        not available
   *    Non-Carbon CFM:   not available
   */
  func start() throws {
    switch FSEventStreamStart(self.rawref) {
    case false:
      throw EonilFSEventsError(code: .cannotStartStream)
    case true:
      return
    }
  }

  /*
   *  FSEventStreamFlushAsync()
   *
   *  Discussion:
   *    Asks the FS Events service to flush out any events that have
   *    occurred but have not yet been delivered, due to the latency
   *    parameter that was supplied when the stream was created.  This
   *    flushing occurs asynchronously -- do not expect the events to
   *    have already been delivered by the time this call returns.
   *    FSEventStreamFlushAsync() can only be called after the stream has
   *    been started, via FSEventStreamStart().
   *
   *  Parameters:
   *
   *    streamRef:
   *      A valid stream.
   *
   *  Result:
   *    The largest event id of any event ever queued for this stream,
   *    otherwise zero if no events have been queued for this stream.
   *
   *  Availability:
   *    Mac OS X:         in version 10.5 and later in CoreServices.framework
   *    CarbonLib:        not available
   *    Non-Carbon CFM:   not available
   */
  func flushAsync() -> EonilFSEventsEventID {
    let eventId = FSEventStreamFlushAsync(rawref)
    let eventId1 = EonilFSEventsEventID(rawValue: eventId)
    return eventId1
  }

  /*
   *  FSEventStreamFlushSync()
   *
   *  Discussion:
   *    Asks the FS Events service to flush out any events that have
   *    occurred but have not yet been delivered, due to the latency
   *    parameter that was supplied when the stream was created.  This
   *    flushing occurs synchronously -- by the time this call returns,
   *    your callback will have been invoked for every event that had
   *    already occurred at the time you made this call.
   *    FSEventStreamFlushSync() can only be called after the stream has
   *    been started, via FSEventStreamStart().
   *
   *  Parameters:
   *
   *    streamRef:
   *      A valid stream.
   *
   *  Availability:
   *    Mac OS X:         in version 10.5 and later in CoreServices.framework
   *    CarbonLib:        not available
   *    Non-Carbon CFM:   not available
   */
  func flushSync() {
    FSEventStreamFlushSync(self.rawref)
  }

  /*
   *  FSEventStreamStop()
   *
   *  Discussion:
   *    Unregisters with the FS Events service.  The client callback will
   *    not be called for this stream while it is stopped.
   *    FSEventStreamStop() can only be called if the stream has been
   *    started, via FSEventStreamStart(). Once stopped, the stream can
   *    be restarted via FSEventStreamStart(), at which point it will
   *    resume receiving events from where it left off ("sinceWhen").
   *
   *  Parameters:
   *
   *    streamRef:
   *      A valid stream.
   *
   *  Availability:
   *    Mac OS X:         in version 10.5 and later in CoreServices.framework
   *    CarbonLib:        not available
   *    Non-Carbon CFM:   not available
   */
  func stop() {
    FSEventStreamStop(self.rawref)
  }
}

/*
 *  Debugging
 */
extension EonilFSEventStream {
  /*
   *  FSEventStreamShow()
   *
   *  Discussion:
   *    Prints a description of the supplied stream to stderr. For
   *    debugging only.
   *
   *  Parameters:
   *
   *    streamRef:
   *      A valid stream.
   *
   *  Availability:
   *    Mac OS X:         in version 10.5 and later in CoreServices.framework
   *    CarbonLib:        not available
   *    Non-Carbon CFM:   not available
   */
  private func show() {
    FSEventStreamShow(self.rawref)
  }

  /*
   *  FSEventStreamCopyDescription()
   *
   *  Discussion:
   *    Returns a CFStringRef containing the description of the supplied
   *    stream. For debugging only.
   *
   *  Result:
   *    A CFStringRef containing the description of the supplied stream.
   *    Ownership follows the Copy rule.
   *
   *  Availability:
   *    Mac OS X:         in version 10.5 and later in CoreServices.framework
   *    CarbonLib:        not available
   *    Non-Carbon CFM:   not available
   */
  private func copyDescription() -> String {
    let desc = FSEventStreamCopyDescription(rawref)
    let desc1 = desc as String
    return desc1
  }

  /*
   * FSEventStreamSetExclusionPaths()
   *
   * Discussion:
   *    Sets directories to be filtered from the EventStream.
   *    A maximum of 8 directories maybe specified.
   *
   * Result:
   *    True if it succeeds, otherwise False if it fails.
   *
   * Availability:
   *    Mac OS X:         in version 10.9 and later in CoreServices.framework
   *    CarbonLib:        not available
   *    Non-Carbon CFM:   not available
   */
  @discardableResult
  public func setExclusionPaths(_ pathsToExclude: [String]) -> Bool {
    let pathsToExclude1 = pathsToExclude as [NSString] as NSArray as CFArray
    return FSEventStreamSetExclusionPaths(self.rawref, pathsToExclude1)
  }
}

extension EonilFSEventStream: CustomStringConvertible, CustomDebugStringConvertible {
  public var description: String {
    self.copyDescription()
  }

  public var debugDescription: String {
    self.copyDescription()
  }
}

public extension EonilFSEventStream {
  static func events(
    pathsToWatch: [String],
    sinceWhen: EonilFSEventsEventID = .now,
    latency: TimeInterval = 0,
    flags: EonilFSEventsCreateFlags = [],
    queue: DispatchQueue = .global(qos: .background)
  ) -> AsyncStream<EonilFSEventsEvent> {
    AsyncStream { continuation in
      let stream: EonilFSEventStream
      do {
        stream = try EonilFSEventStream(
          pathsToWatch: pathsToWatch,
          sinceWhen: sinceWhen,
          latency: latency,
          flags: flags
        ) { event in
          continuation.yield(event)
        }
        stream.setDispatchQueue(queue)
        try stream.start()
      } catch {
        continuation.finish()
        return
      }

      continuation.onTermination = { _ in
        stream.stop()
        stream.invalidate()
      }
    }
  }
}
