//
//  CalculatorBrain.swift
//  Calculat0r
//
//  Created by Olivier van den Biggelaar on 15/06/2017.
//  Copyright © 2017 Olivier van den Biggelaar. All rights reserved.
//

import Foundation

struct CalculatorBrain {
    
    typealias ValidationErrorMessage = String?
    typealias UnaryOperationArgumentValidator = (Double) -> ValidationErrorMessage
    typealias BinaryOperationArgumentValidator = (Double, Double) -> ValidationErrorMessage
    
    private enum Operation {
        case constant(Double)
        case unaryOperation((Double) -> Double, UnaryOperationArgumentValidator)
        case binaryOperation((Double, Double) -> Double, BinaryOperationArgumentValidator)
        case equals
        case random
    }
    
    private var operations: Dictionary<String, Operation> = [
        "π" : .constant(Double.pi),
        "e" : .constant(M_E),
        "√" : .unaryOperation(sqrt) { $0 < 0 ? "Argument of sqrt should be positive" : nil },
        "tan": .unaryOperation(tan) { _ in nil },
        "cos": .unaryOperation(cos) { _ in nil },
        "sin": .unaryOperation(sin) { _ in nil },
        "exp": .unaryOperation(exp) { _ in nil },
        "log": .unaryOperation(log) { $0 <= 0 ? "Argument of log should be strictly positive" : nil },
        "abs": .unaryOperation(abs) { _ in nil },
        "±": .unaryOperation({ -$0 }) { _ in nil },
        "+": .binaryOperation({ $0 + $1 }) { _ in nil },
        "-": .binaryOperation({ $0 - $1 }) { _ in nil },
        "×": .binaryOperation({ $0 * $1 }) { _ in nil },
        "÷": .binaryOperation({ $0 / $1 }) { $1 == 0 ? "Cannot divide by zero" : nil },
        "^": .binaryOperation(pow) { _ in nil },
        "=": .equals,
        "?": .random
    ]
    
    // deprecated
    var result: Double? { let (result, _, _) = evaluate(); return result }
    var resultIsPending: Bool { let (_, isPending, _) = evaluate(); return isPending }
    var description: String { let (_, _, description) = evaluate(); return description }
    
    mutating func reset() { history = [] }
    
    enum Element {
        case operation(String)
        case operand(Double)
        case variable(String)
    }
    
    private var history = [Element]()
    
    mutating func performOperation(_ symbol: String) {
        history.append(.operation(symbol))
    }
    
    mutating func setOperand(variable named: String) {
        history.append(.variable(named))
    }
    
    mutating func setOperand(_ operand: Double) {
        history.append(.operand(operand))
    }
    
    mutating func undo() {
        if !history.isEmpty { history.removeLast() }
    }
    
    func evaluate(using variables: Dictionary<String,Double>? = nil, formattedForDescription: (_ operand: Double) -> String = { String($0) })
        -> (result: Double?, isPending: Bool, description: String) {
            let (result, isPending, description, _) = evaluateAndReportErrors(using: variables, formattedForDescription: formattedForDescription)
            return (result, isPending, description)
    }
    
    func evaluateAndReportErrors(using variables: Dictionary<String,Double>? = nil, formattedForDescription: (_ operand: Double) -> String = { String($0) })
        -> (result: Double?, isPending: Bool, description: String, errorMessage: String?) {
            struct PendingBinaryOperation {
                var function: (value: (Double, Double) -> Double, description: String)
                var validator: BinaryOperationArgumentValidator
                var firstOperand: (value: Double, description: String)
                
                func perform(with secondOperand: (value: Double, description: String))
                    -> (accumumatorValue: Double, accumulatorDescription: String, errorMessage: ValidationErrorMessage) {
                        return (function.value(firstOperand.value, secondOperand.value), description + secondOperand.description, validator(firstOperand.value, secondOperand.value))
                }
                var description: String {
                    return firstOperand.description + function.description
                }
            }
            
            var accumulator: (value: Double, description: String)?
            var errorMessage: ValidationErrorMessage
            var pendingBinaryOperation : PendingBinaryOperation?
            
            func performOperation(_ symbol: String) {
                func performPendingBinaryOperation() {
                    let lastErrorMessage: ValidationErrorMessage
                    (accumulator!.value, accumulator!.description, lastErrorMessage) = pendingBinaryOperation!.perform(with: accumulator!)
                    errorMessage = errorMessage ?? lastErrorMessage
                }
                if let operation = operations[symbol] {
                    switch operation {
                    case .constant(let value):
                        accumulator = (value, symbol)
                    case let .unaryOperation(function, validator):
                        if let accu = accumulator {
                            if let error = validator(accu.value) {
                                errorMessage = error
                            }
                            accumulator = (function(accu.value), symbol + "(" + accu.description + ")")
                        }
                    case let .binaryOperation(function, validator):
                        if accumulator != nil {
                            if pendingBinaryOperation != nil { performPendingBinaryOperation() }
                            pendingBinaryOperation = PendingBinaryOperation(function: (function, symbol), validator: validator, firstOperand: accumulator!)
                            accumulator = nil
                        }
                    case .equals:
                        if accumulator != nil, pendingBinaryOperation != nil {
                            performPendingBinaryOperation()
                            pendingBinaryOperation = nil
                        }
                    case .random:
                        let rand = Double(arc4random())/Double(UInt32.max)
                        accumulator = (rand, "rand")
                    }
                }
                
            }
            
            for elem in history {
                switch elem {
                case .operand(let value):
                    accumulator = (value, formattedForDescription(value))
                case .variable(let name):
                    accumulator = (variables?[name] ?? 0, name)
                case . operation(let symbol):
                    performOperation(symbol)
                }
            }
            
            let description = (pendingBinaryOperation?.description ?? "") + (accumulator?.description ?? "")
            return (result: accumulator?.value, isPending: pendingBinaryOperation != nil, description: description, errorMessage: errorMessage)
    }
    
    private enum ElemKeys: String {
        case operand, operation, variable
    }
    var program: Any {
        get {
            var prog = [Any]()
            for elem in history {
                switch elem {
                case .operand(let value):
                    prog.append([ElemKeys.operand.rawValue: value])
                case .operation(let symbol):
                    prog.append([ElemKeys.operation.rawValue: symbol])
                case .variable(let name):
                    prog.append([ElemKeys.variable.rawValue: name])
                }
            }
            return prog
        }
        set {
            reset()
            if let prog = newValue as? [[String: Any]] {
                for elem in prog {
                    switch elem.keys.first! {
                    case ElemKeys.operand.rawValue:
                        history.append(.operand(elem.values.first! as! Double))
                    case ElemKeys.operation.rawValue:
                        history.append(.operation(elem.values.first! as! String))
                    case ElemKeys.variable.rawValue:
                        history.append(.variable(elem.values.first! as! String))
                    default:
                        break
                    }
                    
                }
            }
        }
    }
    
}
