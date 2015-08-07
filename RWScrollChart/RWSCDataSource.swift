//
//  RWSCDataSource.swift
//  RWScrollChartDemo
//
//  Created by Zhang Bin on 2015-08-03.
//  Copyright (c) 2015年 Zhang Bin. All rights reserved.
//

import UIKit

protocol RWSCDataSetType {
    var showFocus: Bool { get }
}

struct RWSCLineDataSet: RWSCDataSetType {
    typealias DataProvider = NSIndexPath -> CGFloat?
    let pointAtIndexPath: DataProvider
    var lineWidth: CGFloat = 1.0
    var lineColor = UIColor.whiteColor()
    var smoothed = true
    var showFocus = true
    
    init(pointAtIndexPath: DataProvider) {
        self.pointAtIndexPath = pointAtIndexPath
    }
}

struct RWSCBarDataSet: RWSCDataSetType {
    typealias DataProvider = NSIndexPath -> [(ratio: CGFloat, color: UIColor)]?
    let barAtIndexPath: DataProvider
    var showFocus = true
    
    init(barAtIndexPath: DataProvider) {
        self.barAtIndexPath = barAtIndexPath
    }
}

struct RWSCAxis {
    typealias AxisItem = (ratio: CGFloat, text: String)
    var items: [AxisItem]
}

struct RWSCDataSource {
    var numberOfSections: (Void -> Int) = { 0 }
    var numberOfItemsInSection: Int -> Int = { _ in 0 }
    var titleForSection: Int -> String? = { _ in nil }
    var textForItemAtIndexPath: NSIndexPath -> String? = { _ in nil }
    var dataSets: [RWSCDataSetType] = []
    var axis: RWSCAxis? = nil
}

// axis

