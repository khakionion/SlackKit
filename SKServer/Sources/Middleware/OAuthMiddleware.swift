//
// OAuthMiddleware.swift
//
// Copyright © 2016 Peter Zignego. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import HTTPServer
import SKCommon
import Venice

public struct OAuthMiddleware: Middleware {

    private let clientID: String
    private let clientSecret: String
    private let state: String?
    private let redirectURI: String?
    internal(set) public var authed: ((OAuthResponse) -> Void)? = nil
    
    public init(clientID: String, clientSecret: String, state: String? = nil, redirectURI: String? = nil, authed: ((OAuthResponse) -> Void)? = nil) {
        self.clientID = clientID
        self.clientSecret = clientSecret
        self.state = state ?? ""
        self.redirectURI = redirectURI
        self.authed = authed
    }
    
    public func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        guard let response = AuthorizeResponse(queryItems: request.url.queryItems), let code = response.code, response.state == state else {
            return Response(status: .badRequest)
        }
        let channel = FallibleChannel<Response>()
        
        co {
            RestAPI.oauthAccess(clientID: self.clientID, clientSecret: self.clientSecret, code: code, redirectURI: self.redirectURI, success: { (response) in
                self.authed?(OAuthResponse(response: response))
                guard let redirect = self.redirectURI else {
                    channel.send(Response(status: .ok))
                    return
                }
                channel.send(Response(redirectTo: redirect))
            }, failure: { (error) in
                channel.send(error)
            })
        }

        return try channel.receive() ?? Response(status: .badRequest)
    }

}
