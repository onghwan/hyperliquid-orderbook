import Foundation

/// Owns the websocket connection to Hyperliquid: subscribing, keep-alive pings,
/// and automatic reconnection with exponential backoff. All callbacks fire on
/// the main actor.
@MainActor
final class HyperliquidSocket {
    struct Subscription: Equatable {
        var coin: String
        var nSigFigs: Int?
        /// Only meaningful with `nSigFigs == 5`; widens each bucket to 2× or
        /// 5× the finest tick.
        var mantissa: Int?
    }

    var onBook: (L2Book) -> Void = { _ in }
    var onBbo: (BboData) -> Void = { _ in }
    var onContext: (AssetContext) -> Void = { _ in }

    private let url = URL(string: "wss://api.hyperliquid.xyz/ws")!
    private let session = URLSession(configuration: .default)
    private let decoder = JSONDecoder()
    private var socket: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var pingTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var reconnectAttempt = 0
    private var subscription: Subscription?
    private var isActive = false

    func start(with subscription: Subscription) {
        guard !isActive else { return }
        self.subscription = subscription
        isActive = true
        open()
    }

    /// Switches coin/grouping on the live socket instead of tearing the
    /// connection down. The context stream only depends on the coin, so it is
    /// left alone when just the grouping changes.
    func update(subscription new: Subscription) {
        guard new != subscription else { return }
        let old = subscription
        subscription = new
        guard socket != nil else { return }
        if let old {
            send("unsubscribe", payload: l2BookPayload(old))
            if old.coin != new.coin {
                send("unsubscribe", payload: contextPayload(coin: old.coin))
                send("unsubscribe", payload: bboPayload(coin: old.coin))
            }
        }
        send("subscribe", payload: l2BookPayload(new))
        if old?.coin != new.coin {
            send("subscribe", payload: contextPayload(coin: new.coin))
            send("subscribe", payload: bboPayload(coin: new.coin))
        }
    }

    /// Tears the connection down while the app is in the background.
    func suspend() {
        guard isActive else { return }
        isActive = false
        closeSocket()
        reconnectTask?.cancel()
        reconnectTask = nil
    }

    func resume() {
        guard !isActive, subscription != nil else { return }
        isActive = true
        reconnectAttempt = 0
        open()
    }

    // MARK: - Connection lifecycle

    private func open() {
        closeSocket()
        let task = session.webSocketTask(with: url)
        socket = task
        task.resume()
        if let subscription {
            send("subscribe", payload: l2BookPayload(subscription))
            send("subscribe", payload: contextPayload(coin: subscription.coin))
            send("subscribe", payload: bboPayload(coin: subscription.coin))
        }
        startReceiving(on: task)
        startPinging()
    }

    private func closeSocket() {
        receiveTask?.cancel()
        receiveTask = nil
        pingTask?.cancel()
        pingTask = nil
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
    }

    private func scheduleReconnect() {
        guard isActive else { return }
        closeSocket()
        reconnectAttempt += 1
        let delay = min(0.5 * pow(2.0, Double(reconnectAttempt - 1)), 8.0)
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.open()
        }
    }

    // MARK: - Receiving

    private func startReceiving(on task: URLSessionWebSocketTask) {
        receiveTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    let message = try await task.receive()
                    self?.handle(message)
                } catch {
                    guard !Task.isCancelled else { return }
                    self?.scheduleReconnect()
                    return
                }
            }
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) {
        guard case let .string(text) = message,
              let data = text.data(using: .utf8),
              let peek = try? decoder.decode(ChannelPeek.self, from: data)
        else { return }

        // Any successful frame proves the connection is healthy again.
        reconnectAttempt = 0

        // Each case drops frames for a coin we've already switched away from.
        switch peek.channel {
        case "l2Book":
            guard let book = try? decoder.decode(L2BookMessage.self, from: data).data else { return }
            if book.coin == subscription?.coin {
                onBook(book)
            }
        case "bbo":
            guard let bbo = try? decoder.decode(BboMessage.self, from: data).data else { return }
            if bbo.coin == subscription?.coin {
                onBbo(bbo)
            }
        case "activeAssetCtx":
            guard let ctx = try? decoder.decode(AssetContextMessage.self, from: data).data else { return }
            if ctx.coin == subscription?.coin {
                onContext(ctx)
            }
        default:
            break
        }
    }

    // MARK: - Sending

    private func startPinging() {
        pingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(45))
                guard !Task.isCancelled else { return }
                self?.sendJSON(["method": "ping"])
            }
        }
    }

    private func l2BookPayload(_ sub: Subscription) -> [String: Any] {
        var payload: [String: Any] = ["type": "l2Book", "coin": sub.coin]
        if let nSigFigs = sub.nSigFigs {
            payload["nSigFigs"] = nSigFigs
        }
        if let mantissa = sub.mantissa {
            payload["mantissa"] = mantissa
        }
        return payload
    }

    private func contextPayload(coin: String) -> [String: Any] {
        ["type": "activeAssetCtx", "coin": coin]
    }

    private func bboPayload(coin: String) -> [String: Any] {
        ["type": "bbo", "coin": coin]
    }

    private func send(_ method: String, payload: [String: Any]) {
        sendJSON(["method": method, "subscription": payload])
    }

    private func sendJSON(_ object: [String: Any]) {
        guard let socket,
              let data = try? JSONSerialization.data(withJSONObject: object),
              let text = String(data: data, encoding: .utf8)
        else { return }
        // Send failures surface in the receive loop, which owns reconnection.
        socket.send(.string(text)) { _ in }
    }
}
