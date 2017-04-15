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
    @IBOutlet var dateButton: UIButton!
    @IBOutlet var doneButton: UIButton!
    @IBOutlet var conflictList: UITableView!
    @IBOutlet weak var datePicker: UIDatePicker!

    var myDialer: ConferenceDial = ConferenceDial()
    let mySynthesizer = AVSpeechSynthesizer()
    
    struct CallData {
        var dialString: String?
        var eventTitle: String?
    }
    
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
        NSLog("Appearing")
        super.viewDidAppear(animated)
        self.reload();
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
            self.myDialer.dialPhone(self.myDialer.eventsWithCallData[0].dialString, eventTitle: self.myDialer.eventsWithCallData[0].eventTitle)
        } else {
            // UI updates on main thread
            DispatchQueue.main.async(execute: {
                self.conflictList.isHidden = false
                self.conflictList.reloadData()
            })
            let myTestUtterance = AVSpeechUtterance(string: "\(myDialer.eventsWithCallData.count) events")
            self.mySynthesizer.speak(myTestUtterance)
        }
    }

    
    @IBAction
    func handleAgainButton(_ button: UIButton) {
        
        // XXX would be nice to animate fade
        self.mainLabel.isHidden = false
        self.mainButton.isHidden = true
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
        self.myDialer.dialPhone(myDialer.eventsWithCallData[(indexPath as NSIndexPath).row].dialString, eventTitle: myDialer.eventsWithCallData[(indexPath as NSIndexPath).row].eventTitle)
    }
}








