//
//  EventRecord.swift
//  Dvanactka
//
//  Created by Jan Adamec on 30.10.16.
//  Copyright © 2016 Jan Adamec. All rights reserved.
//

import UIKit
import Kanna

class CRxEventRecord: NSObject {
    var m_sTitle: String = ""
    var m_sLink: String?
    var m_sCategory: String?
    var m_sText: String?
    var m_aDate: Date?
    
    init(title sTitle: String) {
        m_sTitle = sTitle
    }
    
    func openLink() {
        if let link = m_sLink {
            if let url = URL(string: link) {
                UIApplication.shared.openURL(url);
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
}

//--------------------------------------------------------------------------
class CRxDataSourceManager : NSObject {
    var m_dictDataSources = [String: CRxDataSource]()   // distionary on data sources, id -> source
    
    static let sharedInstance = CRxDataSourceManager()  // singleton
    private override init() {}     // "private" prevents others from using the default '()' initializer for this class (so being singleton)
    
    static let dsRadNews = "dsRadNews";
    static let dsRadAlerts = "dsRadAlerts";
    static let dsBiografProgram = "dsBiografProgram";
    
    func defineDatasources() {
        m_dictDataSources[CRxDataSourceManager.dsRadNews] = CRxDataSource(id: CRxDataSourceManager.dsRadNews, title: NSLocalizedString("Townhall News", comment: ""));
        m_dictDataSources[CRxDataSourceManager.dsRadAlerts] = CRxDataSource(id: CRxDataSourceManager.dsRadAlerts, title: NSLocalizedString("Townhall Alerts", comment: ""));
        m_dictDataSources[CRxDataSourceManager.dsBiografProgram] = CRxDataSource(id: CRxDataSourceManager.dsBiografProgram, title: NSLocalizedString("Modransky Biograf Program", comment: ""));
    }
    
    func loadData() {
        //
    }
    
    func refreshAllDataSources(force: Bool = false) {
        
    }
    
    func refreshDataSource(id: String, force: Bool = false) {
    
    }
    
    func refreshRadniceDataSources() {
        
        // XPath syntax: https://www.w3.org/TR/xpath/#path-abbrev

        //let url = URL(string: "https://www.praha12.cz/")
        //if let doc = HTML(url: url!, encoding: .utf8) {
        
        if let path = Bundle.main.path(forResource: "/test_files/praha12titulka", ofType: "html") {
            let html = try! String(contentsOfFile: path, encoding: .utf8)
            if let doc = HTML(html: html, encoding: .utf8) {
                
                let aNewsDS = m_dictDataSources[CRxDataSourceManager.dsRadNews]
                
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
                            aNewRecord.m_sLink = sLink;
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
                        aNewsDS?.m_arrItems.append(aNewRecord);
                    }
                }
                aNewsDS?.m_dateLastRefreshed = Date()

                let aAlertsDS = m_dictDataSources[CRxDataSourceManager.dsRadAlerts]
                
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
                            aNewRecord.m_sLink = sLink;
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
                        aAlertsDS?.m_arrItems.append(aNewRecord);
                    }
                }
                aAlertsDS?.m_dateLastRefreshed = Date()
            }
        }
    }
    
    func refreshBiografDataSource() {
        
        //let url = URL(string: "http://www.modranskybiograf.cz/klient-349/kino-114/")
        //if let doc = HTML(url: url!, encoding: .utf8) {

        if let path = Bundle.main.path(forResource: "/test_files/modrbiograf", ofType: "html") {
            let html = try! String(contentsOfFile: path, encoding: .utf8)
            if let doc = HTML(html: html, encoding: .utf8) {
                
                let aBiografDS = m_dictDataSources[CRxDataSourceManager.dsBiografProgram]
                
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
                                aNewRecord.m_sLink = "http://www.modranskybiograf.cz" + sLink;
                            }
                            if let sDescription = aLinkNode["title"] {  // remove newlines
                                let components = sDescription.components(separatedBy: NSCharacterSet.newlines)
                                aNewRecord.m_sText = components.filter { !$0.isEmpty }.joined(separator: " | ")
                            }

                            //dump(aNewRecord)
                            aBiografDS?.m_arrItems.append(aNewRecord);
                        }
                    }
                }
                aBiografDS?.m_dateLastRefreshed = Date()
            }
        }
    }
}
