//
//  ViewController.swift
//  fastdial
//
//  Created by Brian J Hernacki on 6/5/14.
//  Updated 4/19/17
//  Copyright (c) 2014 Brian J Hernacki. All rights reserved.
//

import UIKit
import EventKit
import Foundation
import Intents
import AVFoundation
import WatchConnectivity

class ViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, WCSessionDelegate {
    //our various UI connections
    @IBOutlet var mainLabel: UILabel!
    @IBOutlet var mainButton: UIButton!
    @IBOutlet var dateButton: UIButton!
    @IBOutlet var doneButton: UIButton!
    @IBOutlet var conflictList: UITableView!
    @IBOutlet weak var datePicker: UIDatePicker!

    // all the calendar/event parsing smarts are in here
    var myDialer: ConferenceDial = ConferenceDial()
    // keep track if we've spawned a call to control re-activation list reloads
    var didCall: Bool = false
    let mySynthesizer = AVSpeechSynthesizer()
    var watchCommSession: WCSession? = nil
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        INPreferences.requestSiriAuthorization { (status) in
            NSLog("New status: \(status)")
        }
        
        // fire up the speech machine
        let myTestUtterance = AVSpeechUtterance(string: "welcome to fast dial")
        mySynthesizer.speak(myTestUtterance)
        startWatchComms()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if (self.didCall == false) {
             NSLog("Reloading event data")
           self.reload();
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    func handleEventSelection() {
        
        if myDialer.eventsWithCallData.count <= 0 {
            // UI updates on main thread
            DispatchQueue.main.async(execute: {
                self.mainLabel.text = "No events found"
                self.mainLabel.isHidden = false
                self.conflictList.isHidden = true
                self.mainButton.isHidden = false})
            let myTestUtterance = AVSpeechUtterance(string: "no events found")
            self.mySynthesizer.speak(myTestUtterance)
            return
        }
        
        if myDialer.eventsWithCallData.count == 1 {
            // UI updates on main thread
            DispatchQueue.main.async(execute: {
                self.mainLabel.text = "Dialing "+self.myDialer.eventsWithCallData[0].eventTitle!
                self.mainLabel.isHidden = false
                self.conflictList.isHidden = true
            })
            let myTestUtterance = AVSpeechUtterance(string: "Dialing "+self.myDialer.eventsWithCallData[0].eventTitle!)
            self.mySynthesizer.speak(myTestUtterance)
            self.dialPhone(self.myDialer.eventsWithCallData[0])
            self.didCall = true
        } else {
            // UI updates on main thread
            DispatchQueue.main.async(execute: {
                self.conflictList.isHidden = false
                self.conflictList.reloadData()
            })
            let myTestUtterance = AVSpeechUtterance(string: "\(myDialer.eventsWithCallData.count) events")
            self.mySynthesizer.speak(myTestUtterance)
            
            
        }
        // UI updates on main thread
        DispatchQueue.main.async(execute: {
            self.conflictList.isHidden = false
            self.conflictList.reloadData()
        })
    }

    
    @IBAction
    func handleAgainButton(_ button: UIButton) {
        
        // XXX would be nice to animate fade
        self.mainLabel.isHidden = false
        self.mainButton.isHidden = true
        self.didCall = false
        self.reload();
    }
    
    @IBAction
    func handleDateButton(_ button: UIButton) {
        
        self.datePicker.isHidden = false;
        self.doneButton.isHidden = false;
        self.mainButton.isHidden = true;
        self.mainLabel.isHidden = true;
        self.conflictList.isHidden = true;
        
    }
    
    @IBAction
    func handleDoneButton(_ button: UIButton) {
        
        self.datePicker.isHidden = true;
        self.doneButton.isHidden = true;
        self.mainButton.isHidden = false;
        self.mainLabel.isHidden = false;
        self.conflictList.isHidden = false;
        
        self.myDialer.useDate =  self.datePicker.date
        self.reload();
    }
    
    
    func reload() {
        let globalConcurrentQueue = DispatchQueue.global(qos: DispatchQoS.QoSClass.default)
        
        globalConcurrentQueue.async(execute: {
            self.myDialer.readCalendar()
            self.handleEventSelection()
            // Now send to the watch if there is one
            if self.watchCommSession != nil {
                // Send events to watch over active session
                let callEvents = self.myDialer.toDictionary() as Dictionary<String, Any>
                self.watchCommSession!.transferUserInfo(callEvents)
            }

        })
    }
    
    // UITableViewDataSource
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let myCell = conflictList.dequeueReusableCell(withIdentifier: "BasicTableCell")! as UITableViewCell
        
        let row = (indexPath as NSIndexPath).row
        myCell.textLabel!.text = myDialer.eventsWithCallData[row].eventTitle
        myCell.textLabel!.textAlignment = .center
        myCell.textLabel!.textColor = UIColor.white
        myCell.textLabel!.font = UIFont.systemFont(ofSize: 20)
        
        return myCell
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return myDialer.eventsWithCallData.count
    }
    
    //UITableViewDelegate
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.dialPhone(myDialer.eventsWithCallData[(indexPath as NSIndexPath).row])
        self.didCall = true
    }
    
    func dialPhone(_ event: CallData) {
        // dial the phone
        guard let dialURL = URL(string: event.dialString!) else {
            return
        }
        let uiapp = UIApplication.shared
        
        uiapp.open(dialURL)
        let myTestUtterance = AVSpeechUtterance(string: "Dialing "+event.eventTitle!)
        self.mySynthesizer.speak(myTestUtterance)
    }
    
    // MARK: Watch communication
    
    func startWatchComms() {
        if WCSession.isSupported() {
            let defaultSession = WCSession.default()
            defaultSession.delegate = self
            defaultSession.activate()
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Swift.Void) {
        /*
         Because this method is likely to be called when the app is in the
         background, begin a background task. Starting a background task ensures
         that your app is not suspended before it has a chance to send its reply.
         */
        let application = UIApplication.shared
        
        var identifier = UIBackgroundTaskInvalid;
        // The "endBlock" ensures that the background task is ended and the identifier is reset.
        let endBlock = {
            if identifier != UIBackgroundTaskInvalid {
                application.endBackgroundTask(identifier)
            }
            identifier = UIBackgroundTaskInvalid
        };
        
        identifier = application.beginBackgroundTask(expirationHandler: endBlock)
        
        // Re-assign the "reply" block to include a call to "endBlock" after "reply" is called.
        let replyHandler = {(replyInfo: [String : Any]) in
            replyHandler(replyInfo)
            
            endBlock();
        }
        
        // Receives text input result from the WatchKit app extension.
        print("Message: \(message)")
        
        // To bootstrap a watch-only launch the watch sends the message so we will send it the meetings
        let callEvents = self.myDialer.toDictionary() as Dictionary<String, Any>
        session.transferUserInfo(callEvents)
        
        // Sends a confirmation message to the WatchKit app extension that the text input result was received.
        replyHandler(["Confirmation" : "Text was received."])
    }
    
    func session(_ session: WCSession, didReceiveUserInfo info: [String : Any] = [:]) {
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        
        if activationState == WCSessionActivationState.activated {
            watchCommSession = session
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        watchCommSession = nil
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        watchCommSession = nil
    }
}








