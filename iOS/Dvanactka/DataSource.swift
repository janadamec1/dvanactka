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
    var m_sId: String
    var m_sTitle: String           // human readable
    var m_sShortTitle: String?
    var m_sIcon: String
    var m_iBackgroundColor: Int;
    var m_nRefreshFreqHours: Int = 18;  // refresh after 18 hours
    var m_sTestJsonFile: String?;       // offline data file
    var m_sLastItemShown: String = "";  // hash of the last record user displayed (to count unread news, etc)
    var m_sUuid: String?;               // id used in game data source
    var m_dateLastRefreshed: Date?
    var m_bIsBeingRefreshed: Bool = false
    var m_arrItems: [CRxEventRecord] = [CRxEventRecord]()   // the data
    var delegate: CRxDataSourceRefreshDelegate?
    
    enum DataType {
        case events
        case news
        case places
    }
    var m_eType: DataType
    var m_bGroupByCategory = true       // UI should show sections for each category
    var m_bFilterAsParentView = false   // UI should first show the list of possible filters
    var m_bFilterable = false           // UI can filter this datasource accoring to records' m_sFilter
    var m_setFilter: Set<String>?       // contains strings that should NOT be shown
    var m_bMapEnabled = false           // UI can display records on map (enabled for .places)
    
    init(id: String, title: String, icon: String, type: DataType, backgroundColor: Int) {
        m_sId = id;
        m_sTitle = title;
        m_sIcon = icon;
        m_eType = type;
        m_iBackgroundColor = backgroundColor;
        m_bMapEnabled = (type == .places);
        super.init()
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
    private override init() {}     // "private" prevents others from using the default '()' initializer for this class (so being singleton)
    
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
    var m_urlDocumentsDir: URL!
    var m_aSavedNews = CRxDataSource(id: CRxDataSourceManager.dsSavedNews, title: NSLocalizedString("Saved News", comment: ""), icon: "ds_news", type: .news, backgroundColor:0x808080);    // (records over all news sources)
    var m_setPlacesNotified: Set<String> = [];  // (titles)
    var delegate: CRxDataSourceRefreshDelegate? // one global delegate (main viewController)

    func defineDatasources() {
        
        let documentsDirectoryPathString = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        m_urlDocumentsDir = URL(fileURLWithPath: documentsDirectoryPathString)
        
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
        if let ds = m_dictDataSources[CRxDataSourceManager.dsRadDeska] {
            ds.m_bFilterable = true;
        }
        if let ds = m_dictDataSources[CRxDataSourceManager.dsRadEvents] {
            ds.m_bFilterable = true;
        }
        if let ds = m_dictDataSources[CRxDataSourceManager.dsSpolky] {
            ds.m_bFilterable = true;
        }
        if let ds = m_dictDataSources[CRxDataSourceManager.dsSpolkyList] {
            ds.m_nRefreshFreqHours = 48;
            ds.m_sTestJsonFile = "/test_files/spolkyList";
        }
        if let ds = m_dictDataSources[CRxDataSourceManager.dsBiografProgram] {
            ds.m_nRefreshFreqHours = 48;
            ds.m_sShortTitle = "Biograf";
        }
        if let ds = m_dictDataSources[CRxDataSourceManager.dsCooltour] {
            ds.m_nRefreshFreqHours = 48;
            ds.m_sTestJsonFile = "/test_files/p12kultpamatky";
        }
        if let ds = m_dictDataSources[CRxDataSourceManager.dsSosContacts] {
            ds.m_nRefreshFreqHours = 48;
            ds.m_sTestJsonFile = "/test_files/sos";
        }
        if let ds = m_dictDataSources[CRxDataSourceManager.dsWaste] {
            ds.m_sTestJsonFile = "/test_files/dyn_waste";
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
            ds.m_sTestJsonFile = "/test_files/p12shops";
            ds.m_bFilterAsParentView = true;
        }
        if let ds = m_dictDataSources[CRxDataSourceManager.dsTraffic] {
            ds.m_nRefreshFreqHours = 4;
        }
        if let ds = m_dictDataSources[CRxDataSourceManager.dsCityOffice] {
            ds.m_nRefreshFreqHours = 100;
            ds.m_sTestJsonFile = "/test_files/dyn_cityOffice";
            ds.m_bFilterAsParentView = true;
            ds.m_bMapEnabled = false;
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
                if let testFile = ds.m_sTestJsonFile,
                    let url = Bundle.main.url(forResource: testFile, withExtension: "json") {
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
        
        if id == CRxDataSourceManager.dsRadNews {
            refreshStdJsonDataSource(sDsId: id, url: "dyn_radAktual.json");
            return;
        }
        else if id == CRxDataSourceManager.dsRadEvents {
            refreshStdJsonDataSource(sDsId: id, url: "dyn_events.php");
            return;
        }
        else if id == CRxDataSourceManager.dsRadDeska {
            refreshStdJsonDataSource(sDsId: id, url: "dyn_radDeska.json");
            return;
        }
        else if id == CRxDataSourceManager.dsCityOffice {
            refreshStdJsonDataSource(sDsId: id, url: "dyn_cityOffice.json");
            return;
        }
        else if id == CRxDataSourceManager.dsWork {
            refreshStdJsonDataSource(sDsId: id, url: "dyn_kdejeprace.json");
            return;
        }
        else if id == CRxDataSourceManager.dsSpolky {
            refreshStdJsonDataSource(sDsId: id, url: "dyn_spolky.php");
            return;
        }
        else if id == CRxDataSourceManager.dsBiografProgram {
            refreshStdJsonDataSource(sDsId: id, url: "dyn_biograf.json");
            return;
        }
        else if id == CRxDataSourceManager.dsTraffic {
            refreshStdJsonDataSource(sDsId: id, url: "dyn_doprava.json");
            return;
        }
        else if id == CRxDataSourceManager.dsSpolkyList {
            refreshStdJsonDataSource(sDsId: id, url: "spolkyList.json");
            return;
        }
        else if id == CRxDataSourceManager.dsCooltour {
            refreshStdJsonDataSource(sDsId: id, url: "p12kultpamatky.json");
            return;
        }
        else if id == CRxDataSourceManager.dsWaste {
            refreshStdJsonDataSource(sDsId: id, url: "dyn_waste.json");
            /*if let path = Bundle.main.url(forResource: "/test_files/vokplaces", withExtension: "json") {
                ds.loadFromJSON(file: path);
                refreshWasteDataSource();
                ds.delegate?.dataSourceRefreshEnded(nil);
                return;
            }*/
        }
        else if id == CRxDataSourceManager.dsSosContacts {
            refreshStdJsonDataSource(sDsId: id, url: "sos.json");
            return;
        }
        else if id == CRxDataSourceManager.dsShops {
            refreshStdJsonDataSource(sDsId: id, url: "p12shops.json");
            return;
        }
    }
    
    //--------------------------------------------------------------------------
    // downloading daa from URL: http://stackoverflow.com/questions/24231680/loading-downloading-image-from-url-on-swift
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
        else if let testFile = aDS.m_sTestJsonFile {
            urlDownload = Bundle.main.url(forResource: testFile, withExtension: "json");
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
    
    /*/--------------------------------------------------------------------------
    func refreshHtmlDataSource(sDsId: String, url: String, testFile: String, completition: ((_ error: String?) -> Void)?, htmlCodeHandler: @escaping (_ doc: HTMLDocument, _ arrNewItems: inout [CRxEventRecord]) -> Void) {
        
        guard let aDS = self.m_dictDataSources[sDsId]
            else { return }
        
        var urlDownload: URL?
        if !g_bUseTestFiles {
            urlDownload = URL(string: url);
        }
        else {
            urlDownload = Bundle.main.url(forResource: testFile, withExtension: "html");
        }
        guard let url = urlDownload else { aDS.delegate?.dataSourceRefreshEnded("Cannot resolve URL"); return; }
        
        aDS.m_bIsBeingRefreshed = true;
        showNetworkIndicator();
        
        getDataFromUrl(url: url) { (data, response, error) in
            guard let data = data, error == nil
                else {
                    DispatchQueue.main.async() { () -> Void in
                        aDS.m_bIsBeingRefreshed = false;
                        completition?(NSLocalizedString("Error when downloading data", comment: ""));
                        self.hideNetworkIndicator();
                    }
                    return;
            }
            
            if let doc = HTML(html:data, encoding: .utf8) {
                
                var arrNewItems = [CRxEventRecord]()
                
                htmlCodeHandler(doc, &arrNewItems);
                
                DispatchQueue.main.async() { () -> Void in
                    if arrNewItems.count > 0 {
                        aDS.m_arrItems = arrNewItems;
                        aDS.sortNewsByDate();
                    }
                    aDS.m_dateLastRefreshed = Date();
                    aDS.m_bIsBeingRefreshed = false;
                    self.save(dataSource: aDS);
                    self.hideNetworkIndicator();
                    aDS.delegate?.dataSourceRefreshEnded(nil);
                    self.delegate?.dataSourceRefreshEnded(nil);     // to refresh unread count badge
                }
            }
        }
    } */
    
    //--------------------------------------------------------------------------
    func findVokLocation(alias: String, ds: CRxDataSource) -> CRxEventRecord? {
        let sAliasCompressed = alias.replacingOccurrences(of: " ", with: "");
        for rec in ds.m_arrItems {
            if let text = rec.m_sText {
                let sTextCompressed = text.replacingOccurrences(of: " ", with: "");
                if sTextCompressed.range(of: sAliasCompressed, options:[.diacriticInsensitive, .caseInsensitive]) != nil {
                    return rec;
                }
            }
        }
        return nil;
    }
    
    func processWasteDataFile(csv: String, type: String, into ds: CRxDataSource) {
        
        var iTimeStartCol = 2;
        var iTimeEndCol = 3;
        var iLocCol = 4;
        var iTypeCol = -1;
        if type == "bio" {
            iTimeStartCol = 1;
            iTimeEndCol = 2;
            iLocCol = 3;
            iTypeCol = 5;
        }
        
        let aCalendar = Calendar.current;
        
        let lines = csv.components(separatedBy: .newlines);
        var nProcessedCount = 0;
        for line in lines {
            let lineItems = line.components(separatedBy: ";");
            if lineItems.count < 5 {
                continue;
            }
            
            if let rec = findVokLocation(alias: lineItems[iLocCol], ds: ds) {
                let sDateComps = lineItems[0].components(separatedBy: ".");
                let sTimeStartComps = lineItems[iTimeStartCol].components(separatedBy: ":")
                let sTimeEndComps = lineItems[iTimeEndCol].components(separatedBy: ":")
                if sDateComps.count != 3 || sTimeStartComps.count != 2 || sTimeEndComps.count != 2 {
                    continue;
                }
                
                var aDateComps = DateComponents();
                aDateComps.day = Int(sDateComps[0]);
                aDateComps.month = Int(sDateComps[1]);
                aDateComps.year = Int(sDateComps[2]);
                
                aDateComps.hour = Int(sTimeStartComps[0]);
                aDateComps.minute = Int(sTimeStartComps[1]);
                
                var dateStart = aCalendar.date(from: aDateComps);
                
                aDateComps.hour = Int(sTimeEndComps[0]);
                aDateComps.minute = Int(sTimeEndComps[1]);
                var dateEnd = aCalendar.date(from: aDateComps);
                
                if lineItems[iTimeStartCol] == "0:00" && lineItems[iTimeEndCol] == "0:00" {
                    // exception, duration is entire weekend
                    aDateComps.hour = 15;
                    dateStart = aCalendar.date(from: aDateComps);
                    aDateComps.hour = 8;
                    dateEnd = aCalendar.date(from: aDateComps)?.addingTimeInterval(3*24*60*60); // add 3 days (weekend)
                }
                
                if let dateStart = dateStart, let dateEnd = dateEnd {
                    // add new record to rec
                    if rec.m_arrEvents == nil {
                        rec.m_arrEvents = [CRxEventInterval]();
                    }
                    
                    var sRecType = type;
                    if iTypeCol >= 0 && iTypeCol < lineItems.count {
                        sRecType = lineItems[iTypeCol]
                    }
                    
                    rec.m_arrEvents?.append(CRxEventInterval(start: dateStart, end: dateEnd, type: sRecType));
                    nProcessedCount += 1;
                }
            }
        }
        print("\(type) lines \(lines.count), processed \(nProcessedCount)");
    }
    
    func refreshWasteDataSource(completition: ((_ error: String?) -> Void)? = nil) {
        
        guard let aVokDS = m_dictDataSources[CRxDataSourceManager.dsWaste]
            else { return }
        
        //if let doc = HTML(url: url!, encoding: .utf8) {
        if let pathVok = Bundle.main.path(forResource: "/test_files/vok_vok", ofType: "csv"),
            let pathBio = Bundle.main.path(forResource: "/test_files/vok_bio", ofType: "csv") {
            
            // remove all events
            for rec in aVokDS.m_arrItems {
                rec.m_arrEvents = nil;
            }
            
            let csvVok = try! String(contentsOfFile: pathVok, encoding: .utf8);
            processWasteDataFile(csv: csvVok, type: "obj. odpad", into: aVokDS);
            
            let csvBio = try! String(contentsOfFile: pathBio, encoding: .utf8);
            processWasteDataFile(csv: csvBio, type: "bio", into: aVokDS);
            
            // sort all events (and fill static info link)
            for rec in aVokDS.m_arrItems {
                if let events = rec.m_arrEvents {
                    rec.m_arrEvents = events.sorted(by: { $0.m_dateStart < $1.m_dateStart });
                }
                if let category = rec.m_eCategory {
                    if category == CRxCategory.waste.rawValue {
                        rec.m_sInfoLink = "https://www.praha12.cz/odpady/ds-1138/";
                    }
                }
            }
            
            aVokDS.m_dateLastRefreshed = Date();
            save(dataSource: aVokDS);
            resetAllNotifications();
        }
    }
}