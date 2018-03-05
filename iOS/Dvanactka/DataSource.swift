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
    init?(fromAppDefJson json: [String: AnyObject]) {
        // required values
        if let val = json["id"] as? String { m_sId = val; } else { return nil; }
        if let val = AppDefinition.shared.loadLocalizedString(key: "title", from: json) { m_sTitle = val; } else { return nil; }
        if let val = AppDefinition.shared.loadLocalizedString(key: "icon", from: json) { m_sIcon = val; } else { return nil; }
        if let sType = json["type"] as? String,
            let eType = DataType(rawValue: sType) { m_eType = eType;} else { return nil; }
        
        m_iBackgroundColor = 0xCCCCCC;
        if let val = json["backgroundColor"] as? String {
            var sColorHex = val;
            if sColorHex.hasPrefix("#") {
                sColorHex.remove(at: sColorHex.startIndex);
            }
            if sColorHex.count == 6 {
                if let cl = Int(sColorHex, radix: 16) {
                    m_iBackgroundColor = ((cl & 0xFF0000) >> 16) + (cl & 0xFF00) + ((cl & 0xFF) << 16);
                }
            }
        }

        m_bMapEnabled = (m_eType == .places);
        m_bListingFooterVisible = (m_eType == .places);

        // optional values
        if let val = AppDefinition.shared.loadLocalizedString(key: "shortTitle", from: json) { m_sShortTitle = val; }
        if let val = AppDefinition.shared.loadLocalizedString(key: "serverDataFile", from: json) { m_sServerDataFile = val; }
        if let val = AppDefinition.shared.loadLocalizedString(key: "offlineDataFile", from: json) { m_sOfflineDataFile = val; }
        if let val = json["refreshFreqHours"] as? Int { m_nRefreshFreqHours = val; }
        if let val = json["filterAsParentView"] as? Bool { m_bFilterAsParentView = val; }
        if let val = json["mapEnabled"] as? Bool { m_bMapEnabled = val; }
        if let val = json["listingShowEventAddress"] as? Bool { m_bListingShowEventAddress = val; }
        if let val = json["listingSearchBarVisibleAtStart"] as? Bool { m_bListingSearchBarVisibleAtStart = val; }
        if let val = AppDefinition.shared.loadLocalizedString(key: "listingFooterCustomLabelText", from: json) {
            m_sListingFooterCustomLabelText = val;
        }
        if let val = AppDefinition.shared.loadLocalizedString(key: "listingFooterCustomButtonText", from: json) {
            m_sListingFooterCustomButtonText = val;
        }
        if let val = AppDefinition.shared.loadLocalizedString(key: "listingFooterCustomButtonTargetUrl", from: json) {
            m_sListingFooterCustomButtonTargetUrl = val;
        }

        super.init();
    }
    
    //--------------------------------------------------------------------------
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
    
    static let sharedInstance = CRxDataSourceManager()  // singleton
    
    static let dsRadNews = "dsRadNews";
    static let dsRadEvents = "dsRadEvents";
    static let dsRadDeska = "dsRadDeska";
    static let dsCityOffice = "dsCityOffice";
    static let dsBiografProgram = "dsBiografProgram";
    static let dsCooltour = "dsCooltour";
    static let dsSosContacts = "dsSosContacts";
    static let dsWaste = "dsWaste";
    static let dsShops = "dsShops";
    static let dsWork = "dsWork";
    static let dsSpolky = "dsSpolky";
    static let dsSpolkyList = "dsSpolkyList";
    static let dsReportFault = "dsReportFault";
    static let dsGame = "dsGame";
    static let dsTraffic = "dsTraffic";
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
    func defineDatasources() {
        m_dictDataSources[CRxDataSourceManager.dsRadNews] = CRxDataSource(id: CRxDataSourceManager.dsRadNews, title: NSLocalizedString("News", comment: ""), icon: "ds_news", type: .news, backgroundColor:0x3f4d88);
        m_dictDataSources[CRxDataSourceManager.dsRadEvents] = CRxDataSource(id: CRxDataSourceManager.dsRadEvents, title: NSLocalizedString("Events", comment: ""), icon: "ds_events", type: .events, backgroundColor:0xdb552d);
        m_dictDataSources[CRxDataSourceManager.dsRadDeska] = CRxDataSource(id: CRxDataSourceManager.dsRadDeska, title: NSLocalizedString("Official Board", comment: ""), icon: "ds_billboard", type: .news, backgroundColor:0x3f4d88);
        m_dictDataSources[CRxDataSourceManager.dsSpolky] = CRxDataSource(id: CRxDataSourceManager.dsSpolky, title: NSLocalizedString("Independent", comment: ""), icon: "ds_magazine", type: .news, backgroundColor:0x08739f);
        m_dictDataSources[CRxDataSourceManager.dsSpolkyList] = CRxDataSource(id: CRxDataSourceManager.dsSpolkyList, title: NSLocalizedString("Associations", comment: ""), icon: "ds_usergroups", type: .places, backgroundColor:0x08739f);
        m_dictDataSources[CRxDataSourceManager.dsCityOffice] = CRxDataSource(id: CRxDataSourceManager.dsCityOffice, title: NSLocalizedString("City Office", comment: ""), icon: "ds_parliament", type: .places, backgroundColor:0x3f4d88);
        m_dictDataSources[CRxDataSourceManager.dsBiografProgram] = CRxDataSource(id: CRxDataSourceManager.dsBiografProgram, title: "Modřanský biograf", icon: "ds_biograf", type: .events, backgroundColor:0xdb552d);
        m_dictDataSources[CRxDataSourceManager.dsCooltour] = CRxDataSource(id: CRxDataSourceManager.dsCooltour, title: NSLocalizedString("Trips", comment: ""), icon: "ds_landmarks", type: .places, backgroundColor:0x008000);
        m_dictDataSources[CRxDataSourceManager.dsWaste] = CRxDataSource(id: CRxDataSourceManager.dsWaste, title: NSLocalizedString("Waste", comment: ""), icon: "ds_waste", type: .places, backgroundColor:0x008000);
        m_dictDataSources[CRxDataSourceManager.dsSosContacts] = CRxDataSource(id: CRxDataSourceManager.dsSosContacts, title: NSLocalizedString("Help", comment: ""), icon: "ds_help", type: .places, backgroundColor:0x08739f);
        m_dictDataSources[CRxDataSourceManager.dsReportFault] = CRxDataSource(id: CRxDataSourceManager.dsReportFault, title: NSLocalizedString("Report Fault", comment: ""), icon: "ds_reportfault", type: .places, backgroundColor:0xb11a41);
        m_dictDataSources[CRxDataSourceManager.dsGame] = CRxDataSource(id: CRxDataSourceManager.dsGame, title: NSLocalizedString("Game", comment: ""), icon: "ds_game", type: .places, backgroundColor:0x603cbb);
        m_dictDataSources[CRxDataSourceManager.dsShops] = CRxDataSource(id: CRxDataSourceManager.dsShops, title: NSLocalizedString("Shops", comment: ""), icon: "ds_shop", type: .places, backgroundColor:0x0ab2b2);
        m_dictDataSources[CRxDataSourceManager.dsWork] = CRxDataSource(id: CRxDataSourceManager.dsWork, title: NSLocalizedString("Work", comment: ""), icon: "ds_work", type: .places, backgroundColor:0x0ab2b2);
        m_dictDataSources[CRxDataSourceManager.dsTraffic] = CRxDataSource(id: CRxDataSourceManager.dsTraffic, title: NSLocalizedString("Traffic", comment: ""), icon: "ds_roadblock", type: .places, backgroundColor:0xb11a41);
        
        // additional parameters
        if let ds = m_dictDataSources[CRxDataSourceManager.dsRadNews] {
            ds.m_sServerDataFile = "dyn_radAktual.json";
        }
        if let ds = m_dictDataSources[CRxDataSourceManager.dsRadDeska] {
            ds.m_sServerDataFile = "dyn_radDeska.json";
            ds.m_bFilterable = true;
            ds.m_bListingSearchBarVisibleAtStart = true;
        }
        if let ds = m_dictDataSources[CRxDataSourceManager.dsRadEvents] {
            ds.m_sServerDataFile = "dyn_events.php";
            ds.m_bFilterable = true;
        }
        if let ds = m_dictDataSources[CRxDataSourceManager.dsSpolky] {
            ds.m_sServerDataFile = "dyn_spolky.php";
            ds.m_bFilterable = true;
        }
        if let ds = m_dictDataSources[CRxDataSourceManager.dsSpolkyList] {
            ds.m_nRefreshFreqHours = 48;
            ds.m_sServerDataFile = "spolkyList.json";
            ds.m_sOfflineDataFile = "test_files/spolkyList.json";
        }
        if let ds = m_dictDataSources[CRxDataSourceManager.dsBiografProgram] {
            ds.m_nRefreshFreqHours = 48;
            ds.m_sShortTitle = "Biograf";
            ds.m_sServerDataFile = "dyn_biograf.json";
            ds.m_bListingShowEventAddress = false;
        }
        if let ds = m_dictDataSources[CRxDataSourceManager.dsCooltour] {
            ds.m_nRefreshFreqHours = 48;
            ds.m_sServerDataFile = "p12kultpamatky.json";
            ds.m_sOfflineDataFile = "test_files/p12kultpamatky.json";
        }
        if let ds = m_dictDataSources[CRxDataSourceManager.dsSosContacts] {
            ds.m_nRefreshFreqHours = 48;
            ds.m_sServerDataFile = "sos.json";
            ds.m_sOfflineDataFile = "test_files/sos.json";
        }
        if let ds = m_dictDataSources[CRxDataSourceManager.dsWaste] {
            ds.m_sServerDataFile = "dyn_waste.json";
            ds.m_sOfflineDataFile = "test_files/dyn_waste.json";
            ds.m_bFilterAsParentView = true;
        }
        if let ds = m_dictDataSources[CRxDataSourceManager.dsReportFault] {
            ds.m_nRefreshFreqHours = 1000;
        }
        if let ds = m_dictDataSources[CRxDataSourceManager.dsGame] {
            ds.m_nRefreshFreqHours = 1000;
        }
        if let ds = m_dictDataSources[CRxDataSourceManager.dsShops] {
            ds.m_nRefreshFreqHours = 48;
            ds.m_sServerDataFile = "p12shops.json";
            ds.m_sOfflineDataFile = "test_files/p12shops.json";
            ds.m_bFilterAsParentView = true;
            ds.m_bListingSearchBarVisibleAtStart = true;
        }
        if let ds = m_dictDataSources[CRxDataSourceManager.dsTraffic] {
            ds.m_sServerDataFile = "dyn_doprava.json";
            ds.m_nRefreshFreqHours = 4;
        }
        if let ds = m_dictDataSources[CRxDataSourceManager.dsWork] {
            ds.m_sServerDataFile = "dyn_kdejeprace.json";
            ds.m_sListingFooterCustomLabelText = NSLocalizedString("Add job offer:", comment: "");
            ds.m_sListingFooterCustomButtonText = "KdeJePrace.cz";
            ds.m_sListingFooterCustomButtonTargetUrl = "https://www.kdejeprace.cz/pridat?utm_source=dvanactka.info&utm_medium=app";
        }
        if let ds = m_dictDataSources[CRxDataSourceManager.dsCityOffice] {
            ds.m_nRefreshFreqHours = 100;
            ds.m_sServerDataFile = "dyn_cityOffice.json";
            ds.m_sOfflineDataFile = "test_files/dyn_cityOffice.json";
            ds.m_bFilterAsParentView = true;
            ds.m_bMapEnabled = false;
            ds.m_bListingSearchBarVisibleAtStart = true;
        }
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
        
        guard let ds = m_dictDataSources[CRxDataSourceManager.dsWaste]
            else {return}
        
        // go through all favorite locations and set notifications to future intervals
        let manager = CRxDataSourceManager.sharedInstance;
        let dateNow = Date();
        var arrNewNotifications = [UILocalNotification]();
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
            else {
                urlDownload = URL(string: "https://dvanactka.info/own/p12/" + url);
            }
        }
        else if let sOfflineFile = aDS.m_sOfflineDataFile {
            urlDownload = Bundle.main.url(forResource: sOfflineFile, withExtension: "");
        }
        else {
            return;
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
                if (aDS.m_sId == CRxDataSourceManager.dsWaste) {
                    self.resetAllNotifications();
                }
            }
        }
    }
}
