//
//  ConferenceDial.swift
//  fastdial
//
//  Created by Brian J Hernacki on 3/10/17.
//  Copyright © 2017 Brian J Hernacki. All rights reserved.
//

import UIKit
import EventKit
import Foundation
import Intents


class ConferenceDial {
    
    var eventsWithCallData: [CallData] = []
    
    struct CallData {
        var dialString: String?
        var eventTitle: String?
    }
    
    func readCalendar() {
            let currentEvents = self.getCurrentCalendarEvent()
            self.extractEventData(currentEvents)
    }
    
    
    func getCurrentCalendarEvent() -> [EKEvent]? {
        let store = EKEventStore()
        let eventWindow: TimeInterval = 15*60
        
        // XXX should wait for this to return before proceeding
        store.requestAccess(to: EKEntityType.event, completion:{granted, error in assert(granted); return })
        
        // Create the start/end date components
        let now = Date()
        let startDate = Date(timeInterval:-eventWindow, since:now)
        let endDate = Date(timeInterval:eventWindow, since:now)
        
        // Create the predicate from the event store's instance method
        let predicate = store.predicateForEvents(withStart: startDate, end:endDate, calendars:nil)
        let events = store.events(matching: predicate)
        
        // Fetch all events that match the predicate
        if events.count > 0 {
            
            NSLog("found \(events.count) matching events")
            
            return events
        }
        return nil
    }
    
    func extractEventData(_ events: [EKEvent]?) {
        let maxTitleLength = 15
        let defaultPhoneNumber = "916-356-2663"
        
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
                            dialString += defaultPhoneNumber
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
                    
                    let thisCallData = CallData(dialString:dialString, eventTitle:truncatedTitle)
                    myEventsWithCallData.append(thisCallData)
                }
            }
            
            eventsWithCallData = myEventsWithCallData
        }
        NSLog("Found \(eventsWithCallData.count) events with call data")
    }
    
    func dialPhone(_ dialString: String!, eventTitle: String!) {
        NSLog("dialing [\(dialString)]")
        
        // dial the phone
        let uiapp = UIApplication.shared
        uiapp.open(URL(string: dialString)!)
    }

    
    // regex matching/extraction code
    func extractDialStrings(_ text: String) -> (phoneNumber: String?, codeString: String?) {
        
        var phoneNumber: String?
        var codeString: String = ""
        let regexPatternPhoneNumber = "[\\(\\)\\d]{0,5}[\\s\\.-]{0,1}\\d{3}[\\.-]\\d{4}"
        let regexPatternBridgeID = "Choose bridge (\\d)"
        let regexPatternBridgeCode = "Conference ID: (\\d{6,})"
        
        if let s = extractPatternMatch(text, pattern: regexPatternPhoneNumber, field: 0) {
            phoneNumber = s
            NSLog("number is is [\(phoneNumber)]")
        }
        
        if let s = extractPatternMatch(text, pattern: regexPatternBridgeID, field: 1) {
            codeString += s
        }
        
        if let s = extractPatternMatch(text, pattern: regexPatternBridgeCode, field: 1) {
            codeString += ",,,\(s)"
        }
        
        NSLog("code is [\(codeString)]")
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
                        NSLog("found match - \(matchString)")
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
    
}








