//
//  RWSCLayout.swift
//  RWScrollChartDemo
//
//  Created by Zhang Bin on 2015-08-04.
//  Copyright (c) 2015年 Zhang Bin. All rights reserved.
//

import UIKit

struct RWSCLayout {
    let appearance: RWSCAppearance
    let dataSource: RWSCDataSource
    
    let sectionFrames: [CGRect]
    let sectionTitleWidths: [CGFloat]
    
    let contentLeftMargin: CGFloat
    let contentRightMargin: CGFloat
    let contentSize: CGSize
    let contentInset: UIEdgeInsets
    
    let focusTextAreaHeight: CGFloat
    let sectionTitleAreaHeight: CGFloat
    let titleAreaHeight: CGFloat // section title, padding for upmost axis
    
    var rightScrollBound: CGFloat? = nil
    
    func chartAreaVerticalRangeForViewHeight(height: CGFloat) -> (start: CGFloat, end: CGFloat) {
        let start = appearance.contentMargins.top + titleAreaHeight + appearance.backgroundLineWidth
        let end = height - focusTextAreaHeight - appearance.backgroundLineWidth - appearance.contentMargins.bottom
        return (start, end)
    }
    
    private func _axisWidthForViewWidth(viewWidth: CGFloat) -> CGFloat {
        if !appearance.showAxis || dataSource.axis == nil {
            return 0.0
        }
        return appearance.axisAreaWidthForViewWith(viewWidth)
    }
    
    func itemForFocusPosition(focus: CGFloat, visibleSections: Range<Int>, viewBounds: CGRect) -> (indexPath: NSIndexPath, itemFrame: CGRect)? {
        for section in visibleSections {
            for item in 0..<dataSource.numberOfItemsInSection(section) {
                let indexPath = NSIndexPath(forItem: item, inSection: section)
                let itemFrame = frameForItemAtIndexPath(indexPath, withViewHeight: viewBounds.height)
                
                if focus >= itemFrame.minX - appearance.itemPadding / 2.0
                    && focus <= itemFrame.maxX + appearance.itemPadding / 2.0 {
                        return (indexPath, itemFrame)
                }
                
                if focus < itemFrame.minX && section == 0 && item == 0 {
                    // first item
                    return (indexPath, itemFrame)
                }
                
                if focus > itemFrame.maxX && section + 1 == dataSource.numberOfSections() && item + 1 == dataSource.numberOfItemsInSection(section) {
                    // last item
                    return (indexPath, itemFrame)
                }
                
            } // for item
        } // for section
        return nil
    }
    
    private func _focusParamsWithViewBounds(bounds: CGRect) -> (position: CGFloat, c1: CGFloat, c2: CGFloat, c3: CGFloat) {
        // focusPosition = x + C1 + C2 * (x / C3) = x * (1 + C2 / C3) + C1
        
        let axisFadingWidth = _axisWidthForViewWidth(bounds.width)
        let viewWidth = bounds.width
        
        let c1 = axisFadingWidth + contentLeftMargin + appearance.itemWidth / 2.0
        let c2 = viewWidth - contentRightMargin - contentLeftMargin - appearance.itemWidth - axisFadingWidth
        let c3 = contentSize.width - viewWidth
        
        let x = bounds.origin.x
        let progress = x / c3
        let position = x + c1 + c2 * progress
        
        return (position, c1, c2, c3)
    }
    
    func focusPositionWithViewBounds(bounds: CGRect) -> CGFloat {
        return _focusParamsWithViewBounds(bounds).position
    }
    
    func scrollOffsetForItemAtIndexPath(indexPath: NSIndexPath, withViewSize size: CGSize) -> CGFloat {
        // let itemCenterX = focusPosition, find origin.x
        // focusPosition = x + C1 + C2 * (x / C3) = x * (1 + C2 / C3) + C1
        // x = (focusPosition - C1) / (1 + C2 / C3)
        
        let itemCenterX = frameForItemAtIndexPath(indexPath, withViewHeight: size.height).midX
        let (_, c1, c2, c3) = _focusParamsWithViewBounds(CGRect(origin: CGPointZero, size: size))
        
        let viewWidth = size.width
        
        return (itemCenterX - c1) / (1 + c2 / c3)
    }
    
    func visibleSectionsInRect(rect: CGRect) -> Range<Int>? {
        if sectionFrames.count == 0 {
            return nil
        }
        
        var first = sectionFrames.insertionIndexOf(rect) { $0.minX < $1.minX }
        first = max(first - 1, 0)
        
        var last = min(first + 1, sectionFrames.count - 1)
        
        while last < sectionFrames.count && rect.intersects(sectionFrames[last]) {
            ++last
        }
        
        return first..<last
    }
    
    func frameForItemAtIndexPath(indexPath: NSIndexPath, withViewHeight viewHeight: CGFloat) -> CGRect {
        let sectionFrame = sectionFrames[indexPath.section]
        var rect = CGRectZero
        
        let sectionSeparatorWidth = appearance.showSectionSeparator ? appearance.backgroundLineWidth : 0
        rect.origin.x = sectionFrame.minX + sectionSeparatorWidth + (appearance.itemWidth + appearance.itemPadding) * CGFloat(indexPath.item)
        rect.size.width = appearance.itemWidth
        
        let (startY, endY) = chartAreaVerticalRangeForViewHeight(viewHeight)
        
        rect.origin.y = startY
        rect.size.height = endY - startY
        
        return rect
    }
    
    init(dataSource: RWSCDataSource, appearance: RWSCAppearance, viewSize: CGSize) {
        self.dataSource = dataSource
        self.appearance = appearance
        
        let viewWidth = viewSize.width
        
        contentLeftMargin = appearance.contentMargins.left
        contentRightMargin = appearance.contentMargins.right
        
        var sectionFrames: [CGRect] = []
        var sectionTitleWidths: [CGFloat] = []
        
        var x = contentLeftMargin
        if appearance.showAxis && dataSource.axis != nil {
            x += appearance.axisAreaWidthForViewWith(viewWidth)
        }
        
        for isec in 0..<dataSource.numberOfSections() {
            var titleWidth: CGFloat = 0.0
            if let title = dataSource.titleForSection(isec) where appearance.showSectionTitles {
                titleWidth = (title as NSString).sizeWithAttributes([NSFontAttributeName: appearance.sectionTitleFont]).width
            }
            
            let numberOfItems = dataSource.numberOfItemsInSection(isec)
            
            let sectionSeparatorWidth = appearance.showSectionSeparator ? appearance.backgroundLineWidth : 0
            var sectionWidth = sectionSeparatorWidth + appearance.itemWidth * CGFloat(numberOfItems) + appearance.sectionPadding
            if numberOfItems > 0 {
                sectionWidth += CGFloat(numberOfItems - 1) * appearance.itemPadding
            }
            
            if appearance.showSectionTitles {
                let extra = appearance.sectionTitleInsets.left + appearance.sectionTitleInsets.right + appearance.backgroundLineWidth
                if appearance.truncateSectionTitleWhenNeeded {
                    titleWidth = min(titleWidth, sectionWidth - extra)
                } else {
                    sectionWidth = max(sectionWidth, titleWidth + extra)
                }
            }
            
            sectionFrames.append(CGRect(x: x, y: appearance.contentMargins.top, width: sectionWidth, height: viewSize.height - appearance.contentMargins.top - appearance.contentMargins.bottom))
            sectionTitleWidths.append(titleWidth)
            
            x += sectionWidth
        }
        
        x += contentRightMargin
        
        self.sectionFrames = sectionFrames
        self.sectionTitleWidths = sectionTitleWidths
        
        var contentWidth = x
        if contentWidth < viewSize.width * 1.2 {
            contentWidth += viewSize.width
        }
        contentSize = CGSize(width: contentWidth, height: viewSize.height)
        contentInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0)
        
        if appearance.showFocus {
            focusTextAreaHeight = appearance.focusTextFont.lineHeight * CGFloat(appearance.focusTextLineCount) + 2 * appearance.focusTextMargin.y + appearance.focusNeedleLength
        } else {
            focusTextAreaHeight = 0.0
        }
        
        if appearance.showSectionTitles {
            sectionTitleAreaHeight = appearance.sectionTitleFont.lineHeight + appearance.sectionTitleInsets.top + appearance.sectionTitleInsets.bottom
        } else {
            sectionTitleAreaHeight = 0.0
        }
        
        titleAreaHeight = sectionTitleAreaHeight + appearance.axisTextFont.lineHeight + 2 * appearance.axisTextMargin.y
        
        // right scroll bound
        if dataSource.numberOfSections() > 0 {
            let section = dataSource.numberOfSections() - 1
            let item = dataSource.numberOfItemsInSection(section) - 1
            if item >= 0 {
                let indexPath = NSIndexPath(forItem: item, inSection: section)
                rightScrollBound = scrollOffsetForItemAtIndexPath(indexPath, withViewSize: viewSize)
                // TODO: elimate dependency on view bounds of layout's funcs
            }
        }
    }
}

