//
//  QuaxoDecode.swift
//  QuaxoDecode
//
//  Created by Javid Sheikh on 12/04/2019.
//  Copyright © 2019 QuaxoDigital. All rights reserved.
//

import Foundation
import RxSwift

public class QuaxoDecode {
    
    private let session: URLSession
    private let bag = DisposeBag()
    private lazy var defaultHeaders: [String: String] = ["Content-Type": "application/json"]
    
    init(configuration: URLSessionConfiguration = .default,
         delegate: URLSessionDelegate? = nil,
         delegateQueue: OperationQueue? = nil) {
        session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: delegateQueue)
    }
    
    private func requestTo(_ url: String,
                   method: HTTPMethod,
                   headers: [String: String]?,
                   parameters: [String: Any]?) -> Single<Data> {
        
        guard let url = URL(string: url) else {
            return .error(NetworkError.invalidURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        if let headers = headers {
            headers.forEach { defaultHeaders[$0] = $1 }
        }
        request.allHTTPHeaderFields = defaultHeaders
        if let parameters = parameters {
            request.httpBody = try? JSONSerialization.data(withJSONObject: parameters as Any)
        }
        
        return Single.create { [unowned self] single in
            
            let dataTask = self.session.dataTask(with: request) { data, response, error in
                if let error = error {
                    return single(.error(error))
                }
                guard let httpResponse = response as? HTTPURLResponse else {
                    return single(.error(NetworkError.invalidResponse))
                }
                if 200..<300 ~= httpResponse.statusCode {
                    guard let data = data else { return single(.error(NetworkError.invalidData)) }
                    return single(.success(data))
                } else {
                    return single(.error(NetworkError.requestUnsuccessful))
                }
            }
            dataTask.resume()
            
            return Disposables.create()
        }
    }
    
    private func decode<T: Decodable>(data: Data) -> Single<T> {
        return Single.create { single in
            let decoder = JSONDecoder()
            do {
                let model = try decoder.decode(T.self, from: data)
                single(.success(model))
            }
            catch let error {
                single(.error(error))
            }
            return Disposables.create()
            
        }
    }
    
    public func decodeJSONToType<T: Decodable>(_ url: String,
                                      method: HTTPMethod,
                                      headers: [String: String]? = nil,
                                      parameters: [String: Any]? = nil) -> Single<T> {
        
        let single: Single<T> = requestTo(url, method: .get, headers: headers, parameters: parameters)
            .flatMap(decode)
        return single
    }
}

public enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

public enum NetworkError: Error {
    case invalidURL
    case invalidResponse
    case invalidData
    case requestUnsuccessful
}

public enum Result<T, U> {
    case success(T)
    case error(U)
}
