//
//  GraphView.swift
//  Calculat0r
//
//  Created by Olivier van den Biggelaar on 29/06/2017.
//  Copyright © 2017 Olivier van den Biggelaar. All rights reserved.
//

import UIKit

@IBDesignable
class GraphView: UIView {

    // Public API
    
    @IBInspectable
    var scale: CGFloat = 1.0 { didSet { setNeedsDisplay() } }
    
    @IBInspectable
    var axesColor: UIColor = UIColor.black { didSet { setNeedsDisplay() } }
    
    @IBInspectable
    var curveColor: UIColor = UIColor.blue { didSet { setNeedsDisplay() } }
    
    @IBInspectable
    var pointsPerAxisUnitBeforeScale: CGFloat = 25 { didSet { setNeedsDisplay() } }
    
    @IBInspectable
    var maxDeltaYPerPointForContinuity: CGFloat = 500 { didSet { setNeedsDisplay() } }
    
    var originRelativeToCenter: CGPoint = CGPoint.zero { didSet { setNeedsDisplay() } }
    
    var function: ((Double) -> Double)? { didSet { setNeedsDisplay() } }
    
    func changeScale(byReactingTo pinchRecognizer: UIPinchGestureRecognizer) {
        switch pinchRecognizer.state {
        case .changed, .ended:
            scale *= pinchRecognizer.scale
            pinchRecognizer.scale = 1
        default:
            break
        }
    }
    
    @IBInspectable
    var panUsingSnapshot: Bool = true
    
    private var snapshot: UIView!
    func changeOrigin(byReactingToPan panRecognizer: UIPanGestureRecognizer) {
        switch panRecognizer.state {
        case .began where panUsingSnapshot:
            snapshot = snapshotView(afterScreenUpdates: false)
            snapshot.alpha = 0.6
            addSubview(snapshot)
        case .ended where panUsingSnapshot:
            originRelativeToCenter.x += snapshot.frame.origin.x
            originRelativeToCenter.y += snapshot.frame.origin.y
            snapshot.removeFromSuperview()
            snapshot = nil
            setNeedsDisplay()
        case .changed, .ended:
            if panUsingSnapshot {
                snapshot.center.x += panRecognizer.translation(in: self).x
                snapshot.center.y += panRecognizer.translation(in: self).y
            } else {
                originRelativeToCenter.x += panRecognizer.translation(in: self).x
                originRelativeToCenter.y += panRecognizer.translation(in: self).y
            }
            panRecognizer.setTranslation(CGPoint.zero, in: self)
        default:
            break
        }
    }
    
    func changeOrigin(byReactingToTap tapRecognizer: UITapGestureRecognizer) {
        if tapRecognizer.state == .ended {
            origin = tapRecognizer.location(in: self)
        }
    }
    
    // Private API
    
    private var origin: CGPoint {
        get {
            return CGPoint(x: bounds.midX + originRelativeToCenter.x,
                           y: bounds.midY + originRelativeToCenter.y)
        }
        set {
            originRelativeToCenter.x = newValue.x - bounds.midX
            originRelativeToCenter.y = newValue.y - bounds.midY
        }
    }
    
    private var pointsPerAxisUnit: CGFloat { return pointsPerAxisUnitBeforeScale * scale }
    
    override func draw(_ rect: CGRect) {
        drawAxes(in: rect)
        plotFunction(in: rect)
    }
    
    private func drawAxes(in rect: CGRect) {
        let axesDrawer = AxesDrawer(color: axesColor, contentScaleFactor: contentScaleFactor)
        axesDrawer.drawAxes(in: rect, origin: origin, pointsPerUnit: pointsPerAxisUnit )
    }
    
    private func plotFunction(in rect: CGRect) {
        if let f = function {
            curveColor.set()
            let curve = UIBezierPath()
            var previousPointWasOK = false
            var previousY: CGFloat?
            func functionIsContinuous(_ previousY: CGFloat?, _ currentY: CGFloat) -> Bool {
                guard let previousY = previousY else { return true }
                return abs(currentY - previousY) <= maxDeltaYPerPointForContinuity / contentScaleFactor
            }
            for x_pts in stride(from: 0, through: rect.width, by: 1 / contentScaleFactor) {
                let x_units = Double((x_pts - origin.x) / pointsPerAxisUnit)
                let y_units = f(x_units)
                let currentPointIsOK = y_units.isNormal || y_units.isZero
                if currentPointIsOK {
                    let y_pts = CGFloat(-y_units) * pointsPerAxisUnit + origin.y
                    let currentPoint = CGPoint(x: x_pts, y: y_pts)
                    if previousPointWasOK, functionIsContinuous(previousY, y_pts) {
                        curve.addLine(to: currentPoint)
                    } else {
                        curve.move(to: currentPoint)
                    }
                    previousY = y_pts
                } else {
                    previousY = nil
                }
                previousPointWasOK = currentPointIsOK
            }
            curve.stroke()
        }
    }
    
    
}
