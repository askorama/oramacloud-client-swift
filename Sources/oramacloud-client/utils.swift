import Foundation

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

class EventEmitter {
    typealias EventCallback = (Any) -> Void

    private var eventCallbacks: [String: [EventCallback]] = [:]

    func on(_ eventName: String, callback: @escaping EventCallback) {
        if eventCallbacks[eventName] == nil {
            eventCallbacks[eventName] = []
        }
        eventCallbacks[eventName]?.append(callback)
        fflush(stdout)
    }

    func emit(_ eventName: String, data: Any) {
        fflush(stdout)
        eventCallbacks[eventName]?.forEach { callback in
            callback(data)
        }
    }
}
