//
//  RWSCDrawing.swift
//  RWScrollChartDemo
//
//  Created by Zhang Bin on 2015-08-05.
//  Copyright (c) 2015年 Zhang Bin. All rights reserved.
//

import UIKit

protocol RWSCDataSetDrawable {
    func drawSections(sections: Range<Int>, inChart chart: RWScrollChart, withRect rect: CGRect, context: CGContextRef)
    func drawFocusAtIndexPath(indexPath: NSIndexPath, withItemFrame frame: CGRect, inChart chart: RWScrollChart, context: CGContextRef) -> Bool
}

extension RWSCLineDataSet: RWSCDataSetDrawable {
    func drawSections(sections: Range<Int>, inChart chart: RWScrollChart, withRect rect: CGRect, context: CGContextRef) {
        // find index paths needed to draw
        
        // 0. expand to +/- 1 sections
        let sectionRangeStart = max(0, sections.startIndex - 1)
        let sectionRangeEnd = min(sections.endIndex + 1, chart.dataSource.numberOfSections())
        let sectionRange = sectionRangeStart..<sectionRangeEnd
        
        // 1. gather all index paths that have valid data
        var indexPaths: [NSIndexPath] = []
        for section in sectionRange {
            for item in 0..<chart.dataSource.numberOfItemsInSection(section) {
                let indexPath = NSIndexPath(forItem: item, inSection: section)
                if let _ = pointAtIndexPath(indexPath) {
                    indexPaths.append(indexPath)
                }
            }
        }
        
        // 2. find visible items range
        let indexPathsIndices = Array(0..<indexPaths.count)
        var (firstVisible, _) = indexPathsIndices.binarySearch { toCheck in
            let indexPath = indexPaths[toCheck]
            let midFrame = chart.layout.frameForItemAtIndexPath(indexPath, withViewHeight: chart.bounds.height)
            if midFrame.maxX > rect.minX {
                return .ContinueLeft
            } else if midFrame.maxX < rect.minX {
                return .ContinueRight
            } else {
                return .Match
            }
        }
        var (lastVisible, _) = indexPathsIndices.binarySearch { toCheck in
            let indexPath = indexPaths[toCheck]
            let midFrame = chart.layout.frameForItemAtIndexPath(indexPath, withViewHeight: chart.bounds.height)
            if midFrame.minX > rect.maxX {
                return .ContinueLeft
            } else if midFrame.minX < rect.maxX {
                return .ContinueRight
            } else {
                return .Match
            }
        }
        
        // 3. expand 2 items each before / after visible items
        for _ in 1...2 {
            firstVisible = max(0, firstVisible - 1)
            lastVisible = min(lastVisible + 1, indexPaths.count)
        }
        
        // 4. group index paths into non-adjacent groups
        let indexPathsIndexGroups = split(Array(firstVisible..<lastVisible)) { i -> Bool in
            if i == firstVisible {
                return false
            }
            
            return indexPaths[i].section - indexPaths[i - 1].section > 1
        }
        
        // 5. convert to point groups
        let pointGroups = map(indexPathsIndexGroups) { group -> [CGPoint] in
            map(group) { indexPathsIndex in
                let indexPath = indexPaths[indexPathsIndex]
                let itemFrame = chart.layout.frameForItemAtIndexPath(indexPath, withViewHeight: chart.bounds.height)
                let ratio = self.pointAtIndexPath(indexPath)!
                let x = itemFrame.midX
                let y = itemFrame.maxY - itemFrame.height * ratio
                return CGPoint(x: x, y: y)
            }
        }
        
        // draw lines
        lineColor.setStroke()
        
        for points in pointGroups {
            var bezier: UIBezierPath?
            if smoothed {
                bezier = _interpolatePointsUsingHermite(points)
            } else {
                bezier = UIBezierPath()
                bezier?.moveToPoint(points[0])
                map(points[1..<points.count]) { bezier?.addLineToPoint($0) }
            }
            bezier?.lineWidth = lineWidth
            bezier?.stroke()
            
            if let fillColor = fillColor where points.count > 1 {
                let y0 = chart.layout.chartAreaVerticalRangeForViewHeight(chart.bounds.height).end
                bezier?.addLineToPoint(CGPoint(x: points.last!.x, y: y0))
                bezier?.addLineToPoint(CGPoint(x: points.first!.x, y: y0))
                bezier?.closePath()
                fillColor.setFill()
                bezier?.fill()
            }
        }
        
    }
    
    func drawFocusAtIndexPath(indexPath: NSIndexPath, withItemFrame frame: CGRect, inChart chart: RWScrollChart, context: CGContextRef) -> Bool {
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
    func drawSection(section: Int, inChart chart: RWScrollChart, withRect rect: CGRect, context: CGContextRef) {
        for item in 0..<chart.dataSource.numberOfItemsInSection(section) {
            let indexPath = NSIndexPath(forItem: item, inSection: section)
            if let bars = barAtIndexPath(indexPath) {
                let itemFrame = chart.layout.frameForItemAtIndexPath(indexPath, withViewHeight: chart.bounds.height)
                if !rect.intersects(itemFrame) {
                    continue
                }
                var y = itemFrame.maxY
                for (ratio, color) in bars {
                    let segHeight = itemFrame.height * ratio
                    var segFrame = itemFrame
                    segFrame.origin.y = y - segHeight
                    segFrame.size.height = segHeight
                    y -= segHeight
                    color.setFill()
                    CGContextFillRect(context, segFrame)
                }
            }
        }
    }
    
    func drawSections(sections: Range<Int>, inChart chart: RWScrollChart, withRect rect: CGRect, context: CGContextRef) {
        for section in sections {
            drawSection(section, inChart: chart, withRect: rect, context: context)
        }
    }
    
    func drawFocusAtIndexPath(indexPath: NSIndexPath, withItemFrame frame: CGRect, inChart chart: RWScrollChart, context: CGContextRef) -> Bool {
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

private func _interpolatePointsUsingHermite(points: [CGPoint]) -> UIBezierPath! {
    // http://spin.atomicobject.com/2014/05/28/ios-interpolating-points/
    // https://github.com/jnfisher/ios-curve-interpolation
    if points.count < 2 {
        return nil
    }
    
    let smoothTension = CGFloat(1.0 / 3.0)
    let nCurves = points.count - 1
    let bezier = UIBezierPath()
    
    for ii in 0..<nCurves {
        var currPt = points[ii]
        if ii == 0 {
            bezier.moveToPoint(currPt)
        }
        
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
        
        bezier.addCurveToPoint(endPt, controlPoint1: ctrlPt1, controlPoint2: ctrlPt2)
    }
    
    return bezier
}
    