//
//  RWSCAppearance.swift
//  RWScrollChartDemo
//
//  Created by Zhang Bin on 2015-08-04.
//  Copyright (c) 2015年 Zhang Bin. All rights reserved.
//

import UIKit

struct RWSCAppearance {
    var backgroundColor = UIColor.clearColor()
    var contentMargins = UIEdgeInsets(top: 0.0, left: 15.0, bottom: 5.0, right: 15.0)
    
    var backgroundLineWidth: CGFloat = 0.5
    var horizontalLineColor = UIColor(white: 1.0, alpha: 0.1)
    
    var showSectionTitles = true
    var showSectionSeparator = true
    var sectionPadding: CGFloat = 1.0
    var sectionTitleFont = UIFont.systemFontOfSize(12.0)
    var sectionTitleInsets = UIEdgeInsets(top: 5.0, left: 5.0, bottom: 10.0, right: 5.0)
    var sectionTitleColor = UIColor.whiteColor()
    var sectionSeparatorColor = UIColor(white: 1.0, alpha: 0.5)
    var truncateSectionTitleWhenNeeded = false
    
    var itemPadding: CGFloat = 1.0
    var itemWidth: CGFloat = 15.0
    
    var showFocus = true
    var focusTextFont = UIFont.systemFontOfSize(12.0)
    var focusTextColor = UIColor(white: 0.2, alpha: 1.0)
    var focusTextBackgroundColor = UIColor.whiteColor()
    var focusTextMargin = CGPoint(x: 6.0, y: 1.0)
    var focusTextLineCount = 1
    var focusIndicatorRadius: CGFloat = 4.0
    var focusColor = UIColor.whiteColor()
    var focusStrokeWidth: CGFloat = 1.0
    var focusNeedleLength: CGFloat = 5.0
    var focusBubbleRoundedRadius: CGFloat = 2.0
    
    var showAxis = true
    var axisTextFont = UIFont.systemFontOfSize(10.0)
    var axisTextColor = UIColor.whiteColor()
    var axisBackgroundColor = UIColor(white: 0, alpha: 0.2)
    var axisTextMargin = CGPoint(x: 5.0, y: 2.0)
    var axisAreaWidthForViewWith: CGFloat -> CGFloat = { min(50.0, 0.2 * $0) }
    var axisLineColor = UIColor(white: 1.0, alpha: 0.05)
    var axisLineWidth: CGFloat = 1.0
    
    enum InitialPosition {
        case FirstItem
        case LastItem
    }
    
    var initialPosition: InitialPosition = .LastItem
}

