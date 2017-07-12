//
//  ConferenceDial.swift
//  fastdial
//
//  Created by Brian J Hernacki on 3/10/17.
//  Updated 4/19/17
//  Copyright © 2017 Brian J Hernacki. All rights reserved.
//

import UIKit
import EventKit
import WatchKit
import Foundation
import Intents

class CallData {
    var dialString: String?
    var eventTitle: String?
    
    init (withString: String, withTitle: String) {
        dialString = withString
        eventTitle = withTitle
    }
    
    func getDialURL() -> URL? {
        if dialString == nil {
            return nil
        }
        let myURL = URL(string: dialString!)
        
        return myURL
    }
}
class ConferenceDial {
    
    // I find this a vile sin but the data quality leaves me little choice
    // were I not just hacking, we'd make this a preference or something
    let defaultPhoneNumber = "+1-916-356-2663"
    var eventsWithCallData: [CallData] = []
    var haveCalAccess: Bool = false
    let store = EKEventStore()
    var useDate: Date?
    
    func readCalendar() {
        // XXX should wait for this to return before proceeding
        store.requestAccess(to: EKEntityType.event, completion:{granted, error in self.handleCalendarAccess(granted: granted, error: error)})
        var retryCount = 0
        while haveCalAccess == false {
            sleep(2)
            retryCount+=1
            if retryCount > 10 {
                NSLog("Too many attempts to ask permission for calendar. Bailing.")
                break
            }
        }
        
    }
    
    func handleCalendarAccess(granted: Bool, error: Error?) {
        NSLog("Calendar access: \(granted)")
        haveCalAccess = granted
        if granted == false {
            NSLog("No access to calendar. Should notify user.")
            return
        }
        
        let cals = store.calendars(for: EKEntityType.event)
        NSLog("We can access \(cals.count) calendars")
        for cal in cals {
            NSLog("    \(cal.title)")
        }
        let currentEvents = self.getCurrentCalendarEvent()
        self.extractEventData(currentEvents)
    }
    
    func getCurrentCalendarEvent() -> [EKEvent]? {
        //let eventWindow: TimeInterval = 15*60
        let eventWindow: TimeInterval = 15*60

        
        NSLog("Looking for events")

        
        // XXX should wait for this to return before proceeding
        // store.requestAccess(to: EKEntityType.event, completion:{granted, error in assert(granted); return })
        
        var now = Date()
        // Create the start/end date components. this allows us to select the date center mostly for debug purposes
        if (useDate != nil) {
            now = useDate!
            useDate = nil
        }
        
        NSLog("Using date \(now)")
        
        let startDate = Date(timeInterval:-eventWindow, since:now)
        let endDate = Date(timeInterval:eventWindow, since:now)
        
        // Create the predicate from the event store's instance method
        let predicate = store.predicateForEvents(withStart: startDate, end:endDate, calendars:nil)
        let events = store.events(matching: predicate)
        
        // Fetch all events that match the predicate
        if events.count > 0 {
            
            NSLog("Found \(events.count) matching events")
            
            return events
        }
        return nil
    }
    
    func extractEventData(_ events: [EKEvent]?) {
        let maxTitleLength = 15
        
        if let theEvents = events {
            var myEventsWithCallData: [CallData] = []
            for event in theEvents {
                NSLog("Found event \(event.title)")
                
                if let myNotes = event.notes {
                    
                    let (phoneNumber, codeString) = extractDialStrings(myNotes)
                    var dialString = "tel:"
                    
                    if let myPhoneNumber = phoneNumber {
                        dialString += myPhoneNumber
                    } else {
                        // handle some odd mtgs that only include bridge ID and code
                        if codeString!.characters.count > 0 {
                            dialString += self.defaultPhoneNumber
                        } else {
                            // no phone number and no dial code, nothing to do
                            NSLog("No dial information in event")
                            continue
                        }
                    }
                    
                    if let myCodeString = codeString {
                        dialString += ",,"
                        dialString += myCodeString
                        dialString += "#"
                    }
                    
                    // truncate long event titles to fit more nicely on screen
                    var truncatedTitle = event.title
                    if event.title.characters.count > maxTitleLength {
                        NSLog("Truncating long name")
                        truncatedTitle = (event.title as NSString).substring(to: maxTitleLength)
                    }
                    
                    let thisCallData = CallData(withString:dialString, withTitle:truncatedTitle)
                    myEventsWithCallData.append(thisCallData)
                }
            }
            
            eventsWithCallData = myEventsWithCallData
        }
        NSLog("Found \(eventsWithCallData.count) events with call data")
    }
    
/*
    func dialPhone(_ dialString: String!, eventTitle: String!) {
        NSLog("Dialing phone with [\(dialString)]")
        
        // dial the phone
            let uiapp = UIApplication.shared
            uiapp.open(URL(string: dialString)!)
    }
 */

    
    // The only thing necessary for evil to triumph is for good men to attempt to solve problems
    // using regular expressions
    func extractDialStrings(_ text: String) -> (phoneNumber: String?, codeString: String?) {
        
        var phoneNumber: String?
        var codeString: String = ""
        let regexPatternPhoneNumber = "[\\(\\)\\d]{0,5}[\\s\\.-]{0,1}\\d{3}[\\.-]\\d{4}"
        let regexPatternBridgeID = "Choose bridge (\\d)"
        let regexPatternBridgeCode = "Conference ID: (\\d{6,})"
        
        if let s = extractPatternMatch(text, pattern: regexPatternPhoneNumber, field: 0) {
            phoneNumber = s
            NSLog("Number is is [\(String(describing: phoneNumber))]")
        }
        
        if let s = extractPatternMatch(text, pattern: regexPatternBridgeID, field: 1) {
            codeString += s
        }
        
        if let s = extractPatternMatch(text, pattern: regexPatternBridgeCode, field: 1) {
            codeString += ",,,\(s)"
        }
        
        NSLog("Code is [\(codeString)]")
        return (phoneNumber, codeString)
    }
    
    func extractPatternMatch(_ string: String, pattern: String, field: Int) -> String? {
        
        let myText: NSString = string as NSString
        var resultString: String?
        let myMatchOptions: NSRegularExpression.MatchingOptions = NSRegularExpression.MatchingOptions(rawValue: 0)
        let myRange = NSRange(location:0, length:myText.length)
        
        do {
            let regex = try NSRegularExpression(
                pattern:pattern,
                options:NSRegularExpression.Options.caseInsensitive)
            
            NSLog("Using regex: \(pattern)")
            
            regex.enumerateMatches(
                in: myText as String,
                options:myMatchOptions,
                range:myRange,
                using:{
                    (match: NSTextCheckingResult?, flags: NSRegularExpression.MatchingFlags, stop: UnsafeMutablePointer<ObjCBool>) in
                    if let thisMatch = match {
                        let matchString = myText.substring(with: thisMatch.rangeAt(field))
                        NSLog("Found match - \(matchString)")
                        resultString = matchString
                    }
            });
            
            return resultString
        }
            
        catch {
            NSLog("Error in regex: ")
            return nil
        }
    }
    
    func toDictionary( ) -> Dictionary<String, String> {
        var retDictionary: Dictionary<String, String> = [:]
        
        
        for event in eventsWithCallData {
            if event.eventTitle != nil {
                retDictionary[event.eventTitle!] = event.dialString
            }
        }
        
        return retDictionary
    }
    func fromDictonary(_ inDictionary: Dictionary<String, String>) {
        var index = 0
        var myEventsWithCallData: [CallData] = []
        for event in inDictionary {
            let thisCallData = CallData(withString: event.value, withTitle: event.key)
            myEventsWithCallData.append(thisCallData)
            index += 1
        }
        eventsWithCallData = myEventsWithCallData
    }
}








