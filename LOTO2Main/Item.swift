//
//  Item.swift
//  LOTO2Main
//
//  Created by Jay.Dev on 4/13/26.
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
