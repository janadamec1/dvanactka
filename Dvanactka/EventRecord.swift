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

// this class is for opening hours
class CRxHourInterval: NSObject {
    var m_weekday: Int          // weekday (1 = monday, 7 = sunday)
    var m_hourStart: Int        // int as 1235 = 12:35, or 1000 = 10:00
    var m_hourEnd: Int
    
    init(weekday: Int, start: Int, end: Int) {
        m_weekday = weekday;
        m_hourStart = start;
        m_hourEnd = end;
    }
    
    init?(from string:String) {
        if let iColon = string.range(of: ":"),
                let iHyphen = string.range(of: "-") {
            let day = string.substring(to: iColon.lowerBound)
            let hourStart = string.substring(with: Range(uncheckedBounds: (lower: iColon.upperBound, upper: iHyphen.lowerBound)))
            let hourEnd = string.substring(from: iHyphen.upperBound)
            if let iDay = Int(day),
                    let iHourStart = Int(hourStart),
                    let iHourEnd = Int(hourEnd) {
                m_weekday = iDay;
                m_hourStart = iHourStart;
                m_hourEnd = iHourEnd;
                super.init()
            }
            else {
                return nil;
            }
        }
        else {
            return nil;
        }
    }
    
    func toString() -> String {
        return "\(m_weekday): \(m_hourStart)-\(m_hourEnd)";
    }
}

// this class is used for waste containers records
class CRxEventInterval: NSObject {
    var m_dateStart: Date
    var m_dateEnd: Date
    var m_sType: String
    
    init(start: Date, end: Date, type: String) {
        m_dateStart = start;
        m_dateEnd = end;
        m_sType = type;
        super.init()
    }
    
    init?(from string:String) {
        let items = string.components(separatedBy: ";")
        if items.count < 3 {
            return nil;
        }
        guard let start = CRxEventRecord.loadDate(string: items[1]),
            let end = CRxEventRecord.loadDate(string: items[2])
        else {
            return nil;
        }
        m_sType = items[0];
        m_dateStart = start;
        m_dateEnd = end;
        super.init()
    }
    
    func toString() -> String {
        return "\(m_sType);\(CRxEventRecord.saveDate(date: m_dateStart));\(CRxEventRecord.saveDate(date: m_dateEnd))";
    }
    
    func toDisplayString() -> String {
        // strip time from the date, leave day only
        let calendar = Calendar.current;
        var dtc = calendar.dateComponents([.year, .month, .day, .weekday], from: m_dateStart);
        let dayFrom = calendar.date(from: dtc)
        
        let df = DateFormatter();
        let sWeekDay = df.shortWeekdaySymbols[dtc.weekday!-1];

        dtc = calendar.dateComponents([.year, .month, .day], from: m_dateEnd);
        let dayTo = calendar.date(from: dtc)
        
        df.dateStyle = .short;
        df.timeStyle = .short;
        let sFrom = df.string(from: m_dateStart);
        
        if dayFrom == dayTo {         // skip dayTo when on the same day (different time)
            df.dateStyle = .none;
        }
        let sTo = df.string(from: m_dateEnd);
        return "\(sWeekDay) \(sFrom) - \(sTo)";
    }
}

enum CRxCategory: String {
    case informace, lekarna, prvniPomoc, policie
    case pamatka, pamatnyStrom, vyznamnyStrom
    case remeslnik, restaurace, obchod
    case waste
}

class CRxEventRecord: NSObject {
    var m_sTitle: String = ""
    var m_sInfoLink: String?
    var m_sBuyLink: String?
    var m_eCategory: CRxCategory?
    var m_sText: String?
    var m_aDate: Date?      // date and time of an event start or publish date of an article
    var m_aDateTo: Date?    // date and time of an evend end
    var m_sAddress: String? // location address
    var m_aLocation: CLLocation?    // event location
    var m_sPhoneNumber: String?
    var m_sEmail: String?
    var m_arrOpeningHours: [CRxHourInterval]?
    var m_arrEvents: [CRxEventInterval]?
    
    var m_distFromUser: CLLocationDistance = Double.greatestFiniteMagnitude // calculated and set in runtime
    
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
        if let category = jsonItem["category"] as? String { m_eCategory = CRxCategory(rawValue: category); }
        if let text = jsonItem["text"] as? String { m_sText = text }
        if let phone = jsonItem["phone"] as? String { m_sPhoneNumber = phone }
        if let email = jsonItem["email"] as? String { m_sEmail = email }
        if let address = jsonItem["address"] as? String { m_sAddress = address }
        if let date = jsonItem["date"] as? String { m_aDate = CRxEventRecord.loadDate(string: date); }
        if let dateTo = jsonItem["dateTo"] as? String { m_aDateTo = CRxEventRecord.loadDate(string: dateTo); }

        if let locationLat = jsonItem["locationLat"] as? String,
            let locationLong = jsonItem["locationLong"] as? String,
            let dLocLat = Double(locationLat),
            let dLocLong = Double(locationLong) { m_aLocation = CLLocation(latitude: dLocLat, longitude: dLocLong) }
        
        if let hours = jsonItem["openingHours"] as? String {
            m_arrOpeningHours = [CRxHourInterval]();
            let lstDays = hours.replacingOccurrences(of: " ", with: "").components(separatedBy: ",");
            for dayIt in lstDays {
                if let interval = CRxHourInterval(from: dayIt) {
                    m_arrOpeningHours?.append(interval);
                }
            }
        }
        if let events = jsonItem["events"] as? String {
            m_arrEvents = [CRxEventInterval]();
            let lstEvents = events.components(separatedBy: "|");
            for it in lstEvents {
                if let interval = CRxEventInterval(from: it) {
                    m_arrEvents?.append(interval)
                }
            }
            
        }
    }
    
    func saveToJSON() -> [String: AnyObject] {
        var item: [String: AnyObject] = ["title": m_sTitle as AnyObject]
        if let infoLink = m_sInfoLink { item["infoLink"] = infoLink as AnyObject }
        if let buyLink = m_sBuyLink { item["buyLink"] = buyLink as AnyObject }
        if let category = m_eCategory { item["category"] = category.rawValue as AnyObject }
        if let text = m_sText { item["text"] = text as AnyObject }
        if let phone = m_sPhoneNumber { item["phone"] = phone as AnyObject }
        if let email = m_sEmail { item["email"] = email as AnyObject }
        if let address = m_sAddress { item["address"] = address as AnyObject }
        if let date = m_aDate { item["date"] = CRxEventRecord.saveDate(date: date) as AnyObject }
        if let dateTo = m_aDateTo { item["dateTo"] = CRxEventRecord.saveDate(date: dateTo) as AnyObject }
        
        if let location = m_aLocation {
            item["locationLat"] = String(location.coordinate.latitude) as AnyObject
            item["locationLong"] = String(location.coordinate.longitude) as AnyObject
        }
        
        if let hours = m_arrOpeningHours {
            var sVal = "";
            for it in hours {
                if !sVal.isEmpty {
                    sVal += ", ";
                }
                sVal += it.toString();
            }
            item["openingHours"] = sVal as AnyObject;
        }
        if let events = m_arrEvents {
            var sVal = "";
            for it in events {
                if !sVal.isEmpty {
                    sVal += "|";
                }
                sVal += it.toString();
            }
            item["events"] = sVal as AnyObject;
        }
        
        return item;
    }
    
    static func categoryLocalName(category: CRxCategory) -> String {
        switch category {
        case .informace: return NSLocalizedString("Information", comment: "");
        case .lekarna: return NSLocalizedString("Pharmacies", comment: "");
        case .prvniPomoc: return NSLocalizedString("First Aid", comment: "");
        case .policie: return NSLocalizedString("Police", comment: "");
        case .pamatka: return NSLocalizedString("Landmarks", comment: "");
        case .pamatnyStrom: return NSLocalizedString("Memorial Trees", comment: "");
        case .vyznamnyStrom: return NSLocalizedString("Significant Trees", comment: "");
        case .remeslnik: return NSLocalizedString("Artisans", comment: "");
        case .restaurace: return NSLocalizedString("Restaurants", comment: "");
        case .obchod: return NSLocalizedString("Shops", comment: "");
        case .waste: return NSLocalizedString("Waste Dumpsters", comment: "");
        //default: return category.rawValue;
        }
    }

    static func categoryLocalName(category: CRxCategory?) -> String {
        if let cat = category {
            return CRxEventRecord.categoryLocalName(category: cat);
        }
        else {
            return "";
        }
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
    static let dsSosContacts = "dsSosContacts";
    static let dsWaste = "dsWaste";
    
    var m_urlDocumentsDir: URL!
    
    func defineDatasources() {
        
        let documentsDirectoryPathString = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        m_urlDocumentsDir = URL(fileURLWithPath: documentsDirectoryPathString)
        
        m_dictDataSources[CRxDataSourceManager.dsRadNews] = CRxDataSource(id: CRxDataSourceManager.dsRadNews, title: NSLocalizedString("News", comment: ""), type: .news);
        m_dictDataSources[CRxDataSourceManager.dsRadAlerts] = CRxDataSource(id: CRxDataSourceManager.dsRadAlerts, title: NSLocalizedString("Alerts", comment: ""), type: .news);
        m_dictDataSources[CRxDataSourceManager.dsRadEvents] = CRxDataSource(id: CRxDataSourceManager.dsRadEvents, title: NSLocalizedString("Events", comment: ""), type: .events);
        m_dictDataSources[CRxDataSourceManager.dsBiografProgram] = CRxDataSource(id: CRxDataSourceManager.dsBiografProgram, title: "Modřanský Biograf", type: .events);
        m_dictDataSources[CRxDataSourceManager.dsCooltour] = CRxDataSource(id: CRxDataSourceManager.dsCooltour, title: NSLocalizedString("Landmarks", comment: ""), type: .places, refreshFreqHours: 100, showMap: true);
        //m_dictDataSources[CRxDataSourceManager.dsCoolTrees] = CRxDataSource(id: CRxDataSourceManager.dsCoolTrees, title: NSLocalizedString("Memorial Trees", comment: ""), type: .places, refreshFreqHours: 100, showMap: true);
        m_dictDataSources[CRxDataSourceManager.dsWaste] = CRxDataSource(id: CRxDataSourceManager.dsWaste, title: NSLocalizedString("Waste", comment: ""), type: .places, showMap: true);
        m_dictDataSources[CRxDataSourceManager.dsSosContacts] = CRxDataSource(id: CRxDataSourceManager.dsSosContacts, title: NSLocalizedString("Help", comment: ""), type: .places, refreshFreqHours: 100, showMap: true);
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
        else if id == CRxDataSourceManager.dsWaste {
            if let path = Bundle.main.url(forResource: "/test_files/vokplaces", withExtension: "json") {
                ds.loadFromJSON(file: path);
                refreshWasteDataSource();
            }
        }
        else if id == CRxDataSourceManager.dsSosContacts {
            if let path = Bundle.main.url(forResource: "/test_files/sos", withExtension: "json") {
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
                        /*if let aCategoriesNode = node.xpath("div[@class='ktg']//a").first {
                            aNewRecord.m_sEventCategory = aCategoriesNode.text?.trimmingCharacters(in: .whitespacesAndNewlines);
                        }*/
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
                aBiografDS.m_arrItems = arrNewItems;
                aBiografDS.m_dateLastRefreshed = Date();
                save(dataSource: aBiografDS);
            }
        }
    }
    
    //--------------------------------------------------------------------------
    func findVokLocation(alias: String, ds: CRxDataSource) -> CRxEventRecord? {
        let sAliasCompressed = alias.replacingOccurrences(of: " ", with: "");
        for rec in ds.m_arrItems {
            if let text = rec.m_sText {
                let sTextCompressed = text.replacingOccurrences(of: " ", with: "");
                if sTextCompressed.range(of: sAliasCompressed) != nil {
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
                
                let dateStart = Calendar.current.date(from: aDateComps);
                
                aDateComps.hour = Int(sTimeEndComps[0]);
                aDateComps.minute = Int(sTimeEndComps[1]);
                let dateEnd = Calendar.current.date(from: aDateComps);
                
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
    
    func refreshWasteDataSource() {
        
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
                rec.m_sInfoLink = "https://www.praha12.cz/odpady/ds-1138/";
            }
            
            aVokDS.m_dateLastRefreshed = Date();
            save(dataSource: aVokDS);
        }
    }
}
