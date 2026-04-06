//
//  WebSocketService.swift
//  MultiBank stock tracker
//
//  Created by Abdelrahman Elnagdy on 06/04/2026.
//

import Foundation
import Combine

public actor WebSocketService {

    // MARK: - Constants

    private static let endpoint = URL(string: "wss://ws.postman-echo.com/raw")!
    private static let pingInterval: TimeInterval = 20

    // MARK: - Subjects

    nonisolated let messageSubject = PassthroughSubject<String, Never>()
    nonisolated let stateSubject = CurrentValueSubject<ConnectionState, Never>(.disconnected)

    // MARK: - Public Publishers

    nonisolated public var messages: AnyPublisher<String, Never> {
        messageSubject.eraseToAnyPublisher()
    }

    nonisolated public var connectionState: AnyPublisher<ConnectionState, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    // MARK: - State (actor-isolated)

    private var webSocketTask: URLSessionWebSocketTask?
    private var pingTask: Task<Void, Never>?
    private var receiveTask: Task<Void, Never>?
    private var isRunning = false

    // MARK: - init

    public init(
        webSocketTask: URLSessionWebSocketTask? = nil,
        pingTask: Task<Void, Never>? = nil,
        receiveTask: Task<Void, Never>? = nil,
        isRunning: Bool = false
    ) {
        self.webSocketTask = webSocketTask
        self.pingTask = pingTask
        self.receiveTask = receiveTask
        self.isRunning = isRunning
    }

    // MARK: - Lifecycle

    public func connect() async {
        guard !isRunning else { return }
        isRunning = true
        stateSubject.send(.connecting)

        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: Self.endpoint)
        webSocketTask = task
        task.resume()

        stateSubject.send(.connected)
        startReceiving()
        startPinging()
    }

    public func disconnect() async {
        guard isRunning else { return }
        isRunning = false

        pingTask?.cancel()
        receiveTask?.cancel()
        pingTask = nil
        receiveTask = nil

        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil

        stateSubject.send(.disconnected)
    }

    // MARK: - Send

    public func send(_ message: String) async {
        guard let task = webSocketTask else { return }
        do {
            try await task.send(.string(message))
        } catch {
            handleError(error)
        }
    }

    // MARK: - Private

    private func startReceiving() {
        receiveTask = Task { [weak self] in
            guard let self else { return }
            while await self.isRunning {
                await self.receiveOnce()
            }
        }
    }

    private func receiveOnce() async {
        guard let task = webSocketTask else { return }
        do {
            let message = try await task.receive()
            switch message {
            case .string(let text):
                messageSubject.send(text)
            case .data(let data):
                if let text = String(data: data, encoding: .utf8) {
                    messageSubject.send(text)
                }
            @unknown default:
                break
            }
        } catch {
            if isRunning { handleError(error) }
        }
    }

    private func startPinging() {
        pingTask = Task { [weak self] in
            guard let self else { return }
            while await self.isRunning {
                try? await Task.sleep(nanoseconds: UInt64(Self.pingInterval * 1_000_000_000))
                await self.sendPing()
            }
        }
    }

    private func sendPing() async {
        webSocketTask?.sendPing { [weak self] error in
            if let error {
                Task { await self?.handleError(error) }
            }
        }
    }

    private func handleError(_ error: Error) {
        guard isRunning else { return }
        isRunning = false
        pingTask?.cancel()
        receiveTask?.cancel()
        webSocketTask = nil
        stateSubject.send(.failed(error.localizedDescription))
    }
}
