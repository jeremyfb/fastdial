//
//  InterfaceController.swift
//  FastDialWatch Extension
//
//  Created by Jeremy Bennett on 4/6/17.
//  Copyright © 2017 Brian J Hernacki. All rights reserved.
//

import WatchKit
import Foundation


class InterfaceController: WKInterfaceController {
    @IBOutlet weak var meetingTable: WKInterfaceTable!
    var myDialer: ConferenceDial = ConferenceDial()
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        // Configure interface objects here.
        self.myDialer.readCalendar()
        self.configureTable(withMeetings: myDialer.eventsWithCallData)
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        
        
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
            WKExtension.shared().openSystemURL(dialURL)
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
}
