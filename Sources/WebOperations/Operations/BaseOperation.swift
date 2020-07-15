//
//  BaseOperation
//  WebOperations
//
//  Created by Jacob Davis on 4/20/20.
//  Copyright (c) 2020 Proton Chain LLC, Delaware
//

import Foundation

/**
Create your own Operations be inheriting from BaseOperation. Checkout BasicGetOperation.swift for an example
*/
public class BaseOperation: Operation {
    
    public var baseOperation: BaseOperation!
    public var completion: ((Result<Any?, Error>) -> Void)!
    
    override init() {}
    
    public convenience init(_ completion: @escaping ((Result<Any?, Error>) -> Void)) {
        self.init()
        self.completion = completion
    }
    
    private var _executing = false {
        willSet { willChangeValue(forKey: "isExecuting") }
        didSet { didChangeValue(forKey: "isExecuting") }
    }
    
    private var _finished = false {
        willSet { willChangeValue(forKey: "isFinished") }
        didSet { didChangeValue(forKey: "isFinished") }
    }
    
    public override var isExecuting: Bool {
        return _executing
    }
    
    public override func main() {
        
        guard isCancelled == false else {
            finish()
            return
        }
        
        _executing = true
        
    }
    
    public override var isFinished: Bool {
        return _finished
    }
    
    public func finish(retval: Any? = nil, error: Error? = nil) {
        DispatchQueue.main.async {
            if let error = error {
                self.completion?(.failure(error))
            } else {
                self.completion?(.success(retval))
            }
        }
        _executing = false
        _finished = true
    }
    
    public func finish<T: Codable>(retval: T? = nil, error: Error? = nil) {
        DispatchQueue.main.async {
            if let error = error {
                self.completion?(.failure(error))
            } else {
                self.completion?(.success(retval))
            }
        }
        _executing = false
        _finished = true
    }
    
}
