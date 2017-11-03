//
//  InterfaceController.swift
//  FastDialWatch Extension
//
//  Created by Jeremy Bennett on 4/6/17.
//  Copyright © 2017 Brian J Hernacki. All rights reserved.
//

import WatchKit
import WatchConnectivity
import Foundation


class InterfaceController: WKInterfaceController, WCSessionDelegate {
    @IBOutlet weak var meetingTable: WKInterfaceTable!
    var myDialer: ConferenceDial = ConferenceDial()
    var didCall = false
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        // Configure interface objects here.
        
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        
        let globalConcurrentQueue = DispatchQueue.global(qos: DispatchQoS.QoSClass.default)
        
        startWatchComms()

        globalConcurrentQueue.async(execute: {
            //self.myDialer.readCalendar()
            self.configureTable(withMeetings: self.myDialer.eventsWithCallData)
        })
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }

    func configureTable(withMeetings meetings: [CallData]) {
        
        if meetings.count <= 0 {
            self.meetingTable.setNumberOfRows(1, withRowType: "meetingRowID")
            let row: MeetingRow = self.meetingTable.rowController(at: 0) as! MeetingRow
            row.rowDescription.setText("No events")
            return
        }
        self.meetingTable.setNumberOfRows(meetings.count, withRowType: "meetingRowID")
        var rowNum = 0
        for meeting in meetings {
            let row: MeetingRow = self.meetingTable.rowController(at: rowNum) as! MeetingRow
            row.rowDescription.setText(meeting.eventTitle)
            rowNum += 1
        }
        
        if meetings.count == 1 {
            guard let dialURL = URL(string: meetings[0].dialString!) else {
                return
            }
            if !didCall {
                WKExtension.shared().openSystemURL(dialURL)
                self.didCall = true
            }
        }

    }
    
    override func table(_ table: WKInterfaceTable, didSelectRowAt rowIndex: Int) {
        if myDialer.eventsWithCallData.count <= 0 {
            return
        }
        guard let dialURL = URL(string: myDialer.eventsWithCallData[rowIndex].dialString!) else {
            return
        }
        WKExtension.shared().openSystemURL(dialURL)

    }
    
    // MARK: Watch communication
    func startWatchComms() {
        if !WCSession.isSupported() {
            return
        }
        
        let defaultSession = WCSession.default()
        defaultSession.delegate = self
        
        if defaultSession.activationState != .activated {
            defaultSession.activate()
        }
        
        // Send a ping to the phone to wake it up and send over the latest calendar
        defaultSession.sendMessage(["Req" : "Meetings"], replyHandler: nil, errorHandler: nil)
        
        
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Swift.Void) {
        /*
         Because this method is likely to be called when the app is in the
         background, begin a background task. Starting a background task ensures
         that your app is not suspended before it has a chance to send its reply.
         */
        
    }

    
    func session(_ session: WCSession, didReceiveUserInfo info: [String : Any] = [:]) {
        // Should be incoming call data from the phone
        let globalConcurrentQueue = DispatchQueue.global(qos: DispatchQoS.QoSClass.default)
        myDialer.fromDictonary(info as! Dictionary<String, String>)
        globalConcurrentQueue.async(execute: {
            self.configureTable(withMeetings: self.myDialer.eventsWithCallData)
        })
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        
        if activationState == WCSessionActivationState.activated {
            
            session.sendMessage(["Calendar" : "want"], replyHandler: { (replyMessage) in
                print("Reply Info: \(replyMessage)")
            }, errorHandler: { (error) in
                print("Error: \(error.localizedDescription)")
            })
        }
    }
}
