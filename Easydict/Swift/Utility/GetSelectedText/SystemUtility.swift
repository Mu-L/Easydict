//
//  SystemUtility.swift
//  Easydict
//
//  Created by tisfeng on 2024/10/3.
//  Copyright © 2024 izual. All rights reserved.
//

import AXSwift
import AXSwiftExt
import Carbon
import KeySender

// MARK: - SystemUtility

@objcMembers
class SystemUtility: NSObject {
    /// Post copy event
    static func postCopyEvent() {
        let sender = KeySender(key: .c, modifiers: .command)
        sender.sendGlobally()
    }

    /// Post paste event
    static func postPasteEvent() {
        let sender = KeySender(key: .v, modifiers: .command)
        sender.sendGlobally()
    }

    /// Copy text and paste text
    static func copyTextAndPaste(_ text: String) {
        logInfo("Copy text and paste text: \(text)")

        let pasteboard = NSPasteboard.general
        let initialChangeCount = pasteboard.changeCount

        // Copy text to clipboard
        text.copyToClipboard()
        logInfo("Copyed text to clipboard")

        SharedUtilities.pollTask {
            if pasteboard.changeCount != initialChangeCount {
                return true
            }
            return false
        }

        // Paste text
        postPasteEvent()

        logInfo("Pasted text: \(pasteboard.string()!)")
    }

    /// Paste text safely
    static func pasteTextSafely(_ text: String) {
        logInfo("Paste text safely")
        NSPasteboard.general.performTemporaryTask {
            copyTextAndPaste(text)
        }
    }
}

// 模拟粘贴
func pastePrivacy(_ text: String) {
    NSPasteboard.general.performTemporaryTask {
        copyToClipboard(text)
        callSystemPaste()
    }
}

func callSystemPaste() {
    func keyEvents(forPressAndReleaseVirtualKey virtualKey: Int) -> [CGEvent] {
        let eventSource = CGEventSource(stateID: .privateState)
        return [
            CGEvent(
                keyboardEventSource: eventSource, virtualKey: CGKeyCode(virtualKey), keyDown: true
            )!,
            CGEvent(
                keyboardEventSource: eventSource, virtualKey: CGKeyCode(virtualKey), keyDown: false
            )!,
        ]
    }

    let tapLocation = CGEventTapLocation.cgAnnotatedSessionEventTap
    let events = keyEvents(forPressAndReleaseVirtualKey: 9)

    events.forEach {
        $0.flags = .maskCommand
        $0.post(tap: tapLocation)
    }
}

func callSystemCopy() {
    func keyEvents(forPressAndReleaseVirtualKey virtualKey: Int) -> [CGEvent] {
        let eventSource = CGEventSource(stateID: .privateState)
        eventSource?.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents, .permitLocalKeyboardEvents],
            state: .numberOfEventSuppressionStates
        )
        return [
            CGEvent(
                keyboardEventSource: eventSource, virtualKey: CGKeyCode(virtualKey), keyDown: true
            )!,
            CGEvent(
                keyboardEventSource: eventSource, virtualKey: CGKeyCode(virtualKey), keyDown: false
            )!,
        ]
    }

    let tapLocation = CGEventTapLocation.cgAnnotatedSessionEventTap
    let events = keyEvents(forPressAndReleaseVirtualKey: 8)

    events.forEach {
        $0.flags = .maskCommand
        $0.post(tap: tapLocation)
    }
}

func copyToClipboard(_ text: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
}

/// Async poll task, if task is true, call timeoutCallback.
func asyncPollTask(
    every interval: TimeInterval = 0.005,
    timeout: TimeInterval = 0.1,
    task: @escaping () -> Bool,
    timeoutCallback: @escaping () -> () = {}
) {
    var elapsedTime: TimeInterval = 0
    Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
        if task() {
            timer.invalidate()
        } else {
            elapsedTime += interval
            if elapsedTime >= timeout {
                timer.invalidate()
                timeoutCallback()
                logInfo("pollTask timeout call back")
            } else {
                logInfo("Still polling...")
            }
        }
    }
    // For non-main thread, run loop must be run.
    RunLoop.current.run()
}

func unlistenKeyEvent(_ eventTap: CFMachPort) {
    CGEvent.tapEnable(tap: eventTap, enable: false)
    CFRunLoopStop(CFRunLoopGetCurrent())
}

func listenAndInterceptKeyEvent(events: [CGEventType], handler: CGEventTapCallBack) -> CFMachPort? {
    let eventMask = events.reduce(into: 0) { partialResult, eventType in
        partialResult = partialResult | 1 << eventType.rawValue
    }

    // 创建一个事件监听器，并指定位置为 cghidEventTap
    let eventTap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: CGEventMask(eventMask),
        callback: handler,
        userInfo: nil
    )
    // 启用事件监听器
    if let eventTap {
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        CFRunLoopRun()
    }
    return eventTap
}

func measureTime(block: () -> ()) {
    let startTime = DispatchTime.now()
    block()
    let endTime = DispatchTime.now()

    let nanoseconds = endTime.uptimeNanoseconds - startTime.uptimeNanoseconds
    let milliseconds = Double(nanoseconds) / 1_000_000

    print("Execution time: \(milliseconds) milliseconds")
}