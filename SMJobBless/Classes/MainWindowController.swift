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

import Cocoa

public class MainWindowController: NSWindowController
{
    private let helper: Helper
    private var timer:  Timer?
    
    @objc public private( set ) dynamic var isInstalled       = false
    @objc public private( set ) dynamic var command           = "/bin/ls -al /var/root"
    @objc public private( set ) dynamic var terminationStatus = ""
    @objc public private( set ) dynamic var standardOutput    = ""
    @objc public private( set ) dynamic var standardError     = ""
    
    @IBOutlet private var standardOutputTextView: NSTextView!
    @IBOutlet private var standardErrorTextView : NSTextView!
    
    public init( helper: Helper )
    {
        self.helper = helper
        
        super.init( window: nil )
    }
    
    required init?( coder: NSCoder )
    {
        nil
    }
    
    public override var windowNibName: NSNib.Name?
    {
        "MainWindowController"
    }
    
    public override func windowDidLoad()
    {
        super.windowDidLoad()
        
        self.timer = Timer.scheduledTimer( timeInterval: 1, target: self, selector: #selector( refresh ), userInfo: nil, repeats: true )
        
        self.standardOutputTextView.font               = NSFont.userFixedPitchFont( ofSize: 11 )
        self.standardErrorTextView.font                = NSFont.userFixedPitchFont( ofSize: 11 )
        self.standardOutputTextView.textContainerInset = NSSize( width: 10, height: 10 )
        self.standardErrorTextView.textContainerInset  = NSSize( width: 10, height: 10 )
    }
    
    @objc private func refresh()
    {
        self.isInstalled = self.helper.isInstalled
    }
    
    @IBAction private func installHelper( _ sender: Any? )
    {
        do
        {
            try self.helper.install()
        }
        catch let error
        {
            NSAlert( error: error ).runModal()
        }
    }
    
    @IBAction private func removeHelper( _ sender: Any? )
    {
        do
        {
            try self.helper.remove()
        }
        catch let error
        {
            NSAlert( error: error ).runModal()
        }
    }
    
    @IBAction private func run( _ sender: Any? )
    {
        var parts = self.command.split( separator: " " ).map { String( $0 ) }
        
        guard parts.count > 0 else
        {
            NSSound.beep()
            
            return
        }
        
        let interface                    = NSXPCInterface( with: HelperProtocol.self )
        let connection                   = NSXPCConnection( machServiceName: self.helper.label, options: .privileged )
        connection.remoteObjectInterface = interface;
        
        connection.resume()
        
        let proxy = connection.remoteObjectProxyWithErrorHandler(
            {
                error in DispatchQueue.main.async
                {
                    NSAlert( error: error ).runModal()
                }
            }
        ) as? HelperProtocol
        
        self.terminationStatus = ""
        self.standardOutput    = ""
        self.standardError     = ""
        
        proxy?.execute( command: parts.remove( at: 0 ), arguments: parts )
        {
            status, output, error in DispatchQueue.main.async
            {
                self.terminationStatus = "\( status )"
                self.standardOutput    = output ?? ""
                self.standardError     = error  ?? ""
            }
        }
    }
}
