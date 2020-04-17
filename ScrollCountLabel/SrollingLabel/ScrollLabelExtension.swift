//
//  ScrollLabelExtension.swift
//  Demo
//
//  Created by zolobdz on 2020/4/1.
//  Copyright © 2020 zolobdz. All rights reserved.
//

import Foundation


extension NSNumber {
    var dot2Value: String {
        return String(format: "%.2f", self.doubleValue)
    }
    var commaValue: String {
        let format = NumberFormatter()
        format.minimumFractionDigits = 2
        format.maximumFractionDigits = 2
        format.numberStyle = .decimal
        format.groupingSize = 3
        return format.string(from: self) ?? "0.00"
    }
}

extension String {
    var numberValue: NSNumber? {
        guard let f = Double(self) else {
            return nil
        }
        return NSNumber(value: f)
    }
    var isPureNumber: Bool {
        let scan = Scanner(string: self)
        return scan.scanInt() != nil && scan.isAtEnd
    }
}
