//
//  EventRecord.swift
//  Dvanactka
//
//  Created by Jan Adamec on 30.10.16.
//  Copyright © 2016 Jan Adamec. All rights reserved.
//

import UIKit
import CoreLocation
import Kanna

class CRxDateInterval: NSObject {
    var m_dateStart: Date!
    var m_dateEnd: Date!
    
    init(start: Date, end: Date) {
        m_dateStart = start;
        m_dateEnd = end;
    }
}

class CRxEventRecord: NSObject {
    var m_sTitle: String = ""
    var m_sInfoLink: String?
    var m_sBuyLink: String?
    var m_sCategory: String?
    var m_sText: String?
    var m_aDate: Date?      // date and time of an event start or publish date of an article
    var m_aDateTo: Date?    // date and time of an evend end
    var m_sAddress: String? // location address
    var m_aLocation: CLLocation?    // event location
    var m_arrOpeningHours: [Int: CRxDateInterval]?  // dictionary weekday -> interval
    
    init(title sTitle: String) {
        m_sTitle = sTitle
        super.init()
    }
    
    static func loadDate(string: String) -> Date? {
        let df = DateFormatter();
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ";
        return df.date(from: string);
    }
    
    static func saveDate(date: Date) -> String {
        let df = DateFormatter();
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ";
        return df.string(from: date);
    }
    
    init?(from jsonItem: [String: AnyObject]) { // load from JSON
        
        if let title = jsonItem["title"] as? String { m_sTitle = title }
        if m_sTitle.isEmpty { return nil }
        
        if let infoLink = jsonItem["infoLink"] as? String { m_sInfoLink = infoLink }
        if let buyLink = jsonItem["buyLink"] as? String { m_sBuyLink = buyLink }
        if let category = jsonItem["category"] as? String { m_sCategory = category }
        if let text = jsonItem["text"] as? String { m_sText = text }
        if let date = jsonItem["date"] as? String { m_aDate = CRxEventRecord.loadDate(string: date); }
        if let dateTo = jsonItem["dateTo"] as? String { m_aDateTo = CRxEventRecord.loadDate(string: dateTo); }

        if let locationLat = jsonItem["locationLat"] as? String,
            let locationLong = jsonItem["locationLong"] as? String,
            let dLocLat = Double(locationLat),
            let dLocLong = Double(locationLong) { m_aLocation = CLLocation(latitude: dLocLat, longitude: dLocLong) }
    }
    
    func saveToJSON() -> [String: AnyObject] {
        var item: [String: AnyObject] = ["title": m_sTitle as AnyObject]
        if let infoLink = m_sInfoLink { item["infoLink"] = infoLink as AnyObject }
        if let buyLink = m_sBuyLink { item["buyLink"] = buyLink as AnyObject }
        if let category = m_sCategory { item["category"] = category as AnyObject }
        if let text = m_sText { item["text"] = text as AnyObject }
        if let date = m_aDate { item["date"] = CRxEventRecord.saveDate(date: date) as AnyObject }
        if let dateTo = m_aDateTo { item["dateTo"] = CRxEventRecord.saveDate(date: dateTo) as AnyObject }
        
        if let location = m_aLocation {
            item["locationLat"] = String(location.coordinate.latitude) as AnyObject
            item["locationLong"] = String(location.coordinate.longitude) as AnyObject
        }
        
        return item;
    }
    
    func openInfoLink() {
        if let link = m_sInfoLink,
            let url = URL(string: link) {
            UIApplication.shared.openURL(url)
        }
    }
    func openBuyLink() {
        if let link = m_sBuyLink,
            let url = URL(string: link) {
            UIApplication.shared.openURL(url)
        }
    }
}

//--------------------------------------------------------------------------
class CRxDataSource : NSObject {
    var m_sId: String = ""
    var m_sTitle: String = ""           // human readable
    var m_nRefreshFreqHours: Int = 18   // refresh after 18 hours
    var m_bShowMap: Bool = false
    var m_dateLastRefreshed: Date?
    var m_arrItems: [CRxEventRecord] = [CRxEventRecord]()   // the data
    
    enum DataType {
        case events
        case news
        case places
    }
    var m_eType = DataType.news

    init(id: String, title: String, type: DataType, refreshFreqHours: Int = 18, showMap: Bool = false) {
        m_sId = id;
        m_sTitle = title;
        m_eType = type;
        m_nRefreshFreqHours = refreshFreqHours;
        m_bShowMap = showMap;
        super.init()
    }
    
    func loadFromJSON(file: URL) {
        // decode JSON
        var json: AnyObject
        do {
            let jsonString = try String(contentsOf: file, encoding: .utf8);
            let jsonData = jsonString.data(using: String.Encoding.utf8)!;
            json = try JSONSerialization.jsonObject(with: jsonData, options: JSONSerialization.ReadingOptions()) as AnyObject
        } catch { return }
        
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
        }
    }
    
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
}

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
    static let dsCoolTrees = "dsCoolTrees";
    
    var m_urlDocumentsDir: URL!
    
    func defineDatasources() {
        
        let documentsDirectoryPathString = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        m_urlDocumentsDir = URL(fileURLWithPath: documentsDirectoryPathString)
        
        m_dictDataSources[CRxDataSourceManager.dsRadNews] = CRxDataSource(id: CRxDataSourceManager.dsRadNews, title: NSLocalizedString("Townhall News", comment: ""), type: .news);
        m_dictDataSources[CRxDataSourceManager.dsRadAlerts] = CRxDataSource(id: CRxDataSourceManager.dsRadAlerts, title: NSLocalizedString("Townhall Alerts", comment: ""), type: .news);
        m_dictDataSources[CRxDataSourceManager.dsRadEvents] = CRxDataSource(id: CRxDataSourceManager.dsRadEvents, title: NSLocalizedString("Townhall Events", comment: ""), type: .events);
        m_dictDataSources[CRxDataSourceManager.dsBiografProgram] = CRxDataSource(id: CRxDataSourceManager.dsBiografProgram, title: "Modřanský Biograf", type: .events);
        m_dictDataSources[CRxDataSourceManager.dsCooltour] = CRxDataSource(id: CRxDataSourceManager.dsCooltour, title: NSLocalizedString("Landmarks", comment: ""), type: .places, refreshFreqHours: 100, showMap: true);
        m_dictDataSources[CRxDataSourceManager.dsCoolTrees] = CRxDataSource(id: CRxDataSourceManager.dsCoolTrees, title: NSLocalizedString("Memorial Trees", comment: ""), type: .places, refreshFreqHours: 100, showMap: true);
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
    }
    
    //--------------------------------------------------------------------------
    func save(dataSource: CRxDataSource) {
        dataSource.saveToJSON(file: fileForDataSource(id: dataSource.m_sId));
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
    func refreshDataSource(id: String, force: Bool = false) {

        guard let ds = m_dictDataSources[id]
            else { return; }
        
        // check the last refresh date
        if !force && ds.m_dateLastRefreshed != nil  &&
                ds.m_dateLastRefreshed!.timeIntervalSince(Date()) < Double(ds.m_nRefreshFreqHours*60*60) {
            return;
        }
        
        if id == CRxDataSourceManager.dsRadNews || id == CRxDataSourceManager.dsRadAlerts {
            refreshRadniceDataSources();
        }
        else if id == CRxDataSourceManager.dsRadEvents {
            refreshRadEventsDataSource();
        }
        else if id == CRxDataSourceManager.dsBiografProgram {
            refreshBiografDataSource();
        }
        else if id == CRxDataSourceManager.dsCooltour {
            if let path = Bundle.main.url(forResource: "/test_files/p12kultpamatky", withExtension: "json") {
                ds.loadFromJSON(file: path);
            }
        }
        else if id == CRxDataSourceManager.dsCoolTrees {
            if let path = Bundle.main.url(forResource: "/test_files/p12stromy", withExtension: "json") {
                ds.loadFromJSON(file: path);
            }
        }
    }
    
    //--------------------------------------------------------------------------
    func refreshRadniceDataSources() {
        
        // XPath syntax: https://www.w3.org/TR/xpath/#path-abbrev

        //let url = URL(string: "https://www.praha12.cz/")
        //if let doc = HTML(url: url!, encoding: .utf8) {
        
        guard let aNewsDS = m_dictDataSources[CRxDataSourceManager.dsRadNews],
            let aAlertsDS = m_dictDataSources[CRxDataSourceManager.dsRadAlerts]
            else { return }

        if let path = Bundle.main.path(forResource: "/test_files/praha12titulka", ofType: "html") {
            let html = try! String(contentsOfFile: path, encoding: .utf8)
            if let doc = HTML(html: html, encoding: .utf8) {
                
                var arrNewItems = [CRxEventRecord]()
                
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
                        if let aCategoriesNode = node.xpath("div[@class='ktg']//a").first {
                            aNewRecord.m_sCategory = aCategoriesNode.text?.trimmingCharacters(in: .whitespacesAndNewlines);
                        }
                        //dump(aNewRecord)
                        arrNewItems.append(aNewRecord);
                    }
                }
                aNewsDS.m_arrItems = arrNewItems;
                aNewsDS.m_dateLastRefreshed = Date();
                save(dataSource: aNewsDS);

                arrNewItems.removeAll()

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
                        arrNewItems.append(aNewRecord);
                    }
                }
                aAlertsDS.m_arrItems = arrNewItems
                aAlertsDS.m_dateLastRefreshed = Date()
                save(dataSource: aAlertsDS)
            }
        }
    }
    //--------------------------------------------------------------------------
    func refreshRadEventsDataSource() {
        
        guard let aEventsDS = m_dictDataSources[CRxDataSourceManager.dsRadEvents]
            else { return }
        
        //let url = URL(string: "https://www.praha12.cz/vismo/kalendar-akci.asp")  //?pocet=50
        //if let doc = HTML(url: url!, encoding: .utf8) {
        if let path = Bundle.main.path(forResource: "/test_files/praha12events", ofType: "html") {
            let html = try! String(contentsOfFile: path, encoding: .utf8)
            if let doc = HTML(html: html, encoding: .utf8) {
                
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
                aEventsDS.m_arrItems = arrNewItems;
                aEventsDS.m_dateLastRefreshed = Date();
                save(dataSource: aEventsDS);
            }
        }
    }
    
    //--------------------------------------------------------------------------
    func refreshBiografDataSource() {

        guard let aBiografDS = m_dictDataSources[CRxDataSourceManager.dsBiografProgram]
            else { return }

        let sAddress = "Modřanský biograf\nU Kina 1/44\n143 00 Praha 12 - Modřany";
        
        //let url = URL(string: "http://www.modranskybiograf.cz/klient-349/kino-114/")
        //if let doc = HTML(url: url!, encoding: .utf8) {

        if let path = Bundle.main.path(forResource: "/test_files/modrbiograf", ofType: "html") {
            let html = try! String(contentsOfFile: path, encoding: .utf8)
            if let doc = HTML(html: html, encoding: .utf8) {
                
                var arrNewItems = [CRxEventRecord]()

                let unitFlags : Set<Calendar.Component> = [.day, .month, .year]
                let aTodayComps = Calendar.current.dateComponents(unitFlags, from: Date())

                for node in doc.xpath("//div[@class='calendar-left-table-tr']") {
                    if let aLinkNode = node.xpath("a[@class='cal-event-item shortName']").first {
                        
                        if let aTitleNode = aLinkNode.xpath("h2").first, let sTitle = aTitleNode.text {
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
                aBiografDS.m_arrItems = arrNewItems;
                aBiografDS.m_dateLastRefreshed = Date();
                save(dataSource: aBiografDS);
            }
        }
    }
}
