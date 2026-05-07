import Foundation

// ============================================================
// SSE CLIENT
// Server-Sent Events — для стриминга прогресса генерации.
// URLSession.bytes(for:) даёт нам AsyncSequence<UInt8>, мы
// парсим формат SSE построчно.
//
// Формат:
//   event: step
//   data: {"current":2,"total":5,"message":"..."}
//
//   event: done
//   data: {"surveyId":"...","routeIds":["..."]}
// ============================================================

@MainActor
final class SSEClient {

    /// События которые получаем по SSE
    enum Event {
        case step(SSEStepPayload)
        case done(SSEDonePayload)
        case error(String)
    }

    private var task: Task<Void, Never>?
    private let decoder = JSONDecoder()

    /// Подключиться к SSE endpoint и получать события.
    /// Возвращает AsyncStream — каждый event приходит как Event.
    func stream(_ endpoint: Endpoint) -> AsyncStream<Event> {
        return AsyncStream { continuation in
            let task = Task {
                await self.run(endpoint, continuation: continuation)
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func run(
        _ endpoint: Endpoint,
        continuation: AsyncStream<Event>.Continuation
    ) async {
        guard
            let urlString = Bundle.main.object(forInfoDictionaryKey: "TRAVELLO_API_URL") as? String,
            let baseURL = URL(string: urlString)
        else {
            // Fallback для локальной разработки
            await connect(
                url: URL(string: "http://localhost:8080")!.appendingPathComponent(endpoint.path),
                continuation: continuation
            )
            return
        }

        let url = baseURL.appendingPathComponent(endpoint.path)
        await connect(url: url, continuation: continuation)
    }

    private func connect(
        url: URL,
        continuation: AsyncStream<Event>.Continuation
    ) async {
        var request = URLRequest(url: url)
        request.setValue("text/event-stream",       forHTTPHeaderField: "Accept")
        request.setValue("no-cache",                forHTTPHeaderField: "Cache-Control")

        if let token = KeychainService.read(.authToken) {
            request.setValue("Bearer \(token)",     forHTTPHeaderField: "Authorization")
        }

        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)

            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                continuation.yield(.error("HTTP \(code)"))
                continuation.finish()
                return
            }

            // Парсим построчно
            var currentEvent: String?
            var currentData = ""

            for try await line in bytes.lines {
                if Task.isCancelled { break }

                if line.isEmpty {
                    // Пустая строка = конец события
                    if let event = currentEvent {
                        emit(event: event, data: currentData, continuation: continuation)
                    }
                    currentEvent = nil
                    currentData = ""
                    continue
                }

                if line.hasPrefix(":") {
                    // Comment или keep-alive — пропускаем
                    continue
                }

                if line.hasPrefix("event:") {
                    currentEvent = line
                        .dropFirst("event:".count)
                        .trimmingCharacters(in: .whitespaces)
                } else if line.hasPrefix("data:") {
                    let dataPart = line
                        .dropFirst("data:".count)
                        .trimmingCharacters(in: .whitespaces)
                    if currentData.isEmpty {
                        currentData = dataPart
                    } else {
                        currentData += "\n" + dataPart
                    }
                }
                // id: и retry: игнорируем для MVP
            }

            continuation.finish()
        } catch {
            if !Task.isCancelled {
                continuation.yield(.error(error.localizedDescription))
            }
            continuation.finish()
        }
    }

    private func emit(
        event: String,
        data: String,
        continuation: AsyncStream<Event>.Continuation
    ) {
        guard let bytes = data.data(using: .utf8) else { return }

        switch event {
        case "step":
            if let payload = try? decoder.decode(SSEStepPayload.self, from: bytes) {
                continuation.yield(.step(payload))
            }
        case "done":
            if let payload = try? decoder.decode(SSEDonePayload.self, from: bytes) {
                continuation.yield(.done(payload))
                continuation.finish()
            }
        case "error":
            let msg = (try? decoder.decode(SSEErrorPayload.self, from: bytes))?.reason
                      ?? "Ошибка генерации"
            continuation.yield(.error(msg))
            continuation.finish()
        default:
            break
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}

// ============================================================
// PAYLOADS
// Зеркалят SSE payloads из Kotlin backend'а.
// ============================================================

struct SSEStepPayload: Decodable {
    let current: Int
    let total: Int
    let message: String
}

struct SSEDonePayload: Decodable {
    let surveyId: UUID
    let routeIds: [UUID]
    let generationNotes: String?
}

struct SSEErrorPayload: Decodable {
    let reason: String
}
