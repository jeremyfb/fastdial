//
//  ViewController.swift
//  fastdial
//
//  Created by Brian J Hernacki on 6/5/14.
//  Copyright (c) 2014 Brian J Hernacki. All rights reserved.
//

import UIKit
import EventKit
import Foundation
import Intents
import AVFoundation

class ViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    @IBOutlet var mainLabel: UILabel!
    @IBOutlet var mainButton: UIButton!
    @IBOutlet var conflictList: UITableView!

    var myDialer: ConferenceDial = ConferenceDial()
    let mySynthesizer = AVSpeechSynthesizer()
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        INPreferences.requestSiriAuthorization { (status) in
            NSLog("new status: \(status)")
        }
        
        //test TTS
        let myTestUtterance = AVSpeechUtterance(string: "welcome to fast dial")
        mySynthesizer.speak(myTestUtterance)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let globalConcurrentQueue = DispatchQueue.global(qos: DispatchQoS.QoSClass.default)
        
        globalConcurrentQueue.async(execute: {
            self.myDialer.readCalendar()
            self.handleEventSelection()
        })
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func handleEventSelection() {
        
        if myDialer.eventsWithCallData.count <= 0 {
            // UI updates on main thread
            DispatchQueue.main.async(execute: {
                self.mainLabel.text = "No events found"
                let myTestUtterance = AVSpeechUtterance(string: "no events found")
                self.mySynthesizer.speak(myTestUtterance)
                self.mainButton.isHidden = false})
            return
        }
        
        if myDialer.eventsWithCallData.count == 1 {
            // dial the phone
            self.dialPhone(myDialer.eventsWithCallData[0])
        } else {
            
            let myTestUtterance = AVSpeechUtterance(string: "(\"eventsWithCallData.count) events")
            self.mySynthesizer.speak(myTestUtterance)
            
            // UI updates on main thread
            DispatchQueue.main.async(execute: {
                self.conflictList.isHidden = false
                self.conflictList.reloadData()
            })
        }
    }

    
    @IBAction
    func handleButton(_ button: UIButton) {
        
        // XXX would be nice to animate fade
        self.mainButton.isHidden = true
        
        let globalConcurrentQueue = DispatchQueue.global(qos: DispatchQoS.QoSClass.default)
        
        globalConcurrentQueue.async(execute: {
            self.myDialer.readCalendar()
            self.handleEventSelection()})
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
    }
    
    func dialPhone(_ event: CallData) {
        // dial the phone
        guard let dialURL = URL(string: event.dialString!) else {
            return
        }
        UIApplication.shared.open(dialURL)
        let myTestUtterance = AVSpeechUtterance(string: "Dialing "+myDialer.eventsWithCallData[0].eventTitle!)
        self.mySynthesizer.speak(myTestUtterance)
    }
}








