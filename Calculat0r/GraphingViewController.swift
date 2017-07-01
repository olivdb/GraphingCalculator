//
//  GraphingViewController.swift
//  Calculat0r
//
//  Created by Olivier van den Biggelaar on 29/06/2017.
//  Copyright © 2017 Olivier van den Biggelaar. All rights reserved.
//

import UIKit

class GraphingViewController: UIViewController {

    @IBOutlet weak var graphView: GraphView! {
        didSet {
            let pinchHandler = #selector(GraphView.changeScale(byReactingTo:))
            let pinchRecognizer = UIPinchGestureRecognizer(target: graphView, action: pinchHandler)
            graphView.addGestureRecognizer(pinchRecognizer)
            let panHandler = #selector(GraphView.changeOrigin(byReactingToPan:))
            let panRecognizer = UIPanGestureRecognizer(target: graphView, action: panHandler)
            graphView.addGestureRecognizer(panRecognizer)
            let tapHandler = #selector(GraphView.changeOrigin(byReactingToTap:))
            let tapRecognizer = UITapGestureRecognizer(target: graphView, action: tapHandler)
            tapRecognizer.numberOfTapsRequired = 1
            tapRecognizer.numberOfTouchesRequired = 1
            graphView.addGestureRecognizer(tapRecognizer)
            restorePrefs()
            updateUI()
        }
    }
    
    // Public API
    
    var function: ((Double) -> Double)? { didSet { updateUI() } }
    
    
    // Private API
    
    private func updateUI() {
        graphView?.function = function
    }
    
    private struct UserDefaultKeys {
        static let originRelativeToCenter = "GraphingViewController.graphView.originRelativeToCenter"
        static let scale = "GraphingViewController.graphView.scale"
    }
    private func restorePrefs() {
        let defaults = UserDefaults.standard
        if let scale = defaults.object(forKey: UserDefaultKeys.scale) as? Double {
            graphView.scale = CGFloat(scale)
        }
        if let originString = defaults.object(forKey: UserDefaultKeys.originRelativeToCenter) as? String {
            graphView.originRelativeToCenter = CGPointFromString(originString)
        }
    }
    
    private func savePrefs() {
        let defaults = UserDefaults.standard
        defaults.set(NSStringFromCGPoint(graphView.originRelativeToCenter), forKey: UserDefaultKeys.originRelativeToCenter)
        defaults.set(Double(graphView.scale), forKey: UserDefaultKeys.scale)
        defaults.synchronize()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        savePrefs()
    }

}
