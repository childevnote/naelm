//
//  AppleTokenServerClient.swift
//  Naelm
//
//  Server client for Sign in with Apple token exchange/revocation.
//

import Foundation
import os

enum AppleTokenServerClient {

    // Update this to your deployed Worker base URL, e.g. https://naelm-apple-token-revoke.workers.dev
    static let baseURL = URL(string: "https://REPLACE_WITH_DEPLOYED_WORKER_URL")!

    static func storeAuthorizationCode(_ authorizationCode: String, userID: String) async {
        let payload = [
            "userID": userID,
            "authorizationCode": authorizationCode
        ]
        await send(path: "/apple/store-token", payload: payload)
    }

    static func revoke(userID: String, authorizationCode: String?) async {
        var payload: [String: String] = ["userID": userID]
        if let authorizationCode {
            payload["authorizationCode"] = authorizationCode
        }
        await send(path: "/apple/revoke", payload: payload)
    }

    private static func send(path: String, payload: [String: String]) async {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload, options: [])

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                AppLogger.auth.warning("Apple token server returned status: \(http.statusCode)")
            }
        } catch {
            AppLogger.auth.warning("Apple token server request failed: \(error.localizedDescription)")
        }
    }
}
