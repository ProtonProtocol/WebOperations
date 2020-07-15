//
//  WebOperations.swift
//  WebOperations
//
//  Created by Jacob Davis on 4/20/20.
//  Copyright (c) 2020 Proton Chain LLC, Delaware
//

import Foundation

public class WebOperations: NSObject {
    
    public var operationQueueSeq: OperationQueue
    public var operationQueueMulti: OperationQueue
    public var session: URLSession
    
    public enum RequestMethod: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
    }
    
    public enum Auth: String {
        case basic = "Basic"
        case bearer = "Bearer"
        case none = "none"
    }
    
    public enum ContentType: String {
        case applicationJson = "application/json"
        case none = ""
    }
    
    /**
     The WebOperations.Config struct which is a required param for initialisation of WebOperations
    */
    public struct Config {
        
        public var sessionConfig: URLSessionConfiguration
        public var queueNamePrefix: String
        
        /**
         Use this to build your configuration for the WebOperations singleton
         - Parameter sessionConfig: The session configuration used for the URLSession
         - Parameter queueNamePrefix: The prefix used to name the operation queues
         */
        public init(sessionConfig: URLSessionConfiguration = .default, queueNamePrefix: String = "") {
            self.sessionConfig = sessionConfig
            self.queueNamePrefix = queueNamePrefix
        }
        
    }
    
    public static var config: Config?
    
    static let shared = WebOperations()
    
    /**
     Use this function as your starting point to initialize the singleton class WebOperations
     - Parameter config: The WebOperations.Config struct which is a required param for initialisation of WebOperations
     - Returns: Initialized WebOperations singleton
     */
    @discardableResult
    public static func initialize(_ config: Config) -> WebOperations {
        WebOperations.config = config
        return self.shared
    }
    
    private override init() {

        guard let config = WebOperations.config else {
            fatalError("ERROR: You must call WebOperations.initialize(_ config: Config) before accessing WebOperations.shared")
        }
        
        session = URLSession(configuration: config.sessionConfig)
        
        operationQueueSeq = OperationQueue()
        operationQueueSeq.qualityOfService = .utility
        operationQueueSeq.maxConcurrentOperationCount = 1
        operationQueueSeq.name = "\(config.queueNamePrefix).\(UUID()).seq"
        
        operationQueueMulti = OperationQueue()
        operationQueueMulti.qualityOfService = .utility
        operationQueueMulti.name = "\(config.queueNamePrefix).\(UUID()).multi"
        
    }
    
    // MARK: - Operation Services
    
    public func addSeq(_ operation: BaseOperation,
                completion: ((Result<Any?, Error>) -> Void)?) {
        
        operation.completion = completion
        operationQueueSeq.addOperation(operation)
        
    }
    
    public func addMulti(_ operation: BaseOperation,
                  completion: ((Result<Any?, Error>) -> Void)?) {
        
        operation.completion = completion
        operationQueueMulti.addOperation(operation)
        
    }
    
    public func suspend(_ isSuspended: Bool) {
        operationQueueSeq.isSuspended = isSuspended
        operationQueueMulti.isSuspended = isSuspended
    }
    
    public func cancelAll() {
        operationQueueSeq.cancelAllOperations()
        operationQueueMulti.cancelAllOperations()
    }
    
    // MARK: - HTTP Base Requests
    
    public func request(method: RequestMethod = .get, auth: Auth = .none, authValue: String? = nil, contentType: ContentType = .applicationJson, url: URL, parameters: [String: Any]? = nil, completion: ((Result<Data?, Error>) -> Void)?) {

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        
        if let authValue = authValue, auth != .none {
            request.addValue("\(auth.rawValue) \(authValue)", forHTTPHeaderField: "Authorization")
        }

        if contentType == .applicationJson {
            request.addValue(contentType.rawValue, forHTTPHeaderField: "Content-Type")
            request.addValue(contentType.rawValue, forHTTPHeaderField: "Accept")
        }

        if let parameters = parameters, !parameters.isEmpty {
            do {
                let body = try JSONSerialization.data(withJSONObject: parameters, options: [])
                request.httpBody = body
            } catch {
                DispatchQueue.main.async {
                    completion?(.failure(error))
                }
            }
        }

        let task = session.dataTask(with: request) { data, response, error in

            if let error = error {
                DispatchQueue.main.async {
                    completion?(.failure(error))
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    completion?(.failure(WebOperationsError.error("No data")))
                }
                return
            }

            guard let response = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    completion?(.failure(WebOperationsError.error("Response Error")))
                }
                return
            }

            if !(200...299).contains(response.statusCode) {
                DispatchQueue.main.async {
                    completion?(.failure(WebOperationsError.error("Response Error Status code: \(response.statusCode)")))
                }
                return
            }

            DispatchQueue.main.async {
                completion?(.success(data))
            }

        }

        task.resume()
        
    }

    public func request<T: Any>(method: RequestMethod = .get, auth: Auth = .none, authValue: String? = nil, contentType: ContentType = .applicationJson, url: URL, parameters: [String: Any]? = nil, completion: ((Result<T?, Error>) -> Void)?) {

        request(method: method, auth: auth, authValue: authValue, contentType: contentType, url: url, parameters: parameters) { result in

            switch result {

            case .success(let data):

                guard let data = data else {
                    DispatchQueue.main.async {
                        completion?(.failure(WebOperationsError.error("No data")))
                    }
                    return
                }

                do {
                    let json = try JSONSerialization.jsonObject(with: data, options: [])
                    DispatchQueue.main.async {
                        completion?(.success(json as? T))
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion?(.failure(error))
                    }
                }

            case .failure(let error):
                DispatchQueue.main.async {
                    completion?(.failure(error))
                }

            }

        }

    }
    
    public func request<T: Codable>(method: RequestMethod = .get, auth: Auth = .none, authValue: String? = nil, contentType: ContentType = .applicationJson, url: URL, parameters: [String: Any]? = nil, completion: ((Result<T, Error>) -> Void)?) {

        request(method: method, auth: auth, authValue: authValue, contentType: contentType, url: url, parameters: parameters) { result in

            switch result {

            case .success(let data):

                guard let data = data else {
                    DispatchQueue.main.async {
                        completion?(.failure(WebOperationsError.error("No data")))
                    }
                    return
                }

                do {
                    let res = try JSONDecoder().decode(T.self, from: data)
                    DispatchQueue.main.async {
                        completion?(.success(res))
                    }
                } catch {
                    completion?(.failure(error))
                }

            case .failure(let error):
                DispatchQueue.main.async {
                    completion?(.failure(error))
                }
            }

        }

    }
    
}

public enum WebOperationsError: Error, LocalizedError {
    
    case error(String)
    
    public var errorDescription: String? {
        switch self {
        case .error(let message):
            return "🌐 \(message)"
        }
    }
    
}
