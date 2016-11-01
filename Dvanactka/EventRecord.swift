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

class CRxEventRecord: NSObject {
    var m_sTitle: String = ""
    var m_sInfoLink: String?
    var m_sBuyLink: String?
    var m_sCategory: String?
    var m_sText: String?
    var m_aDate: Date?      // date and time of an event start or publish date of an article
    var m_aDateTo: Date?    // date and time of an evend end
    var m_aLocation: CLLocation?    // event location
    
    init(title sTitle: String) {
        m_sTitle = sTitle
    }
    
    init?(from jsonItem: [String: AnyObject]) { // load from JSON
        
        if let title = jsonItem["title"] as? String { m_sTitle = title }
        if m_sTitle.isEmpty { return nil }
        
        if let infoLink = jsonItem["infoLink"] as? String { m_sInfoLink = infoLink }
        if let buyLink = jsonItem["buyLink"] as? String { m_sBuyLink = buyLink }
        if let category = jsonItem["category"] as? String { m_sCategory = category }
        if let text = jsonItem["text"] as? String { m_sText = text }
        
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        if let date = jsonItem["date"] as? String { m_aDate = df.date(from: date) }
        if let dateTo = jsonItem["dateTo"] as? String { m_aDateTo = df.date(from: dateTo) }

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
        
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        if let date = m_aDate { item["date"] = df.string(from: date) as AnyObject }
        if let dateTo = m_aDateTo { item["dateTo"] = df.string(from: dateTo) as AnyObject }
        
        if let location = m_aLocation {
            item["locationLat"] = String(location.coordinate.latitude) as AnyObject
            item["locationLong"] = String(location.coordinate.longitude) as AnyObject
        }
        
        return item;
    }
    
    func openInfoLink() {
        if let link = m_sInfoLink {
            if let url = URL(string: link) {
                UIApplication.shared.openURL(url)
            }
        }
    }
}

//--------------------------------------------------------------------------
class CRxDataSource : NSObject {
    var m_sId: String = ""
    var m_sTitle: String = ""           // human readable
    var m_nRefreshFreqHours: Int = 24   // refresh after 12 hours
    var m_dateLastRefreshed: Date?
    var m_arrItems: [CRxEventRecord] = [CRxEventRecord]()   // the data

    init(id: String, title: String, refreshFreqHours: Int = 24) {
        m_sId = id;
        m_sTitle = title;
        m_nRefreshFreqHours = refreshFreqHours;
    }
    
    func loadFromJSON(file: URL) {
        var json: AnyObject
        do {
            let jsonString = try String(contentsOf: file, encoding: .utf8);
            let jsonData = jsonString.data(using: String.Encoding.utf8)!
            json = try JSONSerialization.jsonObject(with: jsonData, options: JSONSerialization.ReadingOptions()) as AnyObject
        } catch { return }
        
        if let jsonItems = json["items"] as? [[String: AnyObject]] {
            for item in jsonItems {
                if let aNewRecord = CRxEventRecord(from: item) {
                    m_arrItems.append(aNewRecord)
                }
                
            }
        }
    }
    
    func saveToJSON(file: URL) {
        var jsonItems = [AnyObject]()
        for item in m_arrItems {
            jsonItems.append(item.saveToJSON() as AnyObject);
        }
        
        let json = ["items" : jsonItems];
        
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
    
    var m_urlDocumentsDir: URL!
    
    func defineDatasources() {
        
        let documentsDirectoryPathString = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        m_urlDocumentsDir = URL(fileURLWithPath: documentsDirectoryPathString)
        
        m_dictDataSources[CRxDataSourceManager.dsRadNews] = CRxDataSource(id: CRxDataSourceManager.dsRadNews, title: NSLocalizedString("Townhall News", comment: ""));
        m_dictDataSources[CRxDataSourceManager.dsRadAlerts] = CRxDataSource(id: CRxDataSourceManager.dsRadAlerts, title: NSLocalizedString("Townhall Alerts", comment: ""));
        m_dictDataSources[CRxDataSourceManager.dsRadEvents] = CRxDataSource(id: CRxDataSourceManager.dsRadEvents, title: NSLocalizedString("Townhall Events", comment: ""));
        m_dictDataSources[CRxDataSourceManager.dsBiografProgram] = CRxDataSource(id: CRxDataSourceManager.dsBiografProgram, title: NSLocalizedString("Modransky Biograf Program", comment: ""));
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
        
    }
    
    //--------------------------------------------------------------------------
    func refreshDataSource(id: String, force: Bool = false) {
    
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
