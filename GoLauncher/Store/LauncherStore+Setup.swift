import Foundation

/// "Set Up My GO Home Screen" progress and the start screen choice.
extension LauncherStore {
    enum StepStatus { case pending, done, skipped }

    func status(of step: SetupStep) -> StepStatus {
        if state.setup.completedSteps.contains(step.rawValue) { return .done }
        if state.setup.skippedSteps.contains(step.rawValue) { return .skipped }
        return .pending
    }

    func setStatus(_ status: StepStatus, for step: SetupStep) {
        var setup = state.setup
        setup.completedSteps.removeAll { $0 == step.rawValue }
        setup.skippedSteps.removeAll { $0 == step.rawValue }
        switch status {
        case .done: setup.completedSteps.append(step.rawValue)
        case .skipped: setup.skippedSteps.append(step.rawValue)
        case .pending: break
        }
        state.setup = setup
    }

    /// Required steps done (skipped ones don't count).
    var setupDoneCount: Int {
        SetupStep.required.filter { status(of: $0) == .done }.count
    }

    /// Where "Continue Setup" goes: the first required step not done or skipped, then the
    /// first skipped one. Nil when every required step is done.
    var nextSetupStep: SetupStep? {
        SetupStep.required.first { status(of: $0) == .pending }
            ?? SetupStep.required.first { status(of: $0) == .skipped }
    }

    /// The step after this one in the required list (for "Done › next").
    func step(after step: SetupStep) -> SetupStep? {
        guard let index = SetupStep.required.firstIndex(of: step) else { return nil }
        return SetupStep.required.dropFirst(index + 1).first { status(of: $0) != .done }
    }
}
