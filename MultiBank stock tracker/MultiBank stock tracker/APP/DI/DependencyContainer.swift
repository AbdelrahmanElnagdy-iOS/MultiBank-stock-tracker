//
//  DependencyContainer.swift
//  MultiBank stock tracker
//
//  Created by Abdelrahman Elnagdy on 06/04/2026.
//

import Foundation

public final class DependencyContainer: Sendable {

    // MARK: - Shared

    public static let shared = DependencyContainer()

    // MARK: - Data Layer

    private let webSocketService: WebSocketService

    // MARK: - Init -

    public init(
        webSocketService: WebSocketService = WebSocketService()
    ) {
        let ws = webSocketService
        self.webSocketService = ws
    }
}
