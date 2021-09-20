/*******************************************************************************
 * The MIT License (MIT)
 * 
 * Copyright (c) 2021 Jean-David Gadina - www.xs-labs.com
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 ******************************************************************************/

import Foundation
import SecurityFoundation
import ServiceManagement

public class Helper
{
    public enum Domain
    {
        case user
        case system
    }
    
    private let authorization: AuthorizationRef
    public  let domain:        Domain
    public  let label:         String
    
    public init( domain: Domain, label: String ) throws
    {
        if label.isEmpty
        {
            throw NSError( title: "Invalid Label", message: "Label cannot be empty." )
        }
        
        guard let bundleID = Bundle.main.object( forInfoDictionaryKey: "CFBundleIdentifier" ) as? String, bundleID.count > 0 else
        {
            throw NSError( title: "Invalid Bundle", message: "Cannot retrieve CFBundleIdentifier from the main bundle." )
        }
        
        if label.hasPrefix( bundleID ) == false
        {
            throw NSError( title: "Invalid Label", message: "Label does not begin with \( bundleID )" )
        }
        
        var auth: AuthorizationRef?
        
        guard AuthorizationCreate( nil, nil, [], &auth ) == errAuthorizationSuccess, let authorization = auth else
        {
            throw NSError( title: "Unauthorized", message: "Cannot create an authorization for the current process" )
        }
        
        self.authorization = authorization
        self.domain        = domain
        self.label         = label
    }
    
    deinit
    {
        AuthorizationFree( self.authorization, [] )
    }
    
    private var domainString: CFString
    {
        switch self.domain
        {
            case .user:   return kSMDomainUserLaunchd
            case .system: return kSMDomainSystemLaunchd
        }
    }
    
    public var isInstalled: Bool
    {
        guard let job        = SMJobCopyDictionary( self.domainString, self.label as CFString )?.takeRetainedValue() as? [ AnyHashable : Any ],
              let jobLabel   = job[ "Label" ]   as? String,
              let jobProgram = job[ "Program" ] as? String
        else
        {
            return false
        }
        
        return jobLabel == label && jobProgram.hasSuffix( label )
    }
    
    public func install() throws
    {
        var error: Unmanaged< CFError >?
        
        guard SMJobBless( self.domainString, self.label as CFString, self.authorization, &error ) else
        {
            if let error = error, let reason = CFErrorCopyFailureReason( error.takeRetainedValue() )
            {
                throw NSError( title: "Cannot bless job", message: reason as String )
            }
            else
            {
                throw NSError( title: "Cannot bless job", message: "Unknown error" )
            }
        }
    }
    
    public func remove() throws
    {
        var error: Unmanaged< CFError >?
        
        guard SMJobRemove( self.domainString, self.label as CFString, self.authorization, true, &error ) else
        {
            if let error = error, let reason = CFErrorCopyFailureReason( error.takeRetainedValue() )
            {
                throw NSError(title: "Cannot remove job", message: reason as String )
            }
            else
            {
                throw NSError(title: "Cannot remove job", message: "Unknown error" )
            }
        }
    }
}
