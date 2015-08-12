//
//  ViewController.swift
//  RWScrollChartDemo
//
//  Created by Zhang Bin on 2015-08-06.
//  Copyright (c) 2015年 Zhang Bin. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    @IBOutlet weak var chart: RWScrollChart!
    
    func makeDataSetRatios() -> [[CGFloat]] {
        return map(self.sections) { itemCount in
            map(Array(0..<itemCount)) { _ in
                CGFloat(Int(arc4random()) % 1000) / 1000.0
            }
        }
    }
    
    lazy var sections: [Int] = map(Array(0..<10)) { _ in
        Int(arc4random()) % 30 + 1
    }
    
    var barData: [[CGFloat]] = []
    var lineData: [[CGFloat]] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        barData = makeDataSetRatios()
        lineData = map(makeDataSetRatios()) { section in
            map(section) {
                0.5 * $0 + 0.2
            }
        }
        
        var appearance = RWScrollChart.Appearance()
        appearance.backgroundColor = UIColor.darkGrayColor()
        // appearance.itemWidth = 50.0
        
        var dataSource = RWScrollChart.DataSource()
        dataSource.numberOfSections = { self.sections.count }
        dataSource.numberOfItemsInSection = { self.sections[$0] }
        dataSource.titleForSection = { "Section \($0)" }
        dataSource.textForItemAtIndexPath = { "\($0.section) - \($0.item)" }
        
        var lineDataSet = RWScrollChart.LineDataSet(
            pointAtIndexPath: { indexPath in
                if indexPath.section % 2 == 1 {
                    return nil
                }
                return self.lineData[indexPath.section][indexPath.item]
            }
        )
        lineDataSet.showFocus = true
        lineDataSet.smoothed = true
        
        var barDataSet = RWScrollChart.BarDataSet(
            barAtIndexPath: { indexPath in
                return [(self.barData[indexPath.section][indexPath.item], UIColor.grayColor())]
            }
        )
        barDataSet.showFocus = false
        
        dataSource.axis = RWScrollChart.Axis(items: map(Array(0...4)) { i in
            let ratio = CGFloat(1.0 / 4.0) * CGFloat(i)
            return (ratio, toString(ratio))
            }
        )
        
        dataSource.dataSets = [barDataSet, lineDataSet]
        
        chart.appearance = appearance
        chart.dataSource = dataSource
        chart.reloadData()
    }
}

