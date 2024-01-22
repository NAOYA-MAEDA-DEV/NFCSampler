//
//  Utility.swift
//  
//  
//  Created by Naoya Maeda on 2024/01/20
//  
//

import Foundation

enum SessionType: String, CaseIterable, Identifiable  {
    case read
    case write
    var id: String { rawValue }
}
enum NFCType: String, CaseIterable, Identifiable  {
    case ndef
    case suica
    var id: String { rawValue }
}
