//
//  ViewController.swift
//  Hibeacons-swift
//
//  Created by user on 15/2/1.
//  Copyright (c) 2015年 yzlpie. All rights reserved.
//

import UIKit
import CoreLocation
import CoreBluetooth

class ViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, CLLocationManagerDelegate, CBPeripheralManagerDelegate, UIAlertViewDelegate {
    
    @IBOutlet weak var beaconTableView: UITableView!
    
    let kUUID = "b9407f30-f5f8-466e-aff9-25556b57fe6d"
    let kIdentifier = "com.yzlpie"
    
    let kOperationCellIdentifier = "OperationCell"
    let kBeaconCellIdentifier = "BeaconCell"
    
    let kMonitoringOperationTitle = "Monitoring"
    let kAdvertisingOperationTitle = "Advertising"
    let kRangingOperationTitle = "Ranging"
    
    let kNumberOfSections = 2
    let kNumberOfAvailableOperations = 3
    let kOperationCellHeight = 44
    let kBeaconCellHeight = 52
    let kBeaconSectionTitle = "Looking for beacons..."
    let kActivityIndicatorPosition = CGPoint(x: 205, y: 12)
    let kBeaconsHeaderViewIdentifier = "BeaconsHeader"
    
    let kMonitoringOperationContext = "kMonitoringOperationContext"
    let kRangingOperationContext = "kRangingOperationContext"
    
    var locationManager:CLLocationManager?
    var beaconRegion:CLBeaconRegion?
    var peripheralManager:CBPeripheralManager?
    var detectedBeacons:NSArray?
    var monitoringSwitch:UISwitch?
    var advertisingSwitch:UISwitch?
    var rangingSwitch:UISwitch?
    var operationContext:String?

    enum NTSectionType:Int {
        case NTOperationsSection
        case NTDetectedBeaconsSection
    }
    
    enum NTOperationsRow:Int {
        case NTMonitoringRow
        case NTAdvertisingRow
        case NTRangingRow
    }
    
    //MARK: - Index path management
    func indexPathsOfRemovedBeacons(beacons:NSArray) -> NSArray? {
        var indexPaths:NSMutableArray?
        var row:Int = 0
        for existingBeacon in self.detectedBeacons! {
            var stillExists = false
            for beacon in beacons {
                if (existingBeacon as CLBeacon).major.integerValue == (beacon as CLBeacon).major.integerValue && (existingBeacon as CLBeacon).minor.integerValue == (beacon as CLBeacon).minor.integerValue {
                    stillExists = true
                    break
                }
            }
            if !stillExists {
                if indexPaths == nil {
                    indexPaths = NSMutableArray()
                }
                indexPaths?.addObject(NSIndexPath(forRow: row, inSection: NTSectionType.NTDetectedBeaconsSection.rawValue))
            }
            row++
        }
        return indexPaths
    }
    
    func indexPathsOfInsertedBeacons(beacons:NSArray) -> NSArray? {
        var indexPaths:NSMutableArray?
        var row:Int = 0
        for beacon in beacons {
            var isNewBeacon = true
            for existingBeacon in self.detectedBeacons! {
                if (existingBeacon as CLBeacon).major.integerValue == (beacon as CLBeacon).major.integerValue && (existingBeacon as CLBeacon).minor.integerValue == (beacon as CLBeacon).minor.integerValue {
                    isNewBeacon = false
                    break
                }
            }
            if isNewBeacon {
                if indexPaths == nil {
                    indexPaths = NSMutableArray()
                }
                indexPaths?.addObject(NSIndexPath(forRow: row, inSection: NTSectionType.NTDetectedBeaconsSection.rawValue))
            }
            row++
        }
        return indexPaths
    }
    
    func indexPathsForBeacons(beacons:NSArray) -> NSArray {
        var indexPaths:NSMutableArray = NSMutableArray()
        for row in 0...(beacons.count - 1) {
            indexPaths.addObject(NSIndexPath(forRow: row, inSection: NTSectionType.NTDetectedBeaconsSection.rawValue))
        }
        return indexPaths
    }
    
    func insertedSections() -> NSIndexSet? {
        if self.rangingSwitch?.on == true && self.beaconTableView.numberOfSections() == kNumberOfSections - 1 {
            return NSIndexSet(index: 1)
        } else {
            return nil
        }
    }
    
    func deletedSections() -> NSIndexSet? {
        if self.rangingSwitch?.on == false && self.beaconTableView.numberOfSections() == kNumberOfSections {
            return NSIndexSet(index: 1)
        } else {
            return nil
        }
    }
    
    func filteredBeacons(beacons:NSArray) -> NSArray {
        var mutableBeacons:NSMutableArray = beacons.mutableCopy() as NSMutableArray
        let lookup:NSMutableSet = NSMutableSet()
        for index in 0...(beacons.count - 1) {
            let curr: CLBeacon = beacons.objectAtIndex(index) as CLBeacon
            let identifier = "\(curr.major)/\(curr.minor)"
            if lookup.containsObject(identifier) {
                mutableBeacons.removeObjectAtIndex(index)
            } else {
                lookup.addObject(identifier)
            }
        }
        return mutableBeacons.copy() as NSArray
    }
    
    
    //MARK: - Table view functionality
    
    func detailsStringForBeacon(beacon:CLBeacon) -> NSString {
        var proximity:NSString?
        switch beacon.proximity {
        case CLProximity.Near:
            proximity = "Near"
        case CLProximity.Immediate:
            proximity = "Immediate"
        case CLProximity.Far:
            proximity = "Far"
        case CLProximity.Unknown:
            proximity = "Unknown"
        default:
            proximity = "Unknown"
        }
        return NSString(string: "\(beacon.major)_\(beacon.minor) • \(proximity!) • \(beacon.accuracy) • \(beacon.rssi)")
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case NTSectionType.NTOperationsSection.rawValue:
            return kNumberOfAvailableOperations
        case NTSectionType.NTDetectedBeaconsSection.rawValue:
            return self.detectedBeacons!.count
        default:
            return self.detectedBeacons!.count
        }
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell:UITableViewCell?
        switch indexPath.section {
        case NTSectionType.NTOperationsSection.rawValue:
            cell = tableView.dequeueReusableCellWithIdentifier(kOperationCellIdentifier) as? UITableViewCell
            switch indexPath.row {
            case NTOperationsRow.NTMonitoringRow.rawValue:
                cell?.textLabel?.text = kMonitoringOperationTitle
                self.monitoringSwitch = cell?.accessoryView as? UISwitch
                self.monitoringSwitch?.addTarget(self, action: "changeMonitoringState:", forControlEvents: UIControlEvents.TouchUpInside)
            case NTOperationsRow.NTAdvertisingRow.rawValue:
                cell?.textLabel?.text = kAdvertisingOperationTitle
                self.advertisingSwitch = cell?.accessoryView as? UISwitch
                self.advertisingSwitch?.addTarget(self, action: "changeAdvertisingState:", forControlEvents: UIControlEvents.ValueChanged)
            case NTOperationsRow.NTRangingRow.rawValue:
                cell?.textLabel?.text = kRangingOperationTitle
                self.rangingSwitch = cell?.accessoryView as? UISwitch
                self.rangingSwitch?.addTarget(self, action: "changeRangingState:", forControlEvents: UIControlEvents.ValueChanged)
            default:
                cell?.textLabel?.text = kRangingOperationTitle
                self.rangingSwitch = cell?.accessoryView as? UISwitch
                self.rangingSwitch?.addTarget(self, action: "changeRangingState:", forControlEvents: UIControlEvents.ValueChanged)
            }
        case NTSectionType.NTDetectedBeaconsSection.rawValue:
            let beacon = self.detectedBeacons![indexPath.row] as? CLBeacon
            cell = tableView.dequeueReusableCellWithIdentifier(kBeaconCellIdentifier) as? UITableViewCell
            if cell == nil {
                cell = UITableViewCell(style: UITableViewCellStyle.Subtitle, reuseIdentifier: kBeaconCellIdentifier)
                cell?.textLabel?.text = beacon?.proximityUUID.UUIDString
                cell?.detailTextLabel?.text = self.detailsStringForBeacon(beacon!)
                cell?.detailTextLabel?.textColor = UIColor.grayColor()
            }
        default:
            let beacon = self.detectedBeacons![indexPath.row] as? CLBeacon
            cell = tableView.dequeueReusableCellWithIdentifier(kBeaconCellIdentifier) as? UITableViewCell
            if cell == nil {
                cell = UITableViewCell(style: UITableViewCellStyle.Subtitle, reuseIdentifier: kBeaconCellIdentifier)
                cell?.textLabel?.text = beacon?.proximityUUID.UUIDString
                cell?.detailTextLabel?.text = self.detailsStringForBeacon(beacon!)
                cell?.detailTextLabel?.textColor = UIColor.grayColor()
            }
        }
        return cell!
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        if self.rangingSwitch?.on == true {
            return kNumberOfSections
        } else {
            return kNumberOfSections - 1
        }
    }
    
    func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case NTSectionType.NTOperationsSection.rawValue:
            return nil
        case NTSectionType.NTDetectedBeaconsSection.rawValue:
            return kBeaconSectionTitle
        default:
            return kBeaconSectionTitle
        }
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        switch indexPath.section {
        case NTSectionType.NTOperationsSection.rawValue:
            return CGFloat(kOperationCellHeight)
        case NTSectionType.NTDetectedBeaconsSection.rawValue:
            return CGFloat(kBeaconCellHeight)
        default:
            return CGFloat(kBeaconCellHeight)
        }
    }
    
    func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = UITableViewHeaderFooterView(reuseIdentifier: kBeaconsHeaderViewIdentifier)
        let indicatorView = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.Gray)
        headerView.addSubview(indicatorView)
        indicatorView.frame = CGRect(origin: kActivityIndicatorPosition, size: indicatorView.frame.size)
        indicatorView.startAnimating()
        return headerView
    }
    
    
    //MARK: - Common
    
    func createBeaconRegion() {
        if self.beaconRegion != nil {
            return
        }
        let proximityUUID = NSUUID(UUIDString: kUUID)
        NSLog("\(kUUID)")
        self.beaconRegion = CLBeaconRegion(proximityUUID: proximityUUID, identifier: kIdentifier)
        self.beaconRegion?.notifyEntryStateOnDisplay = true
    }
    
    func createLocationManager() {
        if self.locationManager == nil {
            self.locationManager = CLLocationManager()
            self.locationManager?.delegate = self
        }
    }
    
    
    //MARK: - Beacon ranging

    func changeRangingState(sender:UISwitch) {
        if sender.on {
            self.startRangingForBeacons()
        } else {
            self.stopRangingForBeacons()
        }
    }
    
    func startRangingForBeacons() {
        self.operationContext = kRangingOperationContext
        self.createLocationManager()
        self.checkLocationAccessForRanging()
        self.detectedBeacons = NSArray()
        self.turnOnRanging()
    }
    
    func turnOnRanging() {
        NSLog("Turning on ranging...")
        if !CLLocationManager.isRangingAvailable() {
            NSLog("Couldn't turn on ranging: Ranging is not available.")
            self.rangingSwitch?.on = false
            return
        }
        
        if self.locationManager?.rangedRegions.count > 0 {
            NSLog("Didn't turn on ranging: Ranging already on.")
            return
        }
        
        self.createBeaconRegion()
        self.locationManager?.startRangingBeaconsInRegion(self.beaconRegion)
        NSLog("Ranging turned on for region: \(self.beaconRegion!.description).")
    }
    
    func stopRangingForBeacons() {
        if self.locationManager?.rangedRegions.count == 0 {
            NSLog("Didn't turn off ranging: Ranging already off.")
            return
        }
        self.locationManager?.stopRangingBeaconsInRegion(self.beaconRegion)
        let deletedSections = self.deletedSections()
        self.detectedBeacons = NSArray()
        self.beaconTableView.beginUpdates()
        if deletedSections != nil {
            self.beaconTableView.deleteSections(deletedSections!, withRowAnimation: UITableViewRowAnimation.Fade)
        }
        self.beaconTableView.endUpdates()
        NSLog("Turned off ranging.")
    }
    
    
    //MARK: - Beacon region monitoring

    func changeMonitoringState(sender:UISwitch) {
        if sender.on {
            self.startMonitoringForBeacons()
        } else {
            self.stopMonitoringForBeacons()
        }
    }
    
    func startMonitoringForBeacons() {
        self.operationContext = kMonitoringOperationContext
        self.createLocationManager()
        self.checkLocationAccessForMonitoring()
        self.turnOnMonitoring()
    }
    
    func turnOnMonitoring() {
        NSLog("Turning on monitoring...")
        if !CLLocationManager.isMonitoringAvailableForClass(CLBeaconRegion) {
            NSLog("Couldn't turn on region monitoring: Region monitoring is not available for CLBeaconRegion class.")
            self.monitoringSwitch!.on = false
            return
        }
        self.createBeaconRegion()
        self.locationManager?.startMonitoringForRegion(self.beaconRegion)
        NSLog("Monitoring turned on for region: \(self.beaconRegion!.description).")
    }
    
    func stopMonitoringForBeacons() {
        self.locationManager?.stopMonitoringForRegion(self.beaconRegion)
        NSLog("Turned off monitoring")
    }
    
    
    //MARK: - Location manager delegate methods
    
    func locationManager(manager: CLLocationManager!, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        if !CLLocationManager.locationServicesEnabled() {
            if self.operationContext == kMonitoringOperationContext {
                NSLog("Couldn't turn on monitoring: Location services are not enabled.")
                self.monitoringSwitch!.on = false
                return
            } else {
                NSLog("Couldn't turn on ranging: Location services are not enabled.")
                self.rangingSwitch!.on = false
                return
            }
        }
        
        let authorizationStatus = CLLocationManager.authorizationStatus()
        switch authorizationStatus {
        case CLAuthorizationStatus.Authorized:
            if self.operationContext == kMonitoringOperationContext {
                self.monitoringSwitch!.on = true
            } else {
                self.rangingSwitch!.on = true
            }
            return
        case CLAuthorizationStatus.AuthorizedWhenInUse:
            if self.operationContext == kMonitoringOperationContext {
                NSLog("Couldn't turn on monitoring: Required Location Access(Always) missing.")
                self.monitoringSwitch!.on = false
            } else {
                self.rangingSwitch!.on = true
            }
            return
        default:
            if self.operationContext == kMonitoringOperationContext {
                NSLog("Couldn't turn on monitoring: Required Location Access(Always) missing.")
                self.monitoringSwitch!.on = false
                return
            } else {
                NSLog("Couldn't turn on monitoring: Required Location Access(WhenInUse) missing.")
                self.rangingSwitch!.on = false
                return
            }
        }
    }
    
    func locationManager(manager: CLLocationManager!, didRangeBeacons beacons: [AnyObject]!, inRegion region: CLBeaconRegion!) {
        let filteredBeacons = self.filteredBeacons(beacons)
        if filteredBeacons.count == 0 {
            NSLog("No beacons found nearby.")
        } else {
            NSLog("Found \(filteredBeacons.count) beacon(s).")
        }
        let insertedSections = self.insertedSections()
        let deletedSections = self.deletedSections()
        var deletedRows = self.indexPathsOfRemovedBeacons(filteredBeacons)
        var insertedRows = self.indexPathsOfInsertedBeacons(filteredBeacons)
        var reloadedRows:NSArray?
        if deletedRows == nil && insertedRows == nil {
            reloadedRows = self.indexPathsForBeacons(filteredBeacons)
        }
        self.detectedBeacons = filteredBeacons
        self.beaconTableView.beginUpdates()
        if insertedRows != nil {
            self.beaconTableView.insertSections(insertedSections!, withRowAnimation: UITableViewRowAnimation.Fade)
        }
        if deletedRows != nil {
            self.beaconTableView.deleteSections(deletedSections!, withRowAnimation: UITableViewRowAnimation.Fade)
        }
        if insertedRows != nil {
            self.beaconTableView.insertRowsAtIndexPaths(insertedRows!, withRowAnimation: UITableViewRowAnimation.Fade)
        }
        if deletedRows != nil {
            self.beaconTableView.deleteRowsAtIndexPaths(deletedRows!, withRowAnimation: UITableViewRowAnimation.Fade)
        }
        if reloadedRows != nil {
            self.beaconTableView.reloadRowsAtIndexPaths(reloadedRows!, withRowAnimation: UITableViewRowAnimation.None)
        }
        self.beaconTableView.endUpdates()
    }

    func locationManager(manager: CLLocationManager!, didEnterRegion region: CLRegion!) {
        NSLog("Entered region: \(region.description)")
        self.sendLocalNotificationForBeaconRegion(region as CLBeaconRegion)
    }
    
    func locationManager(manager: CLLocationManager!, didExitRegion region: CLRegion!) {
        NSLog("Exited region: \(region.description)")
    }
    
    func locationManager(manager: CLLocationManager!, didDetermineState state: CLRegionState, forRegion region: CLRegion!) {
        var stateString:NSString?
        switch state {
        case CLRegionState.Inside:
            stateString = "inside"
        case CLRegionState.Outside:
            stateString = "outside"
        case CLRegionState.Unknown:
            stateString = "unknown"
        }
        NSLog("State changed to \(stateString) for region \(region).")
    }
    
    
    //MARK: - Local notifications

    func sendLocalNotificationForBeaconRegion(region:CLBeaconRegion) {
        let notification = UILocalNotification()
        notification.alertBody = NSString(string: "Entered beacon region for UUID: \(region.proximityUUID.UUIDString)")
//        notification.alertAction = NSLocalizedString(@"View Details", nil)
        notification.soundName = UILocalNotificationDefaultSoundName
        UIApplication.sharedApplication().presentLocalNotificationNow(notification)
    }
    
    
    //MARK: - Beacon advertising
    
    func changeAdvertisingState(sender:UISwitch) {
        if sender.on {
            self.startAdvertisingBeacon()
        } else {
            self.stopAdvertisingBeacon()
        }
    }
    
    func startAdvertisingBeacon() {
        NSLog("Turning on advertising...")
        self.createBeaconRegion()
        if self.peripheralManager == nil {
            self.peripheralManager = CBPeripheralManager(delegate: self, queue: nil, options: nil)
        }
        self.turnOnAdvertising()
    }
    
    func turnOnAdvertising() {
        if self.peripheralManager?.state != CBPeripheralManagerState.PoweredOn {
            NSLog("Peripheral manager is off.")
            self.advertisingSwitch!.on = false
            return
        }
        let majorAndMinor:UInt16 = UInt16(rand())
        let region = CLBeaconRegion(proximityUUID: self.beaconRegion?.proximityUUID, major: majorAndMinor, minor: majorAndMinor, identifier: self.beaconRegion?.identifier)
        let beaconPeripheralData = region.peripheralDataWithMeasuredPower(nil)
        self.peripheralManager?.startAdvertising(beaconPeripheralData)
        NSLog("Turning on advertising for region: \(region.description).")
    }
    
    func stopAdvertisingBeacon() {
        self.peripheralManager?.stopAdvertising()
        NSLog("Turned off advertising.")
    }
    
    
    //MARK: - Beacon advertising delegate methods
    
    func peripheralManagerDidStartAdvertising(peripheral: CBPeripheralManager!, error: NSError!) {
        if error != nil {
            NSLog("Couldn't turn on advertising: \(error.description)")
            self.advertisingSwitch!.on = false
            return
        }
        if peripheralManager?.isAdvertising != nil {
            NSLog("Turned on advertising.")
            self.advertisingSwitch!.on = true
        }
    }
    
    func peripheralManagerDidUpdateState(peripheral: CBPeripheralManager!) {
        if peripheralManager?.state != CBPeripheralManagerState.PoweredOn {
            NSLog("Peripheral manager is off.")
            self.advertisingSwitch!.on = false
            return
        }
        NSLog("Peripheral manager is on.")
        self.turnOnAdvertising()
    }
    
    
    //MARK: - Location access methods (iOS8/Xcode6)
    
    func checkLocationAccessForRanging() {
        if self.locationManager?.respondsToSelector(Selector("requestWhenInUseAuthorization")) == true {
            self.locationManager?.requestWhenInUseAuthorization()
        }
    }
    
    func checkLocationAccessForMonitoring() {
        if self.locationManager?.respondsToSelector(Selector("requestAlwaysAuthorization")) == true {
            let authorizationStatus = CLLocationManager.authorizationStatus()
            if authorizationStatus == CLAuthorizationStatus.Denied || authorizationStatus == CLAuthorizationStatus.AuthorizedWhenInUse {
                let alert = UIAlertView(title: "Location Access Missing", message: "Required Location Access(Always) missing. Click Settings to update Location Access.", delegate: self, cancelButtonTitle: "Settings", otherButtonTitles: "Cancel", "")
                alert.show()
                self.monitoringSwitch!.on = false
                return
            }
            self.locationManager?.requestAlwaysAuthorization()
        }
    }
    
    
    //MARK: - Alert view delegate methods

    func alertView(alertView: UIAlertView, didDismissWithButtonIndex buttonIndex: Int) {
        if buttonIndex == 0 {
            UIApplication.sharedApplication().openURL(NSURL(string: UIApplicationOpenSettingsURLString)!)
        }
    }
    

}

