//
//  ViewController.swift
//  Calculat0r
//
//  Created by Olivier van den Biggelaar on 14/06/2017.
//  Copyright © 2017 Olivier van den Biggelaar. All rights reserved.
//

import UIKit

class CalculatorViewController: UIViewController, UISplitViewControllerDelegate {

    @IBOutlet weak var display: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var memoryLabel: UILabel!
    @IBOutlet weak var errorLabel: UILabel!
    @IBOutlet weak var graphButton: UIButton!
    
    private var userIsInTheMiddleOfTyping = false
    
    private let formattedForDisplay: (_ number: Double) -> String = {
        let formatter = NumberFormatter()
        formatter.numberStyle = NumberFormatter.Style.decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 6
        return { formatter.string(from: NSNumber(value: $0))! }
    }()
    
    @IBAction func touchDigit(_ sender: UIButton) {
        let digit = sender.currentTitle!
        
        if userIsInTheMiddleOfTyping {
            let textCurrentlyInDisplay = display.text!
            if digit != "." || !textCurrentlyInDisplay.contains(".") {
                display.text = textCurrentlyInDisplay + digit
            }
        } else {
            display.text = digit == "." ? "0." : digit
            userIsInTheMiddleOfTyping = true
        }
    }
    
    var displayValue: Double {
        get {
            return Double(display.text!)!
        }
        set {
            
            display.text = formattedForDisplay(newValue)
        }
    }
    
    private var brain = CalculatorBrain()
    private var valueOfM: [String: Double] = [:]
    
    @IBAction func performOperation(_ sender: UIButton) {
        if userIsInTheMiddleOfTyping {
            brain.setOperand(displayValue)
            userIsInTheMiddleOfTyping = false
        }
        if let mathematicalSymbol = sender.currentTitle {
            brain.performOperation(mathematicalSymbol)
        }
        evaluate()
    }
    
    @IBAction func clear() {
        brain.reset()
        displayValue = 0
        descriptionLabel.text = nil
        userIsInTheMiddleOfTyping = false
        valueOfM = [:]
        memoryLabel.text = nil
        errorLabel.text = nil
    }
    
    @IBAction func backspace() {
        if userIsInTheMiddleOfTyping {
            if display.text!.characters.count <= 1 {
                displayValue = 0
                userIsInTheMiddleOfTyping = false
            } else {
                let lastIndex = display.text!.index(before: display.text!.endIndex)
                display.text!.remove(at: lastIndex)
            }
        } else {
            brain.undo()
            evaluate()
        }
    }
    
    private func evaluate() {
        let (result, resultIsPending, description, errorMessage) = brain.evaluateAndReportErrors(using: valueOfM, formattedForDescription: formattedForDisplay)
        descriptionLabel.text = description + (resultIsPending ? "…" : "=")
        graphButton.isEnabled = !resultIsPending
        graphButton.alpha = resultIsPending ? 0.25 : 1.0
        if let result = result {
            displayValue = result
        }
        errorLabel.text = errorMessage
    }
    
    @IBAction func setM() {
        userIsInTheMiddleOfTyping = false
        valueOfM["M"] =  displayValue
        memoryLabel.text = "M=" + formattedForDisplay(displayValue)
        evaluate()
    }
    
    @IBAction func useM() {
        userIsInTheMiddleOfTyping = false
        brain.setOperand(variable: "M")
        evaluate()
    }
    
    private let showGraphSegueIdentifier = "Show Graph"
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == showGraphSegueIdentifier {
            var destinationVC = segue.destination
            if let navigationVC = destinationVC as? UINavigationController {
                destinationVC = navigationVC.visibleViewController ?? destinationVC
            }
            if let graphingVC = destinationVC as? GraphingViewController {
                prepareGraphingViewController(graphingVC)
            }
        }
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == showGraphSegueIdentifier {
            return !brain.evaluate().isPending
        }
        return true
    }
    
    private func prepareGraphingViewController(_ graphingVC: GraphingViewController) {
        if brain.evaluate().result != nil {
            graphingVC.function = { [unowned self = self] x in self.brain.evaluate(using: ["M": x]).result! }
            graphingVC.navigationItem.title = "y(M)=\(brain.evaluate(formattedForDescription: formattedForDisplay).description)"
        } else {
            graphingVC.function = nil
            graphingVC.navigationItem.title = "No Function"
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        splitViewController?.delegate = self
        if let program = UserDefaults.standard.object(forKey: UserDefaultKeys.program) {
            brain.program = program
            evaluate()
        }
    }
    
    func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController:UIViewController, onto primaryViewController:UIViewController) -> Bool {
        return true
    }
    
    private struct UserDefaultKeys {
        static let program = "CalculatorViewController.brain.program"
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        UserDefaults.standard.set(brain.program, forKey: UserDefaultKeys.program)
    }

}

