//
//  NFCReader.swift
//
//
//  Created by Naoya Maeda on 2024/01/20
//
//

import Foundation
import CoreNFC

final class NFCTagReader: NSObject, ObservableObject {
    private var session: NFCNDEFReaderSession?
    private var tagSession: NFCTagReaderSession?
    
    var writeMesage = "Core NFC Test"
    let readingAvailable: Bool
    
    @Published var sessionType = SessionType.read
    @Published var nfcype = NFCType.ndef
    @Published var readMessage: String?
    @Published var detectedTagCount = 0
    
    override init() {
        readingAvailable = NFCNDEFReaderSession.readingAvailable
    }
    
    func beginScanning() {
        guard readingAvailable else {
            print("This iPhone is not NFC-enabled.")
            return
        }
        switch nfcype {
        case .ndef:
            session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
            session?.alertMessage = "Please bring your iPhone close to the NFC tag."
            session?.begin()
            
        case .suica:
            tagSession = NFCTagReaderSession(pollingOption: .iso18092, delegate: self, queue: nil)
            tagSession?.alertMessage = "Please bring your iPhone close to the NFC tag."
            tagSession?.begin()
        }
    }
    
    private func read(tag: NFCNDEFTag, session: NFCNDEFReaderSession) {
        tag.readNDEF {[weak self] message, error in
            session.alertMessage = "The tag reading has been completed."
            session.invalidate()
            if let message {
                DispatchQueue.main.async {
                    self?.readMessage = self?.getStringFromNFCNDEF(message: message)
                }
            }
        }
    }
    
    private func getStringFromNFCNDEF(message: NFCNDEFMessage) -> String {
        message.records.compactMap {
            switch $0.typeNameFormat {
            case .nfcWellKnown:
                if let url = $0.wellKnownTypeURIPayload() {
                    return url.absoluteString
                }
                if let text = String(data: $0.payload, encoding: .utf8) {
                    return text
                }
                return nil
            default:
                return nil
            }
        }.joined(separator: "\n\n")
    }
    
}

extension NFCTagReader: NFCNDEFReaderSessionDelegate {
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        print("error:\(error.localizedDescription)")
    }

    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
        print("www")
    }
    
    /// readerSession(_:didDetect:)を実装すると呼び出されなくなる
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        guard messages.count > 0 else { return }
        self.readMessage = getStringFromNFCNDEF(message: messages.first!)
        session.alertMessage = "The tag reading has been completed."
        session.invalidate()
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        guard tags.count < 2 else { return }
        let tag = tags.first!
        session.connect(to: tag, completionHandler: { (error: Error?) in
            if nil != error {
                session.alertMessage = "Unable to connect to tag."
                session.invalidate()
                return
            }
            
            tag.queryNDEFStatus(completionHandler: { (ndefStatus: NFCNDEFStatus, capacity: Int, error: Error?) in
                guard error == nil else {
                    session.alertMessage = "Unable to query the NDEF status of tag."
                    session.invalidate()
                    return
                }
                
                switch ndefStatus {
                case .notSupported:
                    session.alertMessage = "Tag is not NDEF compliant."
                    session.invalidate()
                    
                case .readOnly:
                    self.read(tag: tag, session: session)
                    session.alertMessage = "Tag is read only."
                    session.invalidate()
                    
                case .readWrite:
                    if self.sessionType == .read {
                        self.read(tag: tag, session: session)
                    } else {
                        let data = self.writeMesage.data(using: .utf8)!
                        let payload = NFCNDEFPayload(format: .nfcWellKnown, type: Data("T".utf8), identifier: Data(), payload: data)
                        let message = NFCNDEFMessage(records: [payload])
                        tag.writeNDEF(message, completionHandler: { (error: Error?) in
                            if nil != error {
                                session.alertMessage = "Write NDEF message fail: \(error!)"
                            } else {
                                session.alertMessage = "Write NDEF message successful."
                            }
                            session.invalidate()
                        })
                    }
                @unknown default:
                    session.alertMessage = "Unknown NDEF tag status."
                    session.invalidate()
                }
            })
        })
    }
}

extension NFCTagReader: NFCTagReaderSessionDelegate {
    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        print()
    }
    
    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        print()
    }
    
    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        let tag = tags.first!
        
        session.connect(to: tag) { (error) in
            if nil != error {
                session.alertMessage = "Unable to connect to tag."
                session.invalidate()
                return
            }
            
            guard case .feliCa(let feliCaTag) = tag else {
                let retryInterval = DispatchTimeInterval.milliseconds(500)
                session.alertMessage = "A tag that is not FeliCa is detected, please try again with tag FeliCa."
                DispatchQueue.global().asyncAfter(deadline: .now() + retryInterval, execute: {
                    session.restartPolling()
                })
                return
            }

            let idm = feliCaTag.currentIDm.map { String(format: "%.2hhx", $0) }.joined()
            let systemCode = feliCaTag.currentSystemCode.map { String(format: "%.2hhx", $0) }.joined()
            DispatchQueue.main.async {
                self.readMessage = idm + "\n" + systemCode
            }
            session.alertMessage = "The tag reading has been completed."
            session.invalidate()
        }
    }
}
