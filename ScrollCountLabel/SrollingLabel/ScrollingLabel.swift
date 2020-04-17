//
//  ScrollingLabel.swift
//  Demo
//
//  Created by zolobdz on 2020/4/1.
//  Copyright © 2020 zolobdz. All rights reserved.
//

import UIKit

fileprivate let kStopAnimationDelay = 0.5 // 为了实现zuo'zong从左到右依次停下，而不是一起停下，每一位要增加x秒后停下(累加)
let kCommaTag = 10086
let kDotTag = 10088
let kSymbolTag = 10088
let kNumberCellLineCount = 11;
let kNumberCellText = "0\n1\n2\n3\n4\n5\n6\n7\n8\n9\n0"
let kMinSpeed = 0.0000012 // 之前是0.000001 但是3148765431.11->0.00的动画1.11就不动了，应该和刷帧频率有关系

enum ScrollingDirection {
    case increase
    case decrease
}
struct AnimationInfo {
    var delay = 0.0
    var toZeroTime = 0.0
    var cycleTime = 0.0
    var cycleCount = 0
    var endTime = 0.0
    var targetNumber = 0
    var direction = ScrollingDirection.increase
    var speed = 0.0
    var repeatCount = 0
    var shouldHideWhenFinish = false
}

class ScrollingLabel: UIView {
    
    private var oldNumber: NSNumber!
    private var newNumber = NSNumber(value: 0.0)
    var symbolText = "$"
    
    var font = UIFont.systemFont(ofSize: 16) {
        didSet {
            let size = NSString(string: kNumberCellText).boundingRect(with: CGSize(width: 100.0, height: Double(MAXFLOAT)), options: .usesLineFragmentOrigin, attributes: [NSAttributedString.Key.font : self.font], context: nil).size
            unitSize = size
        }
    }
    var textColor = UIColor.white
    lazy var unitSize: CGSize = {
        let size = NSString(string: kNumberCellText).boundingRect(with: CGSize(width: 100.0, height: Double(MAXFLOAT)), options: .usesLineFragmentOrigin, attributes: [NSAttributedString.Key.font : self.font], context: nil).size
        return size
    }()
    
    lazy var symbolSize: CGSize = {
        let size = NSString(string: "9").boundingRect(with: CGSize(width: 100.0, height: Double(MAXFLOAT)), options: .usesLineFragmentOrigin, attributes: [NSAttributedString.Key.font : self.font], context: nil).size
        return size
    }()
    
    lazy var symbolLabel: UILabel = {
        let label = createLabel()
        label.changeText(symbolText)
        label.frame.size = symbolSize
        label.isHidden = false
        return label
    }()
    
    private var unitArray = [UILabel]()
    private var cacheLabelArray = [UILabel]()
    private var animtionDate = Date()
    private var isCancelAnimation = false
    // MARK: - Public
    
    func config(_ text: String, interval: TimeInterval, animate: Bool) {
        
        // cancel previous
        isCancelAnimation = true
        for cell in unitArray {
            cell.layer.removeAllAnimations()
        }
        
        // preparing
        guard let targetNumber = text.numberValue else {
            return
        }
        if oldNumber == nil {
            makeUpLabels(number: targetNumber)
            show(targetNumber: targetNumber, needRemoveExcess: false)
            oldNumber = targetNumber
            return
        }
        if targetNumber.dot2Value == oldNumber.dot2Value {
            return
        }
        animtionDate = Date()
        // processing
        let temporaryNumber = targetNumber.floatValue > oldNumber.floatValue ? targetNumber : oldNumber!
        makeUpLabels(number: temporaryNumber)
        if !animate || interval == 0.0 {
            show(targetNumber: targetNumber, needRemoveExcess: true)
            oldNumber = targetNumber
            return
        }
        show(targetNumber: oldNumber, needRemoveExcess: false) // 因为新makeup的cell的value都是0，不一定符合上一次的数字会导致动画错乱。
        let changeValue = NSNumber(value: targetNumber.doubleValue - oldNumber.doubleValue)
        let repeatCountArray = getRepeatCount(changeValue: changeValue)
        playAnimation(targetNumber: targetNumber, repeatCountArray: repeatCountArray, interval: interval)
        oldNumber = targetNumber
    }
    
    // MARK: - Private
    
    private func cleanTable() {
        cacheLabelArray.append(contentsOf: unitArray)
        unitArray.removeAll()
    }
    
    
    /// 直接展示数字
    /// - Parameters:
    ///   - targetNumber: 要展示的数字
    ///   - needRemoveExcess: 是否需要移除unitArray中多余的cell；e.g：array有6个cell，但是只要展示4个，剩下的根据该值移除或者仅仅隐藏
    func show(targetNumber: NSNumber, needRemoveExcess: Bool) {
        var targetNumberString = targetNumber.commaValue// "\(Int(targetNumber.doubleValue*100.0))"
        if targetNumberString == "0" {
            targetNumberString = "0.00"
        }
        for (idx, cell) in unitArray.enumerated() {
            if idx >= targetNumberString.count {
                cell.isHidden = true
                if needRemoveExcess {
                    cell.removeFromSuperview()
                    unitArray.removeAll { (label) -> Bool in
                        let equal = label == cell
                        if equal {
                            cacheLabelArray.append(label)
                        }
                        return equal
                    }
                }
                continue
            }
            let charac = targetNumberString.reversed()[idx]
            cell.isHidden = false
            guard let value = Int(String(charac)) else {
                cell.changeText(String(charac))
                cell.frame.origin.y = 0
                cell.frame.size.height = symbolSize.height
                continue
            }
            moveCellNumber(cell: cell, toNumber: value)
        }
        updateSymbolFrame()
    }
    
    func playAnimation(targetNumber: NSNumber, repeatCountArray: [Int], interval: TimeInterval) {
        isCancelAnimation = false
        if repeatCountArray.count == 0 {
            return
        }
        let oldNumberDouble = (oldNumber ?? NSNumber(0)).doubleValue
        var targetNumberString = targetNumber.commaValue
        if targetNumberString == "0" {
            targetNumberString = "0.00"
        }
        
        // 计算每个翻转动画时间
        let allCount = repeatCountArray.first!
        if allCount == 0 {
            return
        }

        // 方向
        let direction: ScrollingDirection = targetNumber.doubleValue > oldNumberDouble ? .increase : .decrease
        // 每个列数字动画的开始时间（从右往左依次递增）
        var skipOffset = 0
        var beginTime = 0.0
        var isFloatNumber = true
        var stopDelay = 0.0
        
        for (idx,var repeatCount) in repeatCountArray.enumerated() {
            if repeatCount == 0 {
                return
            }
            // 确认速度
            var shouldHideWhenFinish = false
            var speed = (interval-beginTime-stopDelay) / Double(repeatCount)
            if interval == beginTime {
                speed = 0.3
            }
            var charac = "0"
            if targetNumberString.count > idx+skipOffset {
                charac = targetNumberString.reversed().map({ (obj) -> String in
                    return String(obj)
                })[idx+skipOffset]
            } else {
                shouldHideWhenFinish = true
            }
            var cell = unitArray[idx+skipOffset]
            cell.isHidden = false
            var value: Int! = Int(charac)
            if value == nil || cell.tag > 10000 {
                if String(charac) == "." {
                    isFloatNumber = false
                }
                print("not num:\(String(charac))")
                if cell.tag == kDotTag {
                    cell.changeText(".")
                } else if cell.tag == kCommaTag {
                    cell.changeText(",")
                } else {
                    cell.changeText(String(charac))
                }
                cell.frame.origin.y = 0
                cell.frame.size.height = symbolSize.height
                skipOffset += 1
                
                charac = "0"
                if targetNumberString.count > idx+skipOffset {
                    charac = targetNumberString.reversed().map({ (obj) -> String in
                        return String(obj)
                    })[idx+skipOffset]
                } else {
                    shouldHideWhenFinish = true
                }
                cell = unitArray[idx+skipOffset]
                cell.isHidden = false
                value = Int(String(charac))
            }
            
            var toZeroTime = 0.0
            var cycleTime = 0.0
            var endTime = 0.0
            var cycleCount = 0
            
            /// speed处理
            // 速度过慢，导致动画无法执行
            if speed < kMinSpeed {
                let totalTime = Double(repeatCount) * speed
                speed = kMinSpeed
                repeatCount = Int(totalTime / kMinSpeed)
            }
            //0.0151<speed<0.0188 这个范围内动画有点难看，可以考虑转成0.0188(e.g:0~500.99)
            
            print("target:\(charac)-begin:\(beginTime),left:\(interval-beginTime)")
            print("speed:\(speed);repeat:\(repeatCount);stopDelay\(stopDelay)")
            // 速度过快，导致动画太慢
            if speed > 2 {
                speed = 2
            }
            
            /// 动画计算
            // 预热动画 x->0
            let currentValue = getCellCurrentValue(cell: cell)
            if repeatCount >= 10 {
                switch direction {
                case .increase:
                    toZeroTime = Double(10 - currentValue) * speed
                    repeatCount -= (10 - currentValue)
                case .decrease:
                    let count = (currentValue == 0) ? 10 : currentValue
                    toZeroTime = Double(count) * speed
                    repeatCount -= count
                }
                stopDelay += kStopAnimationDelay
            }
            // 循环动画 0->0
            if repeatCount >= 10 {
                cycleCount = repeatCount / 10
                cycleTime = speed * 10.0 // 一圈的时间
                repeatCount = repeatCount % 10
            }
            // 完结动画 0->tragetNumber
            if repeatCount > 0 {
                endTime = Double(repeatCount) * speed
            }
            
            let animte = AnimationInfo(
                delay: beginTime,
                toZeroTime: toZeroTime,
                cycleTime: cycleTime,
                cycleCount: cycleCount,
                endTime: endTime,
                targetNumber: value,
                direction: direction,
                speed: speed,
                repeatCount: repeatCount,
                shouldHideWhenFinish: shouldHideWhenFinish
            )
            beginTime += toZeroTime
            let isLast = ((idx + 1) == repeatCountArray.count)
            cellRollAnimation(cell: cell, animte: animte,isFloat: isFloatNumber, isLast: isLast)

        }
    }
        
    func cellRollAnimation(cell: UILabel, animte: AnimationInfo,isFloat: Bool = false, isLast: Bool = false) {
        var finalDelay = 0.0
        // 注意：如果block中的代码对cell的ui上没有任何改变(frame,alpha等)的话,动画就不会执行，而且直接跳过原定的duration和delay,所以如果block中不改变ui，那么要在block外面要
        UIView.animate(withDuration: animte.toZeroTime, delay: animte.delay, options: UIView.AnimationOptions.curveEaseIn, animations: {
            // 取消动画就不需要执行变换(必须) && 动画时间为0，就不需要执行下面的数字变换
            if !self.isCancelAnimation && animte.toZeroTime > 0{
                self.moveCellNumber(cell: cell, toNumber: animte.direction == .increase ? 10 : 0)
            }
        }) { (_) in
            if !self.isCancelAnimation {
                let onlyRollZero = animte.cycleTime > 0.0 && animte.toZeroTime == 0.0
                if animte.toZeroTime > 0.0 || onlyRollZero{
                    self.moveCellNumber(cell: cell, toNumber: animte.direction == .increase ? 0 : 10)
                }
            }
            let option: UIView.AnimationOptions = [UIView.AnimationOptions.curveLinear,UIView.AnimationOptions.repeat]
            UIView.animate(withDuration: animte.cycleTime, delay: 0, options: option, animations: {
                UIView.setAnimationRepeatCount(Float(animte.cycleCount))
                if !self.isCancelAnimation && animte.cycleTime > 0.0 {
                    self.moveCellNumber(cell: cell, toNumber: animte.direction == .increase ? 10 : 0)
                }
            }) { (repeatFinish) in
                if !self.isCancelAnimation && animte.cycleTime > 0.0{
                    self.moveCellNumber(cell: cell, toNumber: animte.direction == .increase ? 0 : 10)
                }
                if animte.toZeroTime == 0.0 {
                    finalDelay = animte.delay
                }
                UIView.animate(withDuration: animte.endTime, delay: finalDelay, options: UIView.AnimationOptions.curveEaseOut, animations: {
                    if !self.isCancelAnimation {
                        self.moveCellNumber(cell: cell, toNumber: animte.targetNumber)
                    }
                }) { (finish) in
                    if !self.isCancelAnimation && animte.shouldHideWhenFinish {
                        // 先隐藏变为0的最到位数字
                        cell.isHidden = true
                        // 隐藏移除‘,’
                        for (idx,label) in self.unitArray.enumerated() {
                            if idx < 7 {
                                continue
                            }
                            if label == cell && idx >= 7 && self.unitArray[idx - 1].tag == kCommaTag{// 第7未开始的下一位(第六位)才可能是逗号‘,’
                                self.unitArray[idx - 1].isHidden = true
                                self.removeCellFromUnitArray(self.unitArray[idx - 1])
                                break
                            }
                        }
                        // 后隐藏移除变为0的最到位数字(防止for内位数错乱)
                        self.removeCellFromUnitArray(cell)
                        // 更新符号位置
                        self.updateSymbolFrame()
                    }
                    if isLast {
                        let duration = Date().timeIntervalSince(self.animtionDate)
                        print("动画时间：\(duration)")
                    }
                }
            }
        }
    }
    
    private func removeCellFromUnitArray(_ cell: UILabel) {
        for (idx, label) in unitArray.enumerated() {
            if cell == label{
                cacheLabelArray.append(cell)
                unitArray.remove(at: idx)
                break
            }
        }
    }
    
    func getRepeatCount(changeValue: NSNumber) -> [Int]{
        var changeRepeat = Int(abs(changeValue.doubleValue)*100)
        var repeatArray = [changeRepeat]
        repeat {
            changeRepeat = changeRepeat / 10
            repeatArray.append(changeRepeat)
        } while (changeRepeat / 10 > 0)
        print(repeatArray)
        return repeatArray
    }
    
    private func makeUpLabels(number: NSNumber) {
        
        cleanTable()
        
        var width = self.frame.size.width
        if width == 0.0 {
            width = CGFloat(number.commaValue.count) * unitSize.width
        }
        for subView in subviews {
            subView.removeFromSuperview()
        }
        for (idx,obj) in number.commaValue.reversed().enumerated() {
            if unitArray.count > idx {
                continue
            }
            let cell = createLabel()
            let x = width - CGFloat(idx+1) * unitSize.width
            if obj.isNumber {
                cell.frame = CGRect(x: x, y: 0, width: unitSize.width, height: unitSize.height)
                cell.tag = 0
            } else {
                cell.changeText(String(obj))
                cell.frame = CGRect(x: x, y: 0, width: unitSize.width, height: unitSize.height)
            }
            addSubview(cell)
            unitArray.append(cell)
        }
        print("###unitArray count:¥\(unitArray.count)")
        updateSymbolFrame()
        addSubview(symbolLabel)
    }
    
    func createLabel() -> UILabel{
        var label: UILabel!
        if !cacheLabelArray.isEmpty {
            label = cacheLabelArray.first
            cacheLabelArray.removeFirst()
        } else {
            label = UILabel()
        }
        label.font = font
        label.numberOfLines = kNumberCellLineCount
        label.changeText(kNumberCellText)
        label.textColor = textColor
        label.isHidden = true
        label.clipsToBounds = true
        return label
    }
    
    func moveCellNumber(cell: UILabel, toNumber: Int) {
        let signle = unitSize.height / CGFloat(kNumberCellLineCount)
        let y = -(signle*CGFloat(toNumber));
////        let total = unitSize.height / CGFloat(kNumberCellLineCount) * 10.0
//        let y = -(total - CGFloat(toNumber) / CGFloat(kNumberCellLineCount) * unitSize.height)
        cell.frame.origin.y = y
    }
    
    func getCellCurrentValue(cell: UILabel) -> Int{
        var y = cell.frame.origin.y
        if y < 0 {
            y = -y+1
        }
        let signle = unitSize.height / CGFloat(kNumberCellLineCount)
        let num = Int(y/signle)
        return num
    }
    
    func updateSymbolFrame() {
        var symbolX = 0.0
        if let first = unitArray.last {
            symbolX = Double(first.frame.origin.x - symbolSize.width)
        }
        symbolLabel.frame.origin = CGPoint(x: symbolX, y: 0.0)
    }
}


extension UILabel {
    fileprivate func changeText(_ string: String?) {
        text = string
        if let str = string {
            if str == ","{
                tag = kCommaTag
            } else if str == "."{
                tag = kDotTag
            } else if str == "$" {
                tag = kSymbolTag
            } else {
                tag = 0
            }
        }
    }
}
