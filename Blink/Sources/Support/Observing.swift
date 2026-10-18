import Observation

/// Runs `apply` now and again whenever observable state it read changes.
@MainActor
func observeContinuously(_ apply: @escaping @MainActor () -> Void) {
    withObservationTracking(apply) {
        Task { @MainActor in observeContinuously(apply) }
    }
}
