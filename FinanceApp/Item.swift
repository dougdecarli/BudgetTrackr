//
//  Item.swift
//  FinanceApp
//
//  Created by Douglas de Carli Immig on 01/06/26.
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
