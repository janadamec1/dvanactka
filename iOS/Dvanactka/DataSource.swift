//
//  DataSource.swift
//  Dvanactka
//
//  Created by Jan Adamec on 07.11.16.
//  Copyright © 2016 Jan Adamec. All rights reserved.
//

import UIKit
import MapKit

private let g_bUseTestFiles = false;

protocol CRxDataSourceRefreshDelegate {
    func dataSourceRefreshEnded(dsId: String, error: String?);
}

class CRxDataSource : NSObject {
    var m_sId: String;
    var m_sTitle: String;           // human readable
    var m_sShortTitle: String?;     // used on main screen, optional
    var m_sIcon: String;
    var m_iBackgroundColor: Int;
    var m_nRefreshFreqHours: Int = 18;  // refresh after 18 hours
    var m_sServerDataFile: String?;     // url where to get the current data
    var m_sOfflineDataFile: String?;    // offline data file
    var m_sLastItemShown: String = "";  // hash of the last record user displayed (to count unread news, etc)
    var m_sUuid: String?;               // id used in game data source
    var m_dateLastRefreshed: Date?;
    var m_bIsBeingRefreshed: Bool = false;
    var m_arrItems: [CRxEventRecord] = [CRxEventRecord]();   // the data
    var delegate: CRxDataSourceRefreshDelegate?;
    
    enum DataType: String {
        case events
        case news
        case places
    }
    var m_eType: DataType;
    var m_bGroupByCategory = true;      // UI should show sections for each category
    var m_bFilterAsParentView = false;  // UI should first show the list of possible filters
    var m_bFilterable = false;          // UI can filter this DataSource according to records' m_sFilter
    var m_setFilter: Set<String>?;      // contains strings that should NOT be shown
    var m_bMapEnabled = false;          // UI can display records on map (enabled for .places)
    var m_bListingFooterVisible = true;        // UI should show footer (enabled for .places)
    var m_bListingSearchBarVisibleAtStart = false;      // start listing with search bar visible
    var m_sListingFooterCustomLabelText: String?;       // use custom listing footer label text
    var m_sListingFooterCustomButtonText: String?;      // use custom listing footer button text
    var m_sListingFooterCustomButtonTargetUrl: String?; // when nil, apps sends email
    var m_bListingShowEventAddress = true;              // show event address in listing
    var m_bLocalNotificationsForEvents = false;         // send local notifications for events in records (dsWaste)
    
    //--------------------------------------------------------------------------
    // this constructor is no longer used
    init(id: String, title: String, icon: String, type: DataType, backgroundColor: Int) {
        m_sId = id;
        m_sTitle = title;
        m_sIcon = icon;
        m_eType = type;
        m_iBackgroundColor = backgroundColor;
        m_bMapEnabled = (m_eType == .places);
        m_bListingFooterVisible = (m_eType == .places);
        super.init();
    }
    
    //--------------------------------------------------------------------------
    // reading dataSource definition from appDefinition.json
    init?(fromAppDefJson json: [String: AnyObject]) {
        // required values
        if let val = json["id"] as? String { m_sId = val; } else { return nil; }
        if let val = CRxAppDefinition.shared.loadLocalizedString(key: "title", from: json) { m_sTitle = val; } else { return nil; }
        if let val = CRxAppDefinition.shared.loadLocalizedString(key: "icon", from: json) { m_sIcon = val; } else { return nil; }
        if let sType = json["type"] as? String,
            let eType = DataType(rawValue: sType) { m_eType = eType;} else { return nil; }
        
        if let cl = CRxAppDefinition.loadColor(key: "backgroundColor", from: json) { m_iBackgroundColor = cl; } else { m_iBackgroundColor = 0xCCCCCC; }

        m_bMapEnabled = (m_eType == .places);
        m_bListingFooterVisible = (m_eType == .places);

        // optional values
        if let val = CRxAppDefinition.shared.loadLocalizedString(key: "shortTitle", from: json) { m_sShortTitle = val; }
        if let val = CRxAppDefinition.shared.loadLocalizedString(key: "serverDataFile", from: json) { m_sServerDataFile = val; }
        if let val = CRxAppDefinition.shared.loadLocalizedString(key: "offlineDataFile", from: json) { m_sOfflineDataFile = val; }
        if let val = json["refreshFreqHours"] as? Int { m_nRefreshFreqHours = val; }
        if let val = json["filterable"] as? Bool { m_bFilterable = val; }
        if let val = json["filterAsParentView"] as? Bool { m_bFilterAsParentView = val; }
        if let val = json["mapEnabled"] as? Bool { m_bMapEnabled = val; }
        if let val = json["listingShowEventAddress"] as? Bool { m_bListingShowEventAddress = val; }
        if let val = json["listingSearchBarVisibleAtStart"] as? Bool { m_bListingSearchBarVisibleAtStart = val; }
        if let val = CRxAppDefinition.shared.loadLocalizedString(key: "listingFooterCustomLabelText", from: json) {
            m_sListingFooterCustomLabelText = val;
        }
        if let val = CRxAppDefinition.shared.loadLocalizedString(key: "listingFooterCustomButtonText", from: json) {
            m_sListingFooterCustomButtonText = val;
        }
        if let val = CRxAppDefinition.shared.loadLocalizedString(key: "listingFooterCustomButtonTargetUrl", from: json) {
            m_sListingFooterCustomButtonTargetUrl = val;
        }
        if let val = json["localNotificationsForEvents"] as? Bool { m_bLocalNotificationsForEvents = val; }

        super.init();
    }
    
    //--------------------------------------------------------------------------
    // load dataSource contents from json in file
    func loadFromJSON(file: URL) {
        var jsonData: Data?
        do {
            let jsonString = try String(contentsOf: file, encoding: .utf8);
            jsonData = jsonString.data(using: String.Encoding.utf8);
        } catch let error as NSError {
            print("JSON opening failed: \(error.localizedDescription)"); return;
        }
        if let data = jsonData {
            loadFromJSON(data: data);
        }
    }
    
    //--------------------------------------------------------------------------
    // load dataSource contents from json data
    func loadFromJSON(data: Data) {
        // decode JSON
        var json: AnyObject
        do {
            json = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions()) as AnyObject
        } catch let error as NSError {
            print("JSON parsing failed: \(error.localizedDescription)"); return;
        }
        
        // load data
        if let jsonItems = json["items"] as? [[String : AnyObject]] {
            m_arrItems.removeAll(); // remove old items
            for item in jsonItems {
                if let aNewRecord = CRxEventRecord(from: item) {
                    m_arrItems.append(aNewRecord);
                }
                
            }
        }
        
        // load config
        if let config = json["config"] as? [String : AnyObject] {
            if let date = config["dateLastRefreshed"] as? String { m_dateLastRefreshed = CRxEventRecord.loadDate(string: date); }
            if let lastItemShown = config["lastItemShown"] as? String { m_sLastItemShown = lastItemShown; }
            if let filter = config["filter"] as? String { m_setFilter = Set<String>(filter.components(separatedBy: "|")); }
            if let uuid = config["uuid"] as? String { m_sUuid = uuid; }
        }
    }
    
    //--------------------------------------------------------------------------
    // save dataSource contents to json file
    func saveToJSON(file: URL) {
        // save data
        var jsonItems = [AnyObject]()
        for item in m_arrItems {
            jsonItems.append(item.saveToJSON() as AnyObject);
        }
        
        var json: [String : AnyObject] = ["items" : jsonItems as AnyObject];
        
        // save config
        var config = [String: AnyObject]();
        if let date = m_dateLastRefreshed { config["dateLastRefreshed"] = CRxEventRecord.saveDate(date: date) as AnyObject }
        config["lastItemShown"] = m_sLastItemShown as AnyObject;
        if let filter = m_setFilter { config["filter"] = filter.joined(separator: "|") as AnyObject; }
        if let uuid = m_sUuid { config["uuid"] = uuid as AnyObject; }
        
        if config.count > 0 {
            json["config"] = config as AnyObject;
        }
        
        // encode to JSON
        var jsonData: Data!
        do {
            jsonData = try JSONSerialization.data(withJSONObject: json, options: JSONSerialization.WritingOptions())
            let jsonString = String(data: jsonData, encoding: String.Encoding.utf8)
            try jsonString?.write(to: file, atomically: false, encoding: .utf8)
        } catch let error as NSError {
            print("Array to JSON conversion failed: \(error.localizedDescription)")
        }
    }
    
    //--------------------------------------------------------------------------
    func unreadItemsCount() -> Int {
        if m_eType == .news {
            if m_sLastItemShown.isEmpty {   // never opened
                return m_arrItems.count;
            }
            for i in 0 ..< m_arrItems.count {
                let rec = m_arrItems[i];
                if rec.recordHash() == m_sLastItemShown {
                    return i;
                }
            }
            return m_arrItems.count;    // read too old news item (all are newer)
        }
        return 0;
    }
    
    //--------------------------------------------------------------------------
    func sortNewsByDate() {
        if m_eType == .news {
            m_arrItems = m_arrItems.sorted(by: {$0.m_aDate! > $1.m_aDate! });
        }
    }
}

//--------------------------------------------------------------------------
//--------------------------------------------------------------------------
class CRxDataSourceManager : NSObject {
    var m_dictDataSources = [String: CRxDataSource]()   // dictionary on data sources, id -> source
    
    static let shared = CRxDataSourceManager()  // singleton
    
    static let dsReportFault = "dsReportFault";
    static let dsGame = "dsGame";
    static let dsSavedNews = "dsSavedNews";
    
    var m_nNetworkIndicatorUsageCount: Int = 0;
    var m_urlDocumentsDir: URL
    var m_aSavedNews = CRxDataSource(id: CRxDataSourceManager.dsSavedNews, title: NSLocalizedString("Saved News", comment: ""), icon: "ds_news", type: .news, backgroundColor:0x808080);    // (records over all news sources)
    var m_setPlacesNotified: Set<String> = [];  // (titles)
    var delegate: CRxDataSourceRefreshDelegate? // one global delegate (main viewController)
    
    //--------------------------------------------------------------------------
    // "private" prevents others from using the default '()' initializer for this class (so being singleton)
    private override init() {
        let documentsDirectoryPathString = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!;
        m_urlDocumentsDir = URL(fileURLWithPath: documentsDirectoryPathString);
        super.init();
    }
    
    //--------------------------------------------------------------------------
    func fileForDataSource(id: String) -> URL {
        return m_urlDocumentsDir.appendingPathComponent(id).appendingPathExtension("json");
    }
    
    //--------------------------------------------------------------------------
    func loadData() {
        for itemIt in m_dictDataSources {
            let ds = itemIt.value;
            ds.loadFromJSON(file: fileForDataSource(id: ds.m_sId));
            
            // load test data in case we don't have any previously saved
            if ds.m_arrItems.isEmpty {
                if let sOfflineFile = ds.m_sOfflineDataFile,
                    let url = Bundle.main.url(forResource: sOfflineFile, withExtension: "") {
                    ds.loadFromJSON(file: url);
                }
            }
        }
        loadFavorities();
    }
    
    //--------------------------------------------------------------------------
    func save(dataSource: CRxDataSource) {
        dataSource.saveToJSON(file: fileForDataSource(id: dataSource.m_sId));
    }
    
    //--------------------------------------------------------------------------
    func setFavorite(place: String, set: Bool) {
        let bFound = m_setPlacesNotified.contains(place);
        
        if set && !bFound {
            m_setPlacesNotified.insert(place);
            saveFavorities();
            resetAllNotifications();
        }
        else if !set && bFound {
            m_setPlacesNotified.remove(place);
            saveFavorities();
            resetAllNotifications();
        }
    }
    
    //--------------------------------------------------------------------------
    func findFavorite(news: CRxEventRecord) -> CRxEventRecord? {
        let itemToFind = news.recordHash();
        for rec in m_aSavedNews.m_arrItems {
            if rec.recordHash() == itemToFind {
                return rec;
            }
        }
        return nil;
    }
    
    //--------------------------------------------------------------------------
    func setFavorite(news: CRxEventRecord, set: Bool) {
        var bFound = false;
        var bChanged = false;
        let itemToFind = news.recordHash();
        for i in 0..<m_aSavedNews.m_arrItems.count {
            let rec = m_aSavedNews.m_arrItems[i];
            if rec.recordHash() == itemToFind {
                bFound = true;
                if !set {
                    m_aSavedNews.m_arrItems.remove(at: i);
                    bChanged = true;
                }
                break;
            }
        }
        if set && !bFound {
            m_aSavedNews.m_arrItems.insert(news, at: 0);
            bChanged = true;
        }
        
        if bChanged {
            saveFavorities();
        }
    }
    
    //--------------------------------------------------------------------------
    func saveFavorities() {
        let sList: String = m_setPlacesNotified.joined(separator: "|");
        let urlPlaces = m_urlDocumentsDir.appendingPathComponent("favPlaces.txt");
        do {
            try sList.write(to: urlPlaces, atomically: false, encoding: .utf8)
        } catch let error as NSError {
            print("Saving favorite places failed: \(error.localizedDescription)")
        }
        
        let urlNews = m_urlDocumentsDir.appendingPathComponent("favNews.json");
        m_aSavedNews.saveToJSON(file: urlNews);
    }
    
    //--------------------------------------------------------------------------
    func loadFavorities() {
        let urlPlaces = m_urlDocumentsDir.appendingPathComponent("favPlaces.txt");
        do {
            let sLoaded = try String(contentsOf: urlPlaces, encoding: .utf8);
            m_setPlacesNotified = Set(sLoaded.components(separatedBy: "|").map { $0 });
        } catch let error as NSError {
            print("Loading favorite places failed: \(error.localizedDescription)"); return;
        }
        
        let urlNews = m_urlDocumentsDir.appendingPathComponent("favNews.json");
        m_aSavedNews.loadFromJSON(file: urlNews);
    }
    
    //--------------------------------------------------------------------------
    func resetAllNotifications() {
        // go through all favorite locations and set notifications to future intervals
        let manager = CRxDataSourceManager.shared;
        let dateNow = Date();
        var arrNewNotifications = [UILocalNotification]();

        for itemIt in m_dictDataSources {
            let ds = itemIt.value;
            if !ds.m_bLocalNotificationsForEvents {
                continue;
            }

            for rec in ds.m_arrItems {
                if !manager.m_setPlacesNotified.contains(rec.m_sTitle) {
                    continue;
                }
                guard let events = rec.m_arrEvents else { continue }
                for aEvent in events {
                    if aEvent.m_dateStart > dateNow {
                        
                        var aNotification = UILocalNotification();
                        aNotification.fireDate = aEvent.m_dateStart;
                        aNotification.timeZone = NSTimeZone.default;
                        aNotification.alertBody = String(format: NSLocalizedString("Dumpster at %@ just arrived (%@)", comment:""), arguments: [rec.m_sTitle, aEvent.m_sType]);
                        aNotification.soundName = UILocalNotificationDefaultSoundName;
                        //aNotification.applicationIconBadgeNumber = 1;
                        arrNewNotifications.append(aNotification);
                        
                        // also add a notification one day earlier
                        let dateBefore = aEvent.m_dateStart.addingTimeInterval(-24*60*60);
                        if dateBefore > dateNow {
                            aNotification = UILocalNotification();
                            aNotification.fireDate = dateBefore;
                            aNotification.timeZone = NSTimeZone.default;
                            aNotification.alertBody = String(format: NSLocalizedString("Dumpster at %@ tomorrow (%@)", comment:""), arguments: [rec.m_sTitle, aEvent.m_sType]);
                            aNotification.soundName = UILocalNotificationDefaultSoundName;
                            //aNotification.applicationIconBadgeNumber = 1;
                            arrNewNotifications.append(aNotification);
                        }
                    }
                }
            }
        }
        // set those notifications
        if !arrNewNotifications.isEmpty {
            UIApplication.shared.scheduledLocalNotifications = arrNewNotifications;
        }
        else {
            UIApplication.shared.scheduledLocalNotifications = nil;  // remove all our old notifications
        }
    }
    
    //--------------------------------------------------------------------------
    func showNetworkIndicator() {
        if m_nNetworkIndicatorUsageCount == 0 {
            UIApplication.shared.isNetworkActivityIndicatorVisible = true;
        }
        m_nNetworkIndicatorUsageCount += 1;
    }
    
    //--------------------------------------------------------------------------
    func hideNetworkIndicator() {
        if m_nNetworkIndicatorUsageCount > 0 {
            m_nNetworkIndicatorUsageCount -= 1;
        }
        if m_nNetworkIndicatorUsageCount == 0 {
            UIApplication.shared.isNetworkActivityIndicatorVisible = false;
        }
    }
    
    //--------------------------------------------------------------------------
    func refreshAllDataSources(force: Bool = false) {
        
        // check if WiFi only settings applies
        if !force && UserDefaults.standard.bool(forKey: "wifiDataOnly")
            && !Reachability.isConnectedToNetworkViaWiFi() {
            return;
        }
        
        for dsIt in m_dictDataSources {
            refreshDataSource(id: dsIt.key, force: force);
        }
    }
    
    //--------------------------------------------------------------------------
    func refreshDataSource(id: String, force: Bool) {
        
        guard let ds = m_dictDataSources[id]
            else { return; }
        
        // check the last refresh date
        if !force && ds.m_dateLastRefreshed != nil  &&
            Date().timeIntervalSince(ds.m_dateLastRefreshed!) < Double(ds.m_nRefreshFreqHours*60*60) {
            ds.delegate?.dataSourceRefreshEnded(dsId: id, error: nil);
            return;
        }
        
        if let url = ds.m_sServerDataFile {
            refreshStdJsonDataSource(sDsId: id, url: url);
        }
    }
    
    //--------------------------------------------------------------------------
    // downloading data from URL: http://stackoverflow.com/questions/24231680/loading-downloading-image-from-url-on-swift
    // async
    static func getDataFromUrl(url: URL, completion: @escaping (_ data: Data?, _ response: URLResponse?, _ error: Error?) -> Void) {
        URLSession.shared.dataTask(with: url) {
            (data, response, error) in
            completion(data, response, error)
            }.resume()
    }
    
    //--------------------------------------------------------------------------
    func refreshStdJsonDataSource(sDsId: String, url: String) {
        guard let aDS = self.m_dictDataSources[sDsId]
            else { return }
        
        var urlDownload: URL?
        if !g_bUseTestFiles {
            if (url.hasPrefix("http")) {
                urlDownload = URL(string: url);
            }
            else if let serverUrl = CRxAppDefinition.shared.m_sServerDataBaseUrl {
                urlDownload = URL(string: serverUrl + url);
            }
        }
        else if let sOfflineFile = aDS.m_sOfflineDataFile {
            urlDownload = Bundle.main.url(forResource: sOfflineFile, withExtension: "");
        }
        
        guard let url = urlDownload else { aDS.delegate?.dataSourceRefreshEnded(dsId: sDsId, error: "Cannot resolve URL"); return; }
        
        aDS.m_bIsBeingRefreshed = true;
        showNetworkIndicator();
        
        CRxDataSourceManager.getDataFromUrl(url: url) { (data, response, error) in
            guard let data = data, error == nil
                else {
                    if let error = error {
                        print("URL downloading failed: \(error.localizedDescription)");
                    }
                    DispatchQueue.main.async() { () -> Void in
                        aDS.m_bIsBeingRefreshed = false;
                        aDS.delegate?.dataSourceRefreshEnded(dsId: sDsId, error: "Error when downloading data");
                        self.hideNetworkIndicator();
                    }
                    return;
            }
            
            // process the data
            aDS.loadFromJSON(data: data);
            
            DispatchQueue.main.async() { () -> Void in
                aDS.sortNewsByDate();
                aDS.m_dateLastRefreshed = Date();
                aDS.m_bIsBeingRefreshed = false;
                self.save(dataSource: aDS);
                self.hideNetworkIndicator();
                aDS.delegate?.dataSourceRefreshEnded(dsId: sDsId, error: nil);
                self.delegate?.dataSourceRefreshEnded(dsId: sDsId, error: nil);     // to refresh unread count badge
                if (aDS.m_bLocalNotificationsForEvents) {
                    self.resetAllNotifications();
                }
            }
        }
    }
}
