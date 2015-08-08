//
//  RWScrollChart.swift
//  RWScrollChartDemo
//
//  Created by Zhang Bin on 2015-08-04.
//  Copyright (c) 2015年 Zhang Bin. All rights reserved.
//

import UIKit

class RWScrollChart: UIScrollView {
    // namespace
    typealias DataSource = RWSCDataSource
    typealias Appearance = RWSCAppearance
    typealias DataSetDrawable = RWSCDataSetDrawable
    typealias Axis = RWSCAxis
    
    typealias LineDataSet = RWSCLineDataSet
    typealias BarDataSet = RWSCBarDataSet
    
    typealias Layout = RWSCLayout
    
    // user provided information
    var dataSource = DataSource() {
        didSet {
            reloadData()
        }
    }
    
    var appearance: Appearance = Appearance() {
        didSet {
            _applyAppearance()
            reloadData()
        }
    }
    
    func reloadData() {
        _invalidateLayout()
    }
    
    var layout: Layout {
        if let layout = _layout {
            return layout
        }
        _layout = Layout(dataSource: dataSource, appearance: appearance, viewSize: bounds.size)
        return _layout!
    }
    
    func scrollToItemAtIndexPath(indexPath: NSIndexPath, animated: Bool) {
        setContentOffset(CGPoint(x: layout.scrollOffsetForItemAtIndexPath(indexPath, withViewSize: bounds.size), y: 0), animated: animated)
    }
    
    // internal
    private var _layout: Layout? {
        didSet {
            if let layout = _layout {
                contentSize = layout.contentSize
                contentInset = layout.contentInset
            } else {
                contentSize = CGSizeZero
                contentInset = UIEdgeInsetsZero
            }
        }
    }
    
    private func _invalidateLayout() {
        _layout = nil
        setNeedsDisplay()
        
        NSOperationQueue.mainQueue().addOperationWithBlock {
            var offset: CGFloat
            switch self.appearance.initialPosition {
            case .FirstItem: offset = 0.0
            case .LastItem: offset = self.layout.contentSize.width - self.bounds.width
            }
            self.setContentOffset(CGPoint(x: offset, y: 0), animated: false)
        }
    }
    
    private func _applyAppearance() {
        backgroundColor = appearance.backgroundColor
        showsHorizontalScrollIndicator = false
        setNeedsDisplay()
    }
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        delegate = self
        _applyAppearance()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        delegate = self
        _applyAppearance()
    }
    
}

extension RWScrollChart {
    
    override func drawRect(rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()
        
        if let axis = dataSource.axis where appearance.showAxis {
            _drawAxisLines(axis, inRect: rect, context: context)
        }
        
        _drawBackgroundLinesInRect(rect, context: context)
        let focus = layout.focusPositionWithViewBounds(bounds)
        var focusVisible = false
        
        var focusedItem: (indexPath: NSIndexPath, itemFrame: CGRect)? = nil
        
        if let visibleSections = layout.visibleSectionsInRect(rect) {
            for section in visibleSections {
                _drawSeparatorForSection(section, inRect: rect, context: context)
                _drawTitleForSection(section, inRect: rect, context: context)
            }
            
            if appearance.showFocus {
                focusedItem = layout.itemForFocusPosition(focus, visibleSections: visibleSections, viewBounds: bounds)
            }
        
            
            for dataSet in dataSource.dataSets {
                if let drawable = dataSet as? DataSetDrawable {
                    drawable.drawSections(visibleSections, inChart: self, withRect: rect, context: context)
                    if let focusedItem = focusedItem where dataSet.showFocus {
                        let drawn = drawable.drawFocusAtIndexPath(focusedItem.indexPath, withItemFrame: focusedItem.itemFrame, inChart: self, context: context)
                        focusVisible = focusVisible || drawn
                    }
                }
            }
            
        } // if let visibleSections
        
        if focusVisible {
            _drawFocus(focus, indexPath: focusedItem!.indexPath, inRect: rect, context: context)
        }
        
        if let axis = dataSource.axis where appearance.showAxis {
            _drawAxisText(axis, inRect: rect, context: context)
        }
    }
    
    private func _drawFocus(position: CGFloat, indexPath: NSIndexPath, inRect rect: CGRect, context: CGContextRef) {
        let needle = CGPoint(x: position, y: layout.chartAreaVerticalRangeForViewHeight(bounds.height).end + appearance.backgroundLineWidth)
        appearance.focusColor.setFill()
        CGContextBeginPath(context)
        CGContextMoveToPoint(context, needle.x, needle.y)
        CGContextAddLineToPoint(context, needle.x - appearance.focusNeedleLength, needle.y + appearance.focusNeedleLength)
        CGContextAddLineToPoint(context, needle.x + appearance.focusNeedleLength, needle.y + appearance.focusNeedleLength)
        CGContextAddLineToPoint(context, needle.x, needle.y)
        
        var progress: CGFloat = 0.0
        if contentSize.width > bounds.width {
            progress = bounds.minX / (contentSize.width - bounds.width)
        }
        
        let text = dataSource.textForItemAtIndexPath(indexPath) ?? " "
        let textAttr = [NSFontAttributeName: appearance.focusTextFont, NSForegroundColorAttributeName: appearance.focusTextColor]
        var textSize = (text as NSString).sizeWithAttributes(textAttr)
        textSize.width += appearance.focusTextMargin.x * 2.0
        textSize.height += appearance.focusTextMargin.y * 2.0
        
        let rounded: CGFloat = 2.0
        var rect = CGRect()
        rect.size = textSize
        rect.origin.y = needle.y + appearance.focusNeedleLength
        rect.origin.x = needle.x - (appearance.focusNeedleLength + rounded) - (textSize.width - 2.0 * (appearance.focusNeedleLength + rounded)) * progress
        
        _addRoundedRect(rect, withRadius: rounded, inContext: context)
        
        CGContextFillPath(context)
        
        rect.inset(dx: appearance.focusTextMargin.x, dy: appearance.focusTextMargin.y)
        (text as NSString).drawInRect(rect, withAttributes: textAttr)
    }
    
    private func _drawBackgroundLinesInRect(rect: CGRect, context: CGContextRef) {
        CGContextSetLineWidth(context, appearance.backgroundLineWidth)
        appearance.horizontalLineColor.setStroke()
        let chartVerticalRange = layout.chartAreaVerticalRangeForViewHeight(bounds.height)
        CGContextBeginPath(context)
        CGContextMoveToPoint(context, rect.minX, chartVerticalRange.end)
        CGContextAddLineToPoint(context, rect.maxX, chartVerticalRange.end)
        CGContextClosePath(context)
        CGContextStrokePath(context)
    }
    
    private func _drawSeparatorForSection(section: Int, inRect rect: CGRect, context: CGContextRef) {
        let sectionFrame = layout.sectionFrames[section]
        let (chartStartY, chartEndY) = layout.chartAreaVerticalRangeForViewHeight(bounds.height)
        CGContextBeginPath(context)
        CGContextMoveToPoint(context, sectionFrame.minX, sectionFrame.minY)
        CGContextAddLineToPoint(context, sectionFrame.minX, chartEndY)
        CGContextClosePath(context)
        CGContextSetStrokeColorWithColor(context, appearance.sectionSeparatorColor.CGColor)
        CGContextStrokePath(context)
    }
    
    private func _drawTitleForSection(section: Int, inRect rect: CGRect, context: CGContextRef) {
        let title = dataSource.titleForSection(section)
        if title == nil {
            return
        }
        let sectionFrame = layout.sectionFrames[section]
        
        var x = sectionFrame.minX + appearance.backgroundLineWidth + appearance.sectionTitleInsets.left
        let x0 = x
        x = max(x, rect.minX + appearance.sectionTitleInsets.left)
        let titleWidth = layout.sectionTitleWidths[section]
        x = min(x, sectionFrame.maxX - titleWidth - appearance.sectionTitleInsets.left)
        
        let titleRect = CGRect(x: x, y: sectionFrame.minY + appearance.sectionTitleInsets.top, width: sectionFrame.maxX - x, height: layout.sectionTitleAreaHeight)
        
        (title! as NSString).drawInRect(titleRect, withAttributes: [NSForegroundColorAttributeName: appearance.sectionTitleColor, NSFontAttributeName: appearance.sectionTitleFont])
    }
    
    private func _drawAxisLines(axis: Axis, inRect rect: CGRect, context: CGContextRef) {
        let chartArea = layout.chartAreaVerticalRangeForViewHeight(bounds.height)
        for (ratio, _) in axis.items {
            let y = chartArea.end - (chartArea.end - chartArea.start) * ratio
            
            appearance.axisLineColor.setStroke()
            CGContextBeginPath(context)
            CGContextMoveToPoint(context, rect.minX, y)
            CGContextAddLineToPoint(context, rect.maxX, y)
            CGContextStrokePath(context)
        }
    }
    
    private func _drawAxisText(axis: Axis, inRect rect: CGRect, context: CGContextRef) {
        let chartArea = layout.chartAreaVerticalRangeForViewHeight(bounds.height)
        let textAttr = [NSFontAttributeName: appearance.axisTextFont, NSForegroundColorAttributeName: appearance.axisTextColor]
        for (ratio, text) in axis.items {
            let y = chartArea.end - (chartArea.end - chartArea.start) * ratio
            
            var textSize = (text as NSString).sizeWithAttributes(textAttr)
            textSize.width += appearance.axisTextMargin.x * 2.0
            textSize.height += appearance.axisTextMargin.y * 2.0
            
            var textRect = CGRect(origin: CGPoint(x: rect.minX, y: y - textSize.height), size: textSize)
            appearance.axisBackgroundColor.setFill()
            CGContextFillRect(context, textRect)
            textRect.inset(dx: appearance.axisTextMargin.x, dy: appearance.axisTextMargin.y)
            (text as NSString).drawInRect(textRect, withAttributes: textAttr)
        }
    }
}

extension RWScrollChart: UIScrollViewDelegate {
    func scrollViewDidScroll(scrollView: UIScrollView) {
        setNeedsDisplay()
    }
}

private func _addRoundedRect(rect: CGRect, withRadius radius: CGFloat, inContext context: CGContextRef) {
    CGContextMoveToPoint(context, rect.minX + radius, rect.minY)
    CGContextAddArcToPoint(context, rect.maxX, rect.minY, rect.maxX,    radius + rect.minY, radius);
    CGContextAddArcToPoint(context, rect.maxX, rect.maxY, rect.maxX - radius,    rect.maxY, radius);
    CGContextAddArcToPoint(context, rect.minX, rect.maxY, rect.minX,   -radius + rect.maxY, radius);
    CGContextAddArcToPoint(context, rect.minX, rect.minY, rect.minX + radius,    rect.minY, radius);
}

// array binary search

enum ArrayBinarySearchCheckResult {
    case Match
    case ContinueLeft
    case ContinueRight
}

extension Array {
    func binarySearch(check: T -> ArrayBinarySearchCheckResult) -> (index: Int, matched: Bool) {
        var low = 0
        var high = self.count - 1
        while low <= high {
            let mid = (low + high) / 2
            switch check(self[mid]) {
            case .Match: return (mid, true)
            case .ContinueLeft: high = mid - 1
            case .ContinueRight: low = mid + 1
            }
        }
        return (low, false)
    }
    
    func insertionIndexOf(element: T, isAscending: (T, T) -> Bool) -> Int {
        let (index, matched) = binarySearch { midItem in
            if isAscending(element, midItem) {
                return .ContinueLeft
            } else if isAscending(midItem, element) {
                return .ContinueRight
            } else {
                return .Match
            }
        }
        return index
    }
}