//
//  ViewController.swift
//  TW3000Map
//
//  Created by rlbot on 2020/7/18.
//  Copyright © 2020 WL. All rights reserved.
//

import Cocoa
import MapKit
import CoreLocation


class ViewController: NSViewController, MKMapViewDelegate, NSSearchFieldDelegate {
    
    @IBOutlet var mapView : MKMapView!
    @IBOutlet var searchButton : NSButton!
    @IBOutlet var searchField : NSSearchField!
    
    @IBOutlet var messageView : NSView!
    @IBOutlet var messageLabel : NSTextField!
    @IBOutlet var messageIndicator : NSProgressIndicator!
    
    @IBOutlet var myLocationButton : NSButton!
    @IBOutlet var refreshTimePopUpButton : NSPopUpButton!
    @IBOutlet var placeButton : NSButton!
    
    
    let siteCoordinate = CLLocationCoordinate2D(latitude: 25.046856, longitude: 121.516923) //台北車站
    let siteName = "台北車站"
    let refreshMinutes = [5, 8, 13, 21]
    
    var myLocation = CLLocationCoordinate2D()
    var isMoveToUserLocation = true
    var currentRefreshIntervalMinute = 13
    
    var currentSearchPlace : CLPlacemark?
    var currentSearchPlaceAnnotation : MKPointAnnotation?
    
    var items : Array<PostItem>?
    var postAnnotations = Array<PostAnnotation>()
    
    var lastRefreshDate : Date?
    var checkTimer : Timer?
    
    
    // MARK: - viewLoad
    
    override func viewDidAppear() {
        super.viewDidAppear()
        self.view.window?.title = "振興三倍券郵局地圖"
        
        var frame = self.view.window!.frame
        let initialSize = NSSize(width: 1000, height: 750)
        frame.size = initialSize
        self.view.window?.setFrame(frame, display: true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
        fetchData(showMessage: "下載資料中...")
    }
    
    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    
    // MARK: - Setup
    
    func setup() {
        // setup UI
        setupSearchComponent()
        setupMessageViewComponent()
        setupRefreshTimePopUpButton()
        
        // setup initial Location
        setupMyLocation()
        moveToSiteLocation()
        
        // setup MapView
        mapView.showsUserLocation = true
    }
    
    func setupSearchComponent() {
        // search
        searchButton.title = "搜尋"
        searchField.placeholderString = "搜尋地址"
        
        // place
        placeButton.title = "標記的位置"
        placeButton.alphaValue = 0
    }
    
    func setupMessageViewComponent() {
        // view
        messageView.wantsLayer = true
        messageView.layer?.backgroundColor = NSColor.systemBlue.cgColor
        
        // label
        messageLabel.textColor = NSColor.white
        messageLabel.stringValue = ""
        
        // indicator
        if let filter = CIFilter(name: "CIColorControls") {
            filter.setDefaults()
            filter.setValue(1, forKey: "inputBrightness")
            messageIndicator.contentFilters = [filter]
            stopMessageIndicator()
        }
        
        // hide
        messageView.alphaValue = 0
    }
    
    func setupRefreshTimePopUpButton() {
        // clear
        refreshTimePopUpButton.removeAllItems()
        
        // add item
        for minute in refreshMinutes {
            let str = "每隔 \(minute) 分鐘刷新一次地圖"
            refreshTimePopUpButton.addItem(withTitle: str)
        }
        
        // select item
        if let index = refreshMinutes.firstIndex(of: currentRefreshIntervalMinute) {
            refreshTimePopUpButton.selectItem(at: index)
        }
    }
    
    func setupMyLocation() {
        // initial myLocation
        myLocation.latitude = siteCoordinate.latitude
        myLocation.longitude = siteCoordinate.longitude
        myLocationButton.title = "台北車站"
    }
    
    
    // MARK: - Site Location
    
    func moveToSiteLocation() {
        let viewRegion = MKCoordinateRegion(center: siteCoordinate, latitudinalMeters: 1000, longitudinalMeters: 1000);
        let adjustedRegion = mapView.regionThatFits(viewRegion)
        mapView.setRegion(adjustedRegion, animated: true)
    }
    
    
    // MARK: - MKMapViewDelegate

    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        if let location = userLocation.location {
            DispatchQueue.main.async {
                print("緯度:\(location.coordinate.latitude), 經度: \(location.coordinate.longitude)")
                self.myLocation.latitude = location.coordinate.latitude
                self.myLocation.longitude = location.coordinate.longitude
                
                if self.isMoveToUserLocation == true {
                    self.isMoveToUserLocation = false
                    let viewRegion = MKCoordinateRegion(center: self.myLocation,
                                                        latitudinalMeters: 3000,
                                                        longitudinalMeters: 3000)
                    let adjustedRegion = mapView.regionThatFits(viewRegion)
                    mapView.setRegion(adjustedRegion, animated: true)
                    self.myLocationButton.title = "我的位置"
                }
            }
        }
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation {
            return nil
        }
        
        if annotation.isMember(of: PostAnnotation.self) {
            var annoView = mapView.dequeueReusableAnnotationView(withIdentifier: "postAnnotationView") as? PostAnnotationView
            if annoView == nil {
                annoView = PostAnnotationView(annotation: annotation, reuseIdentifier: "postAnnotationView")
            }
            
            let anno = annotation as! PostAnnotation
            annoView?.image      = anno.image
            annoView?.coordinate = anno.coordinate
            
            weak var weakSelf = self
            annoView?.selectedAction = { coordinate in
                weakSelf?.selectedPostAnnotation(anno, coordinate: coordinate)
            }
            
            if let info = anno.info {
                let attrStr = detailAttributedStringWith(info: info)
                let label = NSTextField(labelWithAttributedString: attrStr)
                
                let labelWidth : CGFloat = 300
                let labelHeight = label.cell!.cellSize(forBounds: NSRect(x: 0, y: 0,
                                                                         width: labelWidth,
                                                                         height: CGFloat(Float.greatestFiniteMagnitude))).height
                
                label.frame = NSRect(x: 0, y: 0,
                                     width: labelWidth,
                                     height: (labelHeight + 10))
            
                annoView?.detailCalloutAccessoryView = label
                annoView?.canShowCallout = true
            }
            
            return annoView
        }
        return nil
    }
    
    // MARK: - detail text
    
    func detailAttributedStringWith(info: PostItem) -> NSAttributedString {
        let total         = "\(info.total ?? "")份"
        let totalStr      = "本日三倍券尚有：\(total)\n"
        
        let storeNmStr    = "分局名稱：\(info.storeNm ?? "")"
        let addrStr       = "門市地址：\(info.addr ?? "")"
        let telStr        = "門市電話：\(info.tel ?? "")"
        
        let busiTimeStr   = "營業時間：\(info.busiTime ?? "")".replacingOccurrences(of: "<br>", with: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        let busiMemoStr   = "營業備註：\(info.busiMemo ?? "")".replacingOccurrences(of: "<br>", with: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        
        let updateTimeStr = "異動時間：\(info.updateTime ?? "")"
        
        let textStr = "\(totalStr)\n\(storeNmStr)\n\(addrStr)\n\(telStr)\n\(busiTimeStr)\n\(busiMemoStr)\n\(updateTimeStr)" as NSString
        let attrStr = NSMutableAttributedString(string: textStr as String)
        let totalFontColor = LevelsColor.fontColorWith(total: Int(info.total ?? "") ?? 0)
        
        attrStr.addAttribute(.font,
                             value: NSFont.systemFont(ofSize: 15),
                             range: NSRange(location: 0, length: textStr.length))
        
        attrStr.addAttribute(.font,
                             value: NSFont.boldSystemFont(ofSize: 21),
                             range: textStr.range(of: totalStr))
        
        attrStr.addAttribute(.foregroundColor,
                             value: totalFontColor,
                             range: textStr.range(of: total))
        
        for title in ["分局名稱：", "門市地址：", "門市電話：", "營業時間：", "營業備註：", "異動時間："] {
            attrStr.addAttribute(.font,
                                 value: NSFont.boldSystemFont(ofSize: 15),
                                 range: textStr.range(of: title))
        }
        
        return attrStr
    }
    
    
    // MARK: - Selected Annotation
    
    func selectedPostAnnotation(_ annotation: PostAnnotation, coordinate: CLLocationCoordinate2D) {
        let moveToCoordinate = CLLocationCoordinate2D(latitude: coordinate.latitude,
                                                      longitude: coordinate.longitude)
        
        let viewRegion = MKCoordinateRegion(center: moveToCoordinate, latitudinalMeters: 700, longitudinalMeters: 700)
        let adjustedRegion = mapView.regionThatFits(viewRegion)
        mapView.setRegion(adjustedRegion, animated: true)
    }
    
    
    // MARK: - Fetch Data
    
    func fetchData(showMessage: String) {
        showMessageView(message: showMessage)
        
        APIHelper.fetchData() { jsonArray in
            self.lastRefreshDate = Date()
            
            if let array = jsonArray {
                //print(array)
                print("\ndata count: \(array.count)")
                self.items = array
                self.showMarkers()
            }
            self.dismissMessageView()
            
            if self.checkTimer == nil {
                self.checkTimerStartUp()
            }
        }
    }
    
    // MARK: - Show Markers in MapView
    
    func postPinImageWith(totalString: String) -> NSImage? {
        let name = LevelsColor.postImageNameWith(total: Int(totalString) ?? 0)
        return NSImage(named: name)
    }
    
    func showMarkers() {
        guard let items = self.items else { return }
        
        var annoArray = Array<PostAnnotation>()
        
        for item in items {
            var latitude : Double = 0
            var longitude : Double = 0
            
            if let latStr = item.latitude {
                let lat = latStr.trimmingCharacters(in: .whitespacesAndNewlines)
                latitude = Double(lat) ?? 0
            }
            if let lngStr = item.longitude{
                let lng = lngStr.trimmingCharacters(in: .whitespacesAndNewlines)
                longitude = Double(lng) ?? 0
            }
            
            if latitude == 0 || longitude == 0 {
                continue
            }
            
            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            let anno = PostAnnotation(coordinate: coordinate)
            anno.image = postPinImageWith(totalString: item.total ?? "")
            anno.info = item
            
            annoArray.append(anno)
        }
        
        // clear Annotations
        mapView.removeAnnotations(postAnnotations)
        postAnnotations.removeAll()
        
        // add Annotations
        postAnnotations.append(contentsOf: annoArray)
        mapView.addAnnotations(postAnnotations)
    }
    
    // MARK: - Timer
    
    func checkTimerStartUp() {
        weak var weakSelf = self
        checkTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { timer in
            print("check time...")
            if weakSelf?.isRefreshMapData() ?? false {
                weakSelf?.fetchData(showMessage: "刷新資料中...")
            }
        }
    }
    
    func isRefreshMapData() -> Bool {
        if let lastDate = lastRefreshDate {
            let timeInterval = Date().timeIntervalSince(lastDate)
            print("time interval : \(timeInterval)")
            if timeInterval >= refreshIntervalSecond() {
                return true
            }
        } else {
            lastRefreshDate = Date()
        }
        return false
    }
    
    func refreshIntervalSecond() -> Double {
        let minute = currentRefreshIntervalMinute
        return Double(minute * 60)
    }
    
    
    // MARK: - IBAction
    
    @IBAction func pressedMyLocationButton(sender: NSButton) {
        mapView.setCenter(myLocation, animated: true)
    }
    
    @IBAction func pressedRefreshTimePopUpButton(sender: NSPopUpButton) {
        print("\(sender.titleOfSelectedItem ?? "") : \(sender.indexOfSelectedItem)")
        if sender.indexOfSelectedItem < refreshMinutes.count {
            currentRefreshIntervalMinute = refreshMinutes[sender.indexOfSelectedItem]
        }
    }
    
    @IBAction func pressedSearchButton(sender: NSButton) {
        searchPlace()
    }
    
    @IBAction func pressedPlaceButton(sender: NSButton) {
        if let place = currentSearchPlace, place.location != nil, currentSearchPlaceAnnotation != nil {
            let coordinate = CLLocationCoordinate2D(latitude: place.location!.coordinate.latitude,
                                                    longitude: place.location!.coordinate.longitude)
            
            let viewRegion = MKCoordinateRegion(center: coordinate, latitudinalMeters: 1800, longitudinalMeters: 1800);
            let adjustedRegion = mapView.regionThatFits(viewRegion)
            mapView.setRegion(adjustedRegion, animated: true)
            
            mapView.selectAnnotation(currentSearchPlaceAnnotation!, animated: true)
        }
    }
    
    
    // MARK: - Search Place
    
    func searchPlace() {
        let keyword = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: " ", with: "")
        print("search keyword: \(keyword)。")
        
        removeCurrentSearchPlaceAnnotation()
        currentSearchPlace = nil
        placeButton.alphaValue = 0
        
        if keyword == "" {
            return
        }
        
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(keyword, in: nil, preferredLocale: nil) { placemarks, error in
            if let err = error {
                print("geocoder error: \(err.localizedDescription)")
                self.showGeocodeErrorAlert(keyword: keyword)
            } else {
                print("Placemarks: \(placemarks ?? [])")
                if let placemark = placemarks?[0] {
                    self.currentSearchPlace = placemark
                    self.moveToPlace()
                }
            }
        }
    }
    
    func moveToPlace() {
        if let place = currentSearchPlace, place.location != nil {
            let name = place.name ?? ""
            let country = place.country ?? ""
            let administrativeArea = place.administrativeArea ?? ""
            let subAdministrativeArea = place.subAdministrativeArea ?? ""
            let locality = place.locality ?? ""
            let subLocality = place.subLocality ?? ""
            let thoroughfare = place.thoroughfare ?? ""
            let subThoroughfare = place.subThoroughfare ?? ""
            
            print("name: \(name)")
            print("country: \(country)")
            print("administrativeArea: \(administrativeArea)")
            print("subAdministrativeArea: \(subAdministrativeArea)")
            print("locality: \(locality)")
            print("subLocality: \(subLocality)")
            print("thoroughfare: \(thoroughfare)")
            print("subThoroughfare: \(subThoroughfare)")
            
            let coordinate = CLLocationCoordinate2D(latitude: place.location!.coordinate.latitude,
                                                    longitude: place.location!.coordinate.longitude)
            
            let viewRegion = MKCoordinateRegion(center: coordinate, latitudinalMeters: 2000, longitudinalMeters: 2000);
            let adjustedRegion = mapView.regionThatFits(viewRegion)
            mapView.setRegion(adjustedRegion, animated: true)
            
            let anno = MKPointAnnotation()
            anno.coordinate = coordinate
            anno.title = "\(name)"
            anno.subtitle = "\(country)\(administrativeArea)\(subAdministrativeArea)\(locality)\(subLocality)\(thoroughfare)\(subThoroughfare)"
            
            mapView.addAnnotation(anno)
            mapView.selectAnnotation(anno, animated: true)
            
            currentSearchPlaceAnnotation = anno
            placeButton.alphaValue = 1
        }
    }
    
    func removeCurrentSearchPlaceAnnotation() {
        if let annotation = currentSearchPlaceAnnotation {
            mapView.removeAnnotation(annotation)
            currentSearchPlaceAnnotation = nil
        }
    }
    
    func showGeocodeErrorAlert(keyword: String) {
        let alert = NSAlert()
        alert.addButton(withTitle: "OK")
        alert.messageText = "搜尋失敗"
        alert.informativeText = "搜尋的地址：\(keyword)"
        alert.alertStyle = .warning
        
        alert.beginSheetModal(for: self.view.window!, completionHandler: { modalResponse in
            print("modalResponse: \(modalResponse)")
        })
    }
    
    
    // MARK: - NSSearchFieldDelegate / NSTextFieldDelegate
    
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if (commandSelector == #selector(NSResponder.insertNewline(_:))) {
            // Do something against ENTER key
            print("<ENTER>")
            if control == searchField {
                searchPlace()
            }
            return true
        }
        
        /*
        if (commandSelector == #selector(NSResponder.deleteForward(_:))) {
            // Do something against DELETE key
            print("<DELETE>")
            return true
        }
        if (commandSelector == #selector(NSResponder.deleteBackward(_:))) {
            // Do something against BACKSPACE key
            print("<BACK>")
            return true
        }
        if (commandSelector == #selector(NSResponder.insertTab(_:))) {
            // Do something against TAB key
            print("<TAB>")
            return true
        }
        if (commandSelector == #selector(NSResponder.cancelOperation(_:))) {
            // Do something against ESCAPE key
            print("<ESC>")
            return true
        }*/

        return false
    }
    
    
    // MARK: - MessageView / Indicator
    
    func startMessageIndicator() {
        messageIndicator.startAnimation(nil)
        messageIndicator.alphaValue = 1
    }
    
    func stopMessageIndicator() {
        messageIndicator.stopAnimation(nil)
        messageIndicator.alphaValue = 0
    }
    
    func showMessageView(message: String) {
        messageLabel.stringValue = message
        startMessageIndicator()
        messageView.alphaValue = 1
    }
    
    func dismissMessageView() {
        NSAnimationContext.runAnimationGroup({ _ in
            NSAnimationContext.current.duration = 0.25
            self.messageView.animator().alphaValue = 0
        }, completionHandler: {
            //done
            self.messageLabel.stringValue = ""
            self.stopMessageIndicator()
        })
    }
    
}

