//
//  ConnectionState.swift
//  MultiBank stock tracker
//
//  Created by Abdelrahman Elnagdy on 06/04/2026.
//

import Foundation

public enum ConnectionState: Equatable, Sendable {
    case disconnected
    case connecting
    case connected
    case failed(String)

    public var isConnected: Bool {
        self == .connected
    }

    public var displayTitle: String {
        switch self {
        case .disconnected:  return "Disconnected"
        case .connecting:    return "Connecting…"
        case .connected:     return "Live"
        case .failed(let e): return "Error: \(e)"
        }
    }
}
