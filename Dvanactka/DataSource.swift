//
//  DataSource.swift
//  Dvanactka
//
//  Created by Jan Adamec on 07.11.16.
//  Copyright © 2016 Jan Adamec. All rights reserved.
//

import UIKit
import Kanna

private let g_bUseTestFiles = false;

protocol CRxDataSourceRefreshDelegate {
    func dataSourceRefreshEnded(_ error: String?);
}

class CRxDataSource : NSObject {
    var m_sId: String
    var m_sTitle: String           // human readable
    var m_sShortTitle: String?
    var m_sIcon: String
    var m_nRefreshFreqHours: Int = 18   // refresh after 18 hours
    var m_sLastItemShown: String = ""   // hash of the last record user displayed (to count unread news, etc)
    var m_dateLastRefreshed: Date?
    var m_bIsBeingRefreshed: Bool = false
    var m_arrItems: [CRxEventRecord] = [CRxEventRecord]()   // the data
    var delegates = [CRxDataSourceRefreshDelegate]()
    var delegate: CRxDataSourceRefreshDelegate?
    
    enum DataType {
        case events
        case news
        case places
    }
    var m_eType = DataType.news
    
    init(id: String, title: String, icon: String, type: DataType, refreshFreqHours: Int = 18, shortTitle: String? = nil) {
        m_sId = id;
        m_sTitle = title;
        m_sShortTitle = shortTitle;
        m_sIcon = icon;
        m_eType = type;
        m_nRefreshFreqHours = refreshFreqHours;
        super.init()
    }
    
    //--------------------------------------------------------------------------
    func loadFromJSON(file: URL) {
        // decode JSON
        var json: AnyObject
        do {
            let jsonString = try String(contentsOf: file, encoding: .utf8);
            let jsonData = jsonString.data(using: String.Encoding.utf8)!;
            json = try JSONSerialization.jsonObject(with: jsonData, options: JSONSerialization.ReadingOptions()) as AnyObject
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
}

//--------------------------------------------------------------------------
//--------------------------------------------------------------------------
class CRxDataSourceManager : NSObject {
    var m_dictDataSources = [String: CRxDataSource]()   // distionary on data sources, id -> source
    
    static let sharedInstance = CRxDataSourceManager()  // singleton
    private override init() {}     // "private" prevents others from using the default '()' initializer for this class (so being singleton)
    
    static let dsRadNews = "dsRadNews";
    static let dsRadAlerts = "dsRadAlerts";
    static let dsRadEvents = "dsRadEvents";
    static let dsBiografProgram = "dsBiografProgram";
    static let dsCooltour = "dsCooltour";
    static let dsSosContacts = "dsSosContacts";
    static let dsWaste = "dsWaste";
    static let dsSavedNews = "dsSavedNews";
    
    var m_nNetworkIndicatorUsageCount: Int = 0;
    var m_urlDocumentsDir: URL!
    var m_aSavedNews = CRxDataSource(id: CRxDataSourceManager.dsSavedNews, title: NSLocalizedString("Saved News", comment: ""), icon: "ds_news", type: .news);    // (records over all news sources)
    var m_setPlacesNotified: Set<String> = [];  // (titles)
    var delegate: CRxDataSourceRefreshDelegate? // one global delegate (main viewController)

    func defineDatasources() {
        
        let documentsDirectoryPathString = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        m_urlDocumentsDir = URL(fileURLWithPath: documentsDirectoryPathString)
        
        m_dictDataSources[CRxDataSourceManager.dsRadNews] = CRxDataSource(id: CRxDataSourceManager.dsRadNews, title: NSLocalizedString("News", comment: ""), icon: "ds_news", type: .news);
        m_dictDataSources[CRxDataSourceManager.dsRadAlerts] = CRxDataSource(id: CRxDataSourceManager.dsRadAlerts, title: NSLocalizedString("Alerts", comment: ""), icon: "ds_alerts", type: .news);
        m_dictDataSources[CRxDataSourceManager.dsRadEvents] = CRxDataSource(id: CRxDataSourceManager.dsRadEvents, title: NSLocalizedString("Events", comment: ""), icon: "ds_events", type: .events);
        m_dictDataSources[CRxDataSourceManager.dsBiografProgram] = CRxDataSource(id: CRxDataSourceManager.dsBiografProgram, title: "Modřanský biograf", icon: "ds_biograf", type: .events, refreshFreqHours: 60, shortTitle: "Biograf");
        m_dictDataSources[CRxDataSourceManager.dsCooltour] = CRxDataSource(id: CRxDataSourceManager.dsCooltour, title: NSLocalizedString("Landmarks", comment: ""), icon: "ds_landmarks", type: .places, refreshFreqHours: 100);
        m_dictDataSources[CRxDataSourceManager.dsWaste] = CRxDataSource(id: CRxDataSourceManager.dsWaste, title: NSLocalizedString("Waste", comment: ""), icon: "ds_waste", type: .places);
        m_dictDataSources[CRxDataSourceManager.dsSosContacts] = CRxDataSource(id: CRxDataSourceManager.dsSosContacts, title: NSLocalizedString("Help", comment: ""), icon: "ds_help", type: .places, refreshFreqHours: 100);
    }
    
    //--------------------------------------------------------------------------
    func fileForDataSource(id: String) -> URL {
        return m_urlDocumentsDir.appendingPathComponent(id).appendingPathExtension("json");
    }
    
    //--------------------------------------------------------------------------
    func loadData() {
        for itemIt in m_dictDataSources {
            itemIt.value.loadFromJSON(file: fileForDataSource(id: itemIt.value.m_sId));
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
                    aNotification.alertBody = NSLocalizedString("Dumpster at \(rec.m_sTitle) just arrived (\(aEvent.m_sType))", comment:"");
                    aNotification.soundName = UILocalNotificationDefaultSoundName;
                    aNotification.applicationIconBadgeNumber = 1;
                    arrNewNotifications.append(aNotification);
                    
                    // also add a notification one day earlier
                    let dateBefore = aEvent.m_dateStart.addingTimeInterval(-24*60*60);
                    if dateBefore > dateNow {
                        aNotification = UILocalNotification();
                        aNotification.fireDate = dateBefore;
                        aNotification.timeZone = NSTimeZone.default;
                        aNotification.alertBody = NSLocalizedString("Dumpster at \(rec.m_sTitle) tomorrow (\(aEvent.m_sType))", comment:"");
                        aNotification.soundName = UILocalNotificationDefaultSoundName;
                        aNotification.applicationIconBadgeNumber = 1;
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
        
        for dsIt in m_dictDataSources {
            if dsIt.key != CRxDataSourceManager.dsRadAlerts {
                refreshDataSource(id: dsIt.key, force: force);
            }
        }
    }
    
    //--------------------------------------------------------------------------
    func refreshDataSource(id: String, force: Bool) {
        
        guard let ds = m_dictDataSources[id]
            else { return; }
        
        // check the last refresh date
        if !force && ds.m_dateLastRefreshed != nil  &&
            ds.m_dateLastRefreshed!.timeIntervalSince(Date()) < Double(ds.m_nRefreshFreqHours*60*60) {
            ds.delegate?.dataSourceRefreshEnded(nil);
            return;
        }
        
        if id == CRxDataSourceManager.dsRadNews || id == CRxDataSourceManager.dsRadAlerts {
            refreshRadniceDataSources();
            return;
        }
        else if id == CRxDataSourceManager.dsRadEvents {
            refreshRadEventsDataSource();
            return;
        }
        else if id == CRxDataSourceManager.dsBiografProgram {
            refreshBiografDataSource();
            return;
        }
        else if id == CRxDataSourceManager.dsCooltour {
            if let path = Bundle.main.url(forResource: "/test_files/p12kultpamatky", withExtension: "json") {
                ds.loadFromJSON(file: path);
                ds.delegate?.dataSourceRefreshEnded(nil);
                return;
            }
        }
        else if id == CRxDataSourceManager.dsWaste {
            if let path = Bundle.main.url(forResource: "/test_files/vokplaces", withExtension: "json") {
                ds.loadFromJSON(file: path);
                refreshWasteDataSource();
                ds.delegate?.dataSourceRefreshEnded(nil);
                return;
            }
        }
        else if id == CRxDataSourceManager.dsSosContacts {
            if let path = Bundle.main.url(forResource: "/test_files/sos", withExtension: "json") {
                ds.loadFromJSON(file: path);
                ds.delegate?.dataSourceRefreshEnded(nil);
                return;
            }
        }
    }
    
    //--------------------------------------------------------------------------
    // downloading daa from URL: http://stackoverflow.com/questions/24231680/loading-downloading-image-from-url-on-swift
    // async
    func getDataFromUrl(url: URL, completion: @escaping (_ data: Data?, _ response: URLResponse?, _ error: Error?) -> Void) {
        URLSession.shared.dataTask(with: url) {
            (data, response, error) in
            completion(data, response, error)
            }.resume()
    }
    
    //--------------------------------------------------------------------------
    func refreshRadniceDataSources() {
        guard let aNewsDS = self.m_dictDataSources[CRxDataSourceManager.dsRadNews],
            let aAlertsDS = self.m_dictDataSources[CRxDataSourceManager.dsRadAlerts]
            else { return }
        
        var urlDownload: URL?
        if !g_bUseTestFiles {
            urlDownload = URL(string: "https://www.praha12.cz/");
        }
        else {
            urlDownload = Bundle.main.url(forResource: "/test_files/praha12titulka", withExtension: "html");
        }
        guard let url = urlDownload else {
            aNewsDS.delegate?.dataSourceRefreshEnded("Cannot resolve URL");
            aAlertsDS.delegate?.dataSourceRefreshEnded("Cannot resolve URL"); return;
        }
        
        aNewsDS.m_bIsBeingRefreshed = true;
        aAlertsDS.m_bIsBeingRefreshed = true;
        showNetworkIndicator();

        getDataFromUrl(url: url) { (data, response, error) in
            guard let data = data, error == nil
            else {
                DispatchQueue.main.async() { () -> Void in
                    aNewsDS.delegate?.dataSourceRefreshEnded(NSLocalizedString("Error when downloading data", comment: ""));
                    aAlertsDS.delegate?.dataSourceRefreshEnded(NSLocalizedString("Error when downloading data", comment: ""));
                    self.hideNetworkIndicator();
                }
                return;
            }
            if let doc = HTML(html:data, encoding: .utf8) {

                // XPath syntax: https://www.w3.org/TR/xpath/#path-abbrev
                
                var arrNewsItems = [CRxEventRecord]()
                
                for node in doc.xpath("//div[@class='titulDoc aktClanky']//li") {
                    if let a_title = node.xpath("strong//a").first, let sTitle = a_title.text {
                        let aNewRecord = CRxEventRecord(title: sTitle.trimmingCharacters(in: .whitespacesAndNewlines))
                        
                        if var sLink = a_title["href"] {
                            if sLink.hasPrefix("http://www.praha12.cz") {
                                sLink = sLink.replacingOccurrences(of: "http://", with: "https://");
                            }
                            else if !sLink.hasPrefix("http") {
                                sLink = "https://www.praha12.cz" + sLink;
                            }
                            aNewRecord.m_sInfoLink = sLink;
                        }
                        
                        if let aDateNode = node.xpath("span").first, let sDate = aDateNode.text {
                            let df = DateFormatter();
                            df.dateFormat = "(dd.MM.yyyy)";
                            if let date = df.date(from: sDate) {
                                aNewRecord.m_aDate = date;// as NSDate?
                            }
                        }
                        
                        if let aTextNode = node.xpath("div[1]").first {
                            aNewRecord.m_sText = aTextNode.text?.trimmingCharacters(in: .whitespacesAndNewlines);
                        }
                        /*if let aCategoriesNode = node.xpath("div[@class='ktg']//a").first {
                         aNewRecord.m_sEventCategory = aCategoriesNode.text?.trimmingCharacters(in: .whitespacesAndNewlines);
                         }*/
                        //dump(aNewRecord)
                        arrNewsItems.append(aNewRecord);
                    }
                }
                
                var arrAlertItems = [CRxEventRecord]()

                for node in doc.xpath("//div[@class='titulDoc upoClanky']//li") {
                    if let a_title = node.xpath("strong//a").first, let sTitle = a_title.text {
                        let aNewRecord = CRxEventRecord(title: sTitle.trimmingCharacters(in: .whitespacesAndNewlines))
                        
                        if var sLink = a_title["href"] {
                            if sLink.hasPrefix("http://www.praha12.cz") {
                                sLink = sLink.replacingOccurrences(of: "http://", with: "https://");
                            }
                            else if !sLink.hasPrefix("http") {
                                sLink = "https://www.praha12.cz" + sLink;
                            }
                            aNewRecord.m_sInfoLink = sLink;
                        }
                        
                        if let aDateNode = node.xpath("span").first, let sDate = aDateNode.text {
                            let df = DateFormatter();
                            df.dateFormat = "(dd.MM.yyyy)";
                            if let date = df.date(from: sDate) {
                                aNewRecord.m_aDate = date;// as NSDate?
                            }
                        }
                        
                        if let aTextNode = node.xpath("div[1]").first {
                            aNewRecord.m_sText = aTextNode.text?.trimmingCharacters(in: .whitespacesAndNewlines);
                        }
                        //dump(aNewRecord)
                        arrAlertItems.append(aNewRecord);
                    }
                }
                DispatchQueue.main.async() { () -> Void in
                    if arrNewsItems.count > 0 {
                        aNewsDS.m_arrItems = arrNewsItems;
                    }
                    aNewsDS.m_dateLastRefreshed = Date();
                    aNewsDS.m_bIsBeingRefreshed = false;
                    self.save(dataSource: aNewsDS);

                    if arrAlertItems.count > 0 {
                        aAlertsDS.m_arrItems = arrAlertItems;
                    }
                    aAlertsDS.m_dateLastRefreshed = Date()
                    aAlertsDS.m_bIsBeingRefreshed = false;
                    self.save(dataSource: aAlertsDS)
                    self.hideNetworkIndicator();

                    aNewsDS.delegate?.dataSourceRefreshEnded(nil);  // to refresh EventCtl tableView
                    aAlertsDS.delegate?.dataSourceRefreshEnded(nil);
                    self.delegate?.dataSourceRefreshEnded(nil);     // to refresh unread count badge
                }
            }
        }
    }
    //--------------------------------------------------------------------------
    func refreshRadEventsDataSource(completition: ((_ error: String?) -> Void)? = nil) {
        guard let aEventsDS = self.m_dictDataSources[CRxDataSourceManager.dsRadEvents]
            else { return }
        
        var urlDownload: URL?
        if !g_bUseTestFiles {
            urlDownload = URL(string: "https://www.praha12.cz/vismo/kalendar-akci.asp?pocet=50");
        }
        else {
            urlDownload = Bundle.main.url(forResource: "/test_files/praha12events", withExtension: "html");
        }
        guard let url = urlDownload else { aEventsDS.delegate?.dataSourceRefreshEnded("Cannot resolve URL"); return; }

        aEventsDS.m_bIsBeingRefreshed = true;
        showNetworkIndicator();

        getDataFromUrl(url: url) { (data, response, error) in
            guard let data = data, error == nil
            else {
                DispatchQueue.main.async() { () -> Void in
                    aEventsDS.delegate?.dataSourceRefreshEnded(NSLocalizedString("Error when downloading data", comment: ""));
                    self.hideNetworkIndicator();
                }
                return;
            }
            
            if let doc = HTML(html:data, encoding: .utf8) {
                
                var arrNewItems = [CRxEventRecord]()
                
                for node in doc.xpath("//div[@class='dok']//ul[@class='ui']//li") {
                    if let a_title = node.xpath("strong//a").first, let sTitle = a_title.text {
                        let aNewRecord = CRxEventRecord(title: sTitle.trimmingCharacters(in: .whitespacesAndNewlines))
                        
                        if var sLink = a_title["href"] {
                            if sLink.hasPrefix("http://www.praha12.cz") {
                                sLink = sLink.replacingOccurrences(of: "http://", with: "https://");
                            }
                            else if !sLink.hasPrefix("http") {
                                sLink = "https://www.praha12.cz" + sLink;
                            }
                            aNewRecord.m_sInfoLink = sLink;
                        }
                        
                        if let aDateNode = node.xpath("div[1]").first, let sDate = aDateNode.text {
                            
                            // parse 5.11.2016 10:00 - 17:00
                            var dtc = DateComponents()
                            let arrParts = sDate.components(separatedBy: .whitespaces);
                            if arrParts.count >= 1 {
                                let arrDayParts = arrParts[0].components(separatedBy: ".");
                                if arrDayParts.count == 3 {
                                    dtc.day = Int(arrDayParts[0]);
                                    dtc.month = Int(arrDayParts[1]);
                                    dtc.year = Int(arrDayParts[2]);
                                    aNewRecord.m_aDate = Calendar.current.date(from: dtc);  // only date now
                                }
                            }
                            if arrParts.count >= 2 {
                                let arrTimeParts = arrParts[1].components(separatedBy: ":");
                                if arrTimeParts.count == 2 {
                                    dtc.hour = Int(arrTimeParts[0]);
                                    dtc.minute = Int(arrTimeParts[1]);
                                    aNewRecord.m_aDate = Calendar.current.date(from: dtc);  // date & time "from"
                                }
                            }
                            if arrParts.count >= 4 {
                                let arrTimeParts = arrParts[3].components(separatedBy: ":");
                                if arrTimeParts.count == 2 {
                                    dtc.hour = Int(arrTimeParts[0]);
                                    dtc.minute = Int(arrTimeParts[1]);
                                    aNewRecord.m_aDateTo = Calendar.current.date(from: dtc);  // date & time "to"
                                }
                            }
                        }
                        if let aTextNode = node.xpath("div[2]").first {
                            aNewRecord.m_sText = aTextNode.text?.trimmingCharacters(in: .whitespacesAndNewlines);
                        }
                        
                        //dump(aNewRecord)
                        arrNewItems.append(aNewRecord);
                    }
                }
                DispatchQueue.main.async() { () -> Void in
                    if arrNewItems.count > 0 {
                        aEventsDS.m_arrItems = arrNewItems;
                    }
                    aEventsDS.m_dateLastRefreshed = Date();
                    aEventsDS.m_bIsBeingRefreshed = false;
                    self.save(dataSource: aEventsDS);
                    self.hideNetworkIndicator();
                    aEventsDS.delegate?.dataSourceRefreshEnded(nil);
                }
            }
        }
    }
    
    //--------------------------------------------------------------------------
    func refreshBiografDataSource(completition: ((_ error: String?) -> Void)? = nil) {
        guard let aBiografDS = self.m_dictDataSources[CRxDataSourceManager.dsBiografProgram]
            else { return }
        
        var urlDownload: URL?
        if !g_bUseTestFiles {
            urlDownload = URL(string: "http://www.modranskybiograf.cz/klient-349/kino-114/");
        }
        else {
            urlDownload = Bundle.main.url(forResource: "/test_files/modrbiograf", withExtension: "html");
        }
        guard let url = urlDownload else { aBiografDS.delegate?.dataSourceRefreshEnded("Cannot resolve URL"); return; }
        
        aBiografDS.m_bIsBeingRefreshed = true;
        showNetworkIndicator();

        getDataFromUrl(url: url) { (data, response, error) in
            guard let data = data, error == nil
            else {
                DispatchQueue.main.async() { () -> Void in
                    completition?(NSLocalizedString("Error when downloading data", comment: ""));
                    self.hideNetworkIndicator();
                }
                return;
            }

            if let doc = HTML(html:data, encoding: .utf8) {
                
                let sAddress = "Modřanský biograf\nU Kina 1/44\n143 00 Praha 12 - Modřany";
                var arrNewItems = [CRxEventRecord]()
                
                let unitFlags : Set<Calendar.Component> = [.day, .month, .year]
                let aTodayComps = Calendar.current.dateComponents(unitFlags, from: Date())
                
                for node in doc.xpath("//div[@class='calendar-left-table-tr']") {
                    if let aLinkNode = node.xpath("a[@class='cal-event-item shortName']").first {
                        
                        if let aTitleNode = aLinkNode.xpath("h2").first, let sTitle = aTitleNode.text {
                            if sTitle == "KINO NEHRAJE" {
                                continue;
                            }
                            let aNewRecord = CRxEventRecord(title: sTitle.trimmingCharacters(in: .whitespacesAndNewlines))
                            
                            var dtc = DateComponents()
                            if let aDateNode = aLinkNode.xpath("div[@class='ap_date']").first, let sDate = aDateNode.text {
                                let sParts : [String] = sDate.components(separatedBy: ".");
                                if sParts.count >= 2 {
                                    dtc.day = Int(sParts[0]);
                                    dtc.month = Int(sParts[1]);
                                    if dtc.day != nil && dtc.month != nil {
                                        dtc.year = (dtc.month! < aTodayComps.month! ? aTodayComps.year!+1 : aTodayComps.year! )
                                    }
                                }
                            }
                            if let aTimeNode = aLinkNode.xpath("div[@class='ap_time']").first, let sTime = aTimeNode.text {
                                let sParts : [String] = sTime.components(separatedBy: ":");
                                if sParts.count == 2 {
                                    dtc.hour = Int(sParts[0]);
                                    dtc.minute = Int(sParts[1]);
                                }
                            }
                            aNewRecord.m_aDate = Calendar.current.date(from: dtc)
                            
                            if let sLink = aLinkNode["href"] {
                                aNewRecord.m_sInfoLink = "http://www.modranskybiograf.cz" + sLink;
                            }
                            if let sDescription = aLinkNode["title"] {  // remove newlines
                                let components = sDescription.components(separatedBy: NSCharacterSet.newlines)
                                aNewRecord.m_sText = components.filter { !$0.isEmpty }.joined(separator: " | ");
                            }
                            if let aBuyLinkNode = aLinkNode.xpath("..//a[@class='cal-event-item-buy-span']").first {
                                aNewRecord.m_sBuyLink = aBuyLinkNode["href"];
                            }
                            
                            aNewRecord.m_sAddress = sAddress;
                            
                            //dump(aNewRecord)
                            arrNewItems.append(aNewRecord);
                        }
                    }
                }
                DispatchQueue.main.async() { () -> Void in
                    if arrNewItems.count > 0 {
                        aBiografDS.m_arrItems = arrNewItems;
                    }
                    aBiografDS.m_dateLastRefreshed = Date();
                    aBiografDS.m_bIsBeingRefreshed = false;
                    self.save(dataSource: aBiografDS);
                    self.hideNetworkIndicator();
                    aBiografDS.delegate?.dataSourceRefreshEnded(nil);
                }
            }
        }
    }
    
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
                    if category == .waste {
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
