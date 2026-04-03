//
//  Item.swift
//  Toeigo
//
//  Created by 김동진 on 4/3/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
