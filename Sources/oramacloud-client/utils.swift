@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
class Debouncer {
    private var task: Task<Void, Never>?

    func debounce(interval: Duration = .nanoseconds(10000), operation: @escaping () -> Void) {
        task?.cancel()

        task = Task {
            do {
                try await Task.sleep(for: interval)
                operation()
            } catch {
                // @todo: handle error
                print("Error: \(error)")
            }
        }
    }
}
