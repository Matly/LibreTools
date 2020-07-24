//
//  LibreToolsViewModel.swift
//  LibreTools
//
//  Created by Ivan Valkou on 16.07.2020.
//  Copyright © 2020 Ivan Valkou. All rights reserved.
//

import SwiftUI
import Combine

final class LibreToolsViewModel: ObservableObject {
    private let nfcManager: NFCManager

    private enum Config {
        static let unlockCodeKey = "LibreTools.unlockCode"
        static let passwordKey = "LibreTools.password"
    }
    
    @Published var log = "Ready to scan"
    @Published var region: SensorRegion?
    @Published var unlockCode = ""
    @Published var password = ""

    let canEditUnlockCredentials: Bool

    private var inputSubscription: AnyCancellable?

    init(unlockCode: Int? = nil, password: Data? = nil) {
        nfcManager = BaseNFCManager(unlockCode: unlockCode, password: password)
        canEditUnlockCredentials = unlockCode == nil || password == nil
        self.unlockCode = unlockCode.map { String(format: "%02X", $0) }
            ?? UserDefaults.standard.string(forKey: Config.unlockCodeKey) ?? ""
        self.password = password.map { $0.hexEncodedString() }
            ?? UserDefaults.standard.string(forKey: Config.passwordKey) ?? ""
    }

    func read() {
        inputSubscription = nfcManager.perform(.readState)
            .receive(on: DispatchQueue.main)
            .assign(to: \.log, on: self)
    }

    func reset() {
        inputSubscription = nfcManager.perform(.reset)
            .receive(on: DispatchQueue.main)
            .assign(to: \.log, on: self)
    }

    func activate() {
        inputSubscription = nfcManager.perform(.activate)
            .receive(on: DispatchQueue.main)
            .assign(to: \.log, on: self)
    }

    func dump() {
        inputSubscription = nfcManager.perform(.readFRAM)
            .receive(on: DispatchQueue.main)
            .assign(to: \.log, on: self)
    }

    func changeRegion(to region: SensorRegion) {
        inputSubscription = nfcManager.perform(.changeRegion(region))
            .receive(on: DispatchQueue.main)
            .assign(to: \.log, on: self)
    }

    func saveUnlockCredentials() {
        guard let psw = password.hexadecimal, let code = unlockCode.hexadecimal else {
            password = ""
            unlockCode = ""
            return
        }
        UserDefaults.standard.set(unlockCode, forKey: Config.unlockCodeKey)
        UserDefaults.standard.set(password, forKey: Config.passwordKey)

        nfcManager.setCredentials(unlockCode: Int([UInt8](code)[0]), password: psw)
    }
}

private extension String {
    var hexadecimal: Data? {
        var data = Data()

        let regex = try! NSRegularExpression(pattern: "[0-9a-f]{1,2}", options: .caseInsensitive)
        regex.enumerateMatches(in: self, range: NSRange(startIndex..., in: self)) { match, _, _ in
            let byteString = (self as NSString).substring(with: match!.range)
            let num = UInt8(byteString, radix: 16)!
            data.append(num)
        }

        guard data.count > 0 else { return nil }

        return data
    }
}

extension Data {
    var hexadecimal: String {
        map { String(format: "%02x", $0) }.joined()
    }
}