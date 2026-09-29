import Darwin

/// Whether a debugger (LLDB / Xcode) is currently attached to this process.
///
/// This matters for the CGEvent taps. An ACTIVE session tap (`.defaultTap`)
/// makes the WindowServer block ALL system input until the tap callback returns.
/// Under the debugger the callback thread can be suspended at any moment — at a
/// breakpoint, on a caught signal, or the instant Accessibility is revoked (LLDB
/// stops the process) — and the WindowServer then waits forever for a callback
/// that never returns, hard-freezing the whole machine with no way to reach
/// Xcode's Stop button (hard reboot required). So while a debugger is attached we
/// create the taps `.listenOnly` instead: a listen-only tap is delivered copies
/// of events, can neither modify nor delay them, and never blocks the
/// WindowServer — a suspended callback thread can no longer freeze input. The
/// only cost is that event *swallowing* (return `nil`) is a no-op while debugging
/// (native ⌘Tab is still suppressed via the symbolic-hotkey API, and panel
/// navigation still works), which is an acceptable debug-only degradation.
enum DebuggerCheck {
    /// Apple Technical Q&A QA1361: a process is being traced when its
    /// `kinfo_proc` carries the `P_TRACED` flag. Cheap local `sysctl`, no IPC.
    /// Evaluated once — a debugger is attached at launch (Xcode Run) and the
    /// tap-install paths read it at install time.
    static let isAttached: Bool = {
        var info = kinfo_proc()
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        var size = MemoryLayout<kinfo_proc>.stride
        let result = sysctl(&mib, u_int(mib.count), &info, &size, nil, 0)
        guard result == 0 else { return false }
        return (info.kp_proc.p_flag & P_TRACED) != 0
    }()
}
