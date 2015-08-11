//
//  RWSCDrawing.swift
//  RWScrollChartDemo
//
//  Created by Zhang Bin on 2015-08-05.
//  Copyright (c) 2015年 Zhang Bin. All rights reserved.
//

import UIKit

protocol RWSCDataSetDrawingHint { }

struct RWSCLineDrawingHint: RWSCDataSetDrawingHint {
    typealias ControlPointsType = (ctrlPt1: CGPoint, ctrlPt2: CGPoint)
    let groups: [[(CGPoint, ControlPointsType?)]]
    
    init(lineDataSet: RWSCLineDataSet, chart: RWScrollChart) {
        let pointGroups = lineDataSet._nonAdjacentPointGroupsInChart(chart)
        var groups: [[(CGPoint, ControlPointsType?)]] = map(pointGroups) { group in
            map(group) { ($0, nil) }
        }
        if lineDataSet.smoothed {
            let controlPointGroups: [[ControlPointsType?]] = map(pointGroups, _interpolateControlPointssUsingHermite)
            for iGroup in 0..<groups.count {
                for iPoint in 0..<groups[iGroup].count {
                    groups[iGroup][iPoint].1 = controlPointGroups[iGroup][iPoint]
                }
            }
        }
        
        self.groups = groups
    }
}

struct RWSCBarDrawingHint: RWSCDataSetDrawingHint {
    let bars: [(CGRect, UIColor)]
    
    init(barDataSet: RWSCBarDataSet, chart: RWScrollChart) {
        var bars: [(CGRect, UIColor)] = []
        
        for section in 0..<chart.dataSource.numberOfSections() {
            for item in 0..<chart.dataSource.numberOfItemsInSection(section) {
                let indexPath = NSIndexPath(forItem: item, inSection: section)
                if let barsData = barDataSet.barAtIndexPath(indexPath) {
                    let itemFrame = chart.layout.frameForItemAtIndexPath(indexPath, withViewHeight: chart.bounds.height)
                    var y = itemFrame.maxY
                    for (ratio, color) in barsData {
                        let segHeight = itemFrame.height * ratio
                        var segFrame = itemFrame
                        segFrame.origin.y = y - segHeight
                        segFrame.size.height = segHeight
                        y -= segHeight
                        bars += [(segFrame, color)]
                    }
                }
            }
        }
        
        self.bars = bars
    }
}

extension RWSCLineDataSet {
    private func _allValidValues(dataSource: RWSCDataSource) -> (values: [CGFloat], indexPaths: [NSIndexPath]) {
        var values: [CGFloat] = []
        var indexPaths: [NSIndexPath] = []
        
        for section in 0..<dataSource.numberOfSections() {
            for item in 0..<dataSource.numberOfItemsInSection(section) {
                let indexPath = NSIndexPath(forItem: item, inSection: section)
                if let value = pointAtIndexPath(indexPath) {
                    values.append(value)
                    indexPaths.append(indexPath)
                }
            }
        }
        
        return (values, indexPaths)
    }
    
    private func _nonAdjacentPointGroupsInChart(chart: RWScrollChart) -> [[CGPoint]] {
        let (values, indexPaths) = _allValidValues(chart.dataSource)
        
        let points = map(0..<values.count) { i -> CGPoint in
            let indexPath = indexPaths[i]
            let itemFrame = chart.layout.frameForItemAtIndexPath(indexPath, withViewHeight: chart.bounds.height)
            let ratio = values[i]
            let x = itemFrame.midX
            let y = itemFrame.maxY - itemFrame.height * ratio
            return CGPoint(x: x, y: y)
        }
        
        let nonAdjacentGroups = _divideNonAdjacentIndexPathGroups(indexPaths)
        let pointGroups = map(nonAdjacentGroups) { range in
            map(range) { points[$0] }
        }
        
        return pointGroups
    }
}

protocol RWSCDataSetDrawable {
    func drawingHintForChart(chart: RWScrollChart) -> RWSCDataSetDrawingHint?
    func drawInChart(chart: RWScrollChart, withRect rect: CGRect, visibleSections: Range<Int>, context: CGContextRef, drawingHint: RWSCDataSetDrawingHint?)
    func drawFocusAtIndexPath(indexPath: NSIndexPath, withItemFrame frame: CGRect, inChart chart: RWScrollChart, context: CGContextRef, drawingHint: RWSCDataSetDrawingHint?) -> Bool
}

extension RWSCLineDataSet: RWSCDataSetDrawable {
    func drawingHintForChart(chart: RWScrollChart) -> RWSCDataSetDrawingHint? {
        return RWSCLineDrawingHint(lineDataSet: self, chart: chart)
    }
    
    func drawInChart(chart: RWScrollChart, withRect rect: CGRect, visibleSections: Range<Int>, context: CGContextRef, drawingHint: RWSCDataSetDrawingHint?) {
        // 0. extract point groups
        var groups = (drawingHint as! RWSCLineDrawingHint).groups
        
        // 1. find visible groups
        let visibleGroupIndexRange = groups.indexRangeByBinarySearch {
            if $0.last!.0.x < rect.minX {
                return .ContinueRight
            }
            if $0.first!.0.x > rect.maxX {
                return .ContinueLeft
            }
            return .Match
        }
        
        if visibleGroupIndexRange == nil {
            return
        }
        
        // 2. remove invisible points from first and last group. boundary expanded by 2 points.
        let removeInvisibleInGroup = { (groupIndex: Int) -> Void in
            let visibleIndexRange = groups[groupIndex].indexRangeByBinarySearch {
                if $0.0.x < rect.minX {
                    return .ContinueRight
                }
                if $0.0.x > rect.maxX {
                    return .ContinueLeft
                }
                return .Match
            }
            
            if visibleIndexRange == nil {
                return
            }
            
            var startIndex = visibleIndexRange!.startIndex
            var endIndex = visibleIndexRange!.endIndex
            
            for expand in 1...2 {
                startIndex = max(0, startIndex - 1)
                endIndex = min(groups[groupIndex].count - 1, endIndex + 1)
            }
            
            let remaining = Array(groups[groupIndex][startIndex ... endIndex])
            groups[groupIndex] = remaining
        }
        
        let firstGroupIndex = visibleGroupIndexRange!.startIndex
        removeInvisibleInGroup(firstGroupIndex)
        var lastGroupIndex = visibleGroupIndexRange!.endIndex - 1
        if lastGroupIndex > firstGroupIndex {
            removeInvisibleInGroup(lastGroupIndex)
        }
        
        // 3. draw
        for groupIndex in firstGroupIndex ... lastGroupIndex {
            let points = groups[groupIndex]
            
            if points.count < 2 {
                continue
            }
            
            let bezier = UIBezierPath()
            bezier.moveToPoint(points.first!.0)
            for ipt in 1..<points.count {
                let point = points[ipt]
                if let controlPoints = point.1 where smoothed {
                    bezier.addCurveToPoint(point.0, controlPoint1: controlPoints.ctrlPt1, controlPoint2: controlPoints.ctrlPt2)
                } else {
                    bezier.addLineToPoint(point.0)
                }
            }
            
            lineColor.setStroke()
            CGContextSetLineWidth(context, lineWidth)
            bezier.stroke()
            
            if let fillColor = fillColor {
                let y0 = chart.layout.chartAreaVerticalRangeForViewHeight(chart.bounds.height).end
                bezier.addLineToPoint(CGPoint(x: points.last!.0.x, y: y0))
                bezier.addLineToPoint(CGPoint(x: points.first!.0.x, y: y0))
                bezier.closePath()
                fillColor.setFill()
                bezier.fill()
            }
        }
    }
    
    func drawFocusAtIndexPath(indexPath: NSIndexPath, withItemFrame frame: CGRect, inChart chart: RWScrollChart, context: CGContextRef, drawingHint: RWSCDataSetDrawingHint?) -> Bool {
        let ratio = pointAtIndexPath(indexPath)
        if ratio == nil {
            return false
        }
        
        let point = CGPoint(x: frame.midX, y: frame.maxY - frame.height * ratio!)
        let radius = chart.appearance.focusIndicatorRadius // min(chart.appearance.itemWidth / 2.0, lineWidth * 4.0)
        let rect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2.0, height: radius * 2.0)
        chart.appearance.focusColor.setFill()
        CGContextFillEllipseInRect(context, rect)
        
        return true
    }
}

extension RWSCBarDataSet: RWSCDataSetDrawable {
    func drawingHintForChart(chart: RWScrollChart) -> RWSCDataSetDrawingHint? {
        return RWSCBarDrawingHint(barDataSet: self, chart: chart)
    }
    
    func drawInChart(chart: RWScrollChart, withRect rect: CGRect, visibleSections: Range<Int>, context: CGContextRef, drawingHint: RWSCDataSetDrawingHint?) {
        let barDrawingHint = drawingHint as? RWSCBarDrawingHint
        if barDrawingHint == nil {
            return
        }
        
        // 0. find bar range
        let visibleIndexRange = barDrawingHint!.bars.indexRangeByBinarySearch {
            let bar = $0.0
            if bar.minX > rect.maxX {
                return .ContinueLeft
            }
            if bar.maxX < rect.minX {
                return .ContinueRight
            }
            return .Match
        }
        
        // 1. draw
        if let visibleIndexRange = visibleIndexRange {
            for index in visibleIndexRange {
                let (bar, color) = barDrawingHint!.bars[index]
                color.setFill()
                CGContextFillRect(context, bar)
            }
        }
    }
    
    func drawFocusAtIndexPath(indexPath: NSIndexPath, withItemFrame frame: CGRect, inChart chart: RWScrollChart, context: CGContextRef, drawingHint: RWSCDataSetDrawingHint?) -> Bool {
        let bars = barAtIndexPath(indexPath)
        if bars == nil {
            return false
        }
        
        let ratio = reduce(bars!, CGFloat(0.0)) { $0 + $1.ratio }
        var barFrame = frame
        barFrame.size.height *= ratio
        barFrame.origin.y = frame.maxY - barFrame.size.height
        
        var focusFrame = barFrame
        // focusFrame.inset(dx: -CGFloat(chart.appearance.focusStrokeWidth), dy: -CGFloat(chart.appearance.focusStrokeWidth))
        
        CGContextSetStrokeColorWithColor(context, chart.appearance.focusColor.CGColor)
        CGContextSetLineWidth(context, chart.appearance.focusStrokeWidth)
        CGContextStrokeRect(context, focusFrame)
        
        return true
    }
}

private func _interpolateControlPointssUsingHermite(points: [CGPoint]) -> [RWSCLineDrawingHint.ControlPointsType?] {
    typealias CP = RWSCLineDrawingHint.ControlPointsType
    // http://spin.atomicobject.com/2014/05/28/ios-interpolating-points/
    // https://github.com/jnfisher/ios-curve-interpolation
    if points.count < 2 {
        return Array(Repeat(count: points.count, repeatedValue: Optional<CP>.None))
    }
    
    let smoothTension = CGFloat(1.0 / 3.0)
    let nCurves = points.count - 1
    
    var result: [CP?] = [nil]
    
    for ii in 0..<nCurves {
        var currPt = points[ii]
        /*
        if ii == 0 {
        bezier.moveToPoint(currPt)
        }
        */
        
        var nextii = (ii + 1) % points.count
        var previi = (ii - 1 < 0 ? points.count - 1 : ii - 1)
        
        var prevPt = points[previi]
        var nextPt = points[nextii]
        var endPt = nextPt
        
        var mx = CGFloat()
        var my = CGFloat()
        
        if ii > 0 {
            mx = (nextPt.x - currPt.x) * 0.5 + (currPt.x - prevPt.x) * 0.5
            my = (nextPt.y - currPt.y) * 0.5 + (currPt.y - prevPt.y) * 0.5
        } else {
            mx = (nextPt.x - currPt.x) * 0.5;
            my = (nextPt.y - currPt.y) * 0.5;
        }
        
        let ctrlPt1 = CGPoint(x: currPt.x + mx * smoothTension, y: currPt.y + my * smoothTension)
        
        
        currPt = points[nextii]
        nextii = (nextii + 1) % points.count
        previi = ii
        prevPt = points[previi]
        nextPt = points[nextii]
        
        if ii < nCurves - 1 {
            mx = (nextPt.x - currPt.x) * 0.5 + (currPt.x - prevPt.x) * 0.5
            my = (nextPt.y - currPt.y) * 0.5 + (currPt.y - prevPt.y) * 0.5
        } else {
            mx = (currPt.x - prevPt.x) * 0.5
            my = (currPt.y - prevPt.y) * 0.5
        }
        
        let ctrlPt2 = CGPoint(x: currPt.x - mx * smoothTension, y: currPt.y - my * smoothTension)
        
        // bezier.addCurveToPoint(endPt, controlPoint1: ctrlPt1, controlPoint2: ctrlPt2)
        result.append((ctrlPt1: ctrlPt1, ctrlPt2: ctrlPt2))
    }
    
    return result
}

private func _divideNonAdjacentIndexPathGroups(indexPaths: [NSIndexPath]) -> [Range<Int>] {
    let indexes = split(Array(0..<indexPaths.count)) { i -> Bool in
        if i == 0 {
            return false
        }
        return indexPaths[i].section - indexPaths[i - 1].section > 1
    }
    
    return map(indexes) { $0.startIndex ..< $0.endIndex }
}
