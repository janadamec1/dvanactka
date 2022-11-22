/*
 Copyright 2016-2022 Jan Adamec.
 
 This file is part of "Dvanactka".
 
 "Dvanactka" is free software; see the file COPYING.txt,
 included in this distribution, for details about the copyright.
 
 "Dvanactka" is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 ----------------------------------------------------------------------------
 */

import UIKit
import CoreLocation
import SafariServices

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
            let day = String(string.prefix(upTo:iColon.lowerBound));
            let hourStart = String(string[iColon.upperBound..<iHyphen.lowerBound]);
            let hourEnd = String(string.suffix(from: iHyphen.upperBound));
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
    
    func toIntervalDisplayString() -> String {
        let sStart = String(format: "%d:%02d", (m_hourStart/100), (m_hourStart%100));
        let sEnd = String(format: "%d:%02d", (m_hourEnd/100), (m_hourEnd%100));
        return "\(sStart) - \(sEnd)";
    }
}

//---------------------------------------------------------------------------
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
    
    //---------------------------------------------------------------------------
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
    
    //---------------------------------------------------------------------------
    func toRelativeIntervalString() -> String {
        var sString = "";
        let dayToday = Date();
        if dayToday > m_dateEnd {
            let aDiff = dayToday.timeIntervalSince(m_dateEnd);
            let nDaysAgo = Int(aDiff/(60*60*24));
            sString = String(format: NSLocalizedString("%d days ago", comment:""), nDaysAgo)
        }
        else {
            let aDiff = m_dateStart.timeIntervalSince(dayToday);
            let nMinutes = (Int(aDiff) / 60) % 60;
            let nHours = (Int(aDiff) / 3600) % 24;
            let nDays = (Int(aDiff) / (3600*24));
            
            if aDiff < 0 {
                sString = NSLocalizedString("now", comment:"");
            }
            else {
                if nDays > 2 {
                    sString = String(format: NSLocalizedString("in %d days", comment:""), nDays)
                }
                else if nDays > 0 {
                    sString = String(format: NSLocalizedString("in %d days, %d hours", comment:""), nDays, nHours)
                }
                else if nHours > 0 {
                    sString = String(format: NSLocalizedString("in %d hours, %d minutes", comment:""), nHours, nMinutes)
                }
                else {
                    sString = String(format: NSLocalizedString("in %d minutes", comment:""), nMinutes)
                }
            }
        }
        if !m_sType.isEmpty {
            if sString.isEmpty {
                sString = m_sType;
            }
            else {
                sString += " (\(m_sType))";
            }
        }
        return sString;
    }
}

//---------------------------------------------------------------------------
// this class is for questions and answers
class CRxQuestionAnswer: NSObject {
    var m_iLevel: Int = 0;     // detail level 0 is "all info", higher value means less info
    var m_sQuestion: String;
    var m_sAnswer: String;
    
    init(q: String, a: String, level: Int?) {
        m_sQuestion = q
        m_sAnswer = a;
        if let l = level {
            m_iLevel = l;
        }
    }
    
    init?(from jsonItem: [String: AnyObject]) { // load from JSON
        if let q = jsonItem["q"] as? String, let a = jsonItem["a"] as? String {
            m_sQuestion = q;
            m_sAnswer = a;
            if let level = jsonItem["lvl"] as? Int {
                m_iLevel = level;
            }
            super.init()
        }
        else {
            return nil;
        }
    }

    func saveToJSON() -> [String: AnyObject] {
        var item: [String: AnyObject] = ["q": m_sQuestion as AnyObject];
        item["a"] = m_sAnswer as AnyObject;
        item["lvl"] = m_iLevel as AnyObject;
        return item;
    }
}

//---------------------------------------------------------------------------
enum CRxCategory: String {
    case informace, lekarna, prvniPomoc, policie, havarie, wc
    case pamatka, pamatnyStrom, vyznamnyStrom, zajimavost, ohniste
    case remeslnik, restaurace, obchod
    case children, sport, associations
    case waste, wasteElectro, wasteTextile, wasteGeneral, wasteSeparated
    case nehoda, uzavirka
}

//---------------------------------------------------------------------------
class CRxEventRecord: NSObject {
    var m_sTitle: String = ""
    var m_sInfoLink: String?
    var m_sBuyLink: String?
    var m_eCategory: String?
    var m_sFilter: String?  // filter records accoring to this member
    var m_sText: String?
    var m_sIllustrationImgLink: String? // link to illustration image
    var m_aDate: Date?      // date and time of an event start or publish date of an article
    var m_aDateTo: Date?    // date and time of an evend end
    var m_sAddress: String? // location address
    var m_aLocation: CLLocation?    // event location
    var m_aLocCheckIn: CLLocation?  // location for game check-in (usually not preset)
    var m_sPhoneNumber: String?
    var m_sPhoneMobileNumber: String?
    var m_sEmail: String?
    var m_sContactNote: String?
    var m_arrOpeningHours: [CRxHourInterval]?
    var m_arrEvents: [CRxEventInterval]?
    var m_arrQa: [CRxQuestionAnswer]?

    // members for display only, not stored or read in the record
    var m_distFromUser: CLLocationDistance = Double.greatestFiniteMagnitude;
    var m_bMarkFavorite: Bool = false;      // saved news, marked dumpsters
    
    init(title sTitle: String) {
        m_sTitle = sTitle
        super.init()
    }
    
    static func loadDate(string: String) -> Date? {
        let df = DateFormatter();
        df.dateFormat = "yyyy-MM-dd'T'HH:mm";
        return df.date(from: string);
    }
    
    static func saveDate(date: Date) -> String {
        let df = DateFormatter();
        df.dateFormat = "yyyy-MM-dd'T'HH:mm";
        return df.string(from: date);
    }
    
    //---------------------------------------------------------------------------
    init?(from jsonItem: [String: AnyObject]) { // load from JSON
        
        if let title = jsonItem["title"] as? String { m_sTitle = title }
        if m_sTitle.isEmpty { return nil }
        
        if let infoLink = jsonItem["infoLink"] as? String { m_sInfoLink = infoLink }
        if let buyLink = jsonItem["buyLink"] as? String { m_sBuyLink = buyLink }
        if let category = jsonItem["category"] as? String { m_eCategory = category; }
        if let filter = jsonItem["filter"] as? String { m_sFilter = filter }
        if let text = jsonItem["text"] as? String { m_sText = text }
        if let illustration = jsonItem["illustrationImgLink"] as? String { m_sIllustrationImgLink = illustration }
        if let phone = jsonItem["phone"] as? String { m_sPhoneNumber = phone }
        if let phone = jsonItem["phoneMobile"] as? String { m_sPhoneMobileNumber = phone }
        if let email = jsonItem["email"] as? String { m_sEmail = email }
        if let contactNote = jsonItem["contactNote"] as? String { m_sContactNote = contactNote }
        if let address = jsonItem["address"] as? String { m_sAddress = address }
        if let date = jsonItem["date"] as? String { m_aDate = CRxEventRecord.loadDate(string: date); }
        if let dateTo = jsonItem["dateTo"] as? String { m_aDateTo = CRxEventRecord.loadDate(string: dateTo); }

        if let locationLat = jsonItem["locationLat"] as? String,
            let locationLong = jsonItem["locationLong"] as? String,
            let dLocLat = Double(locationLat),
            let dLocLong = Double(locationLong) { m_aLocation = CLLocation(latitude: dLocLat, longitude: dLocLong) }
        
        if let locationLat = jsonItem["checkinLocationLat"] as? String,
            let locationLong = jsonItem["checkinLocationLong"] as? String,
            let dLocLat = Double(locationLat),
            let dLocLong = Double(locationLong) { m_aLocCheckIn = CLLocation(latitude: dLocLat, longitude: dLocLong) }
        
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
            var arrEvents = [CRxEventInterval]();
            let lstEvents = events.components(separatedBy: "|");
            for it in lstEvents {
                if let interval = CRxEventInterval(from: it) {
                    arrEvents.append(interval)
                }
            }
            if arrEvents.count > 0 {
                m_arrEvents = arrEvents.sorted(by: { $0.m_dateStart < $1.m_dateStart });
            }
        }
        if let qas = jsonItem["qa"] as? [[String: AnyObject]] {
            var arrQa = [CRxQuestionAnswer]();
            for jsonQaItem in qas {
                if let item = CRxQuestionAnswer(from: jsonQaItem) {
                    arrQa.append(item);
                }
            }
            if arrQa.count > 0 {
                m_arrQa = arrQa;
            }
        }
    }
    
    //---------------------------------------------------------------------------
    func saveToJSON() -> [String: AnyObject] {
        var item: [String: AnyObject] = ["title": m_sTitle as AnyObject]
        if let infoLink = m_sInfoLink { item["infoLink"] = infoLink as AnyObject }
        if let buyLink = m_sBuyLink { item["buyLink"] = buyLink as AnyObject }
        if let category = m_eCategory { item["category"] = category as AnyObject }
        if let filter = m_sFilter { item["filter"] = filter as AnyObject }
        if let text = m_sText { item["text"] = text as AnyObject }
        if let illustration = m_sIllustrationImgLink { item["illustrationImgLink"] = illustration as AnyObject }
        if let phone = m_sPhoneNumber { item["phone"] = phone as AnyObject }
        if let phone = m_sPhoneMobileNumber { item["phoneMobile"] = phone as AnyObject }
        if let email = m_sEmail { item["email"] = email as AnyObject }
        if let contactNote = m_sContactNote { item["contactNote"] = contactNote as AnyObject }
        if let address = m_sAddress { item["address"] = address as AnyObject }
        if let date = m_aDate { item["date"] = CRxEventRecord.saveDate(date: date) as AnyObject }
        if let dateTo = m_aDateTo { item["dateTo"] = CRxEventRecord.saveDate(date: dateTo) as AnyObject }
        
        if let location = m_aLocation {
            item["locationLat"] = String(location.coordinate.latitude) as AnyObject
            item["locationLong"] = String(location.coordinate.longitude) as AnyObject
        }
        
        if let location = m_aLocCheckIn {
            item["checkinLocationLat"] = String(location.coordinate.latitude) as AnyObject
            item["checkinLocationLong"] = String(location.coordinate.longitude) as AnyObject
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
        if let qas = m_arrQa {
            var jsonQaItems = [AnyObject]()
            for qaItem in qas {
                jsonQaItems.append(qaItem.saveToJSON() as AnyObject);
            }
            if jsonQaItems.count > 0 {
                item["qa"] = jsonQaItems as AnyObject;
            }
        }
        
        return item;
    }
    
    //---------------------------------------------------------------------------
    static func categoryLocalName(category: String?) -> String {
        guard let category = category else {
            return "";
        }
        if let cat = CRxCategory(rawValue: category) {
            switch cat {
            case .informace: return NSLocalizedString("Information", comment: "");
            case .lekarna: return NSLocalizedString("Pharmacies", comment: "");
            case .prvniPomoc: return NSLocalizedString("First Aid", comment: "");
            case .policie: return NSLocalizedString("Police", comment: "");
            case .havarie: return NSLocalizedString("Faults", comment: "");
            case .wc: return NSLocalizedString("Toilets", comment: "");
            case .pamatka: return NSLocalizedString("Landmarks", comment: "");
            case .pamatnyStrom: return NSLocalizedString("Memorial Trees", comment: "");
            case .vyznamnyStrom: return NSLocalizedString("Significant Trees", comment: "");
            case .zajimavost: return NSLocalizedString("Points of Interest", comment: "");
            case .ohniste: return NSLocalizedString("Campfire", comment: "");
            case .remeslnik: return NSLocalizedString("Artisans", comment: "");
            case .restaurace: return NSLocalizedString("Restaurants", comment: "");
            case .obchod: return NSLocalizedString("Shops", comment: "");
            case .children: return NSLocalizedString("For Families", comment: "");
            case .sport: return NSLocalizedString("Sport", comment: "");
            case .associations: return NSLocalizedString("Associations", comment: "");
            case .waste: return NSLocalizedString("Waste Dumpsters", comment: "");
            case .wasteElectro: return NSLocalizedString("Electric Waste", comment: "");
            case .wasteTextile: return NSLocalizedString("Textile Waste", comment: "");
            case .wasteSeparated: return NSLocalizedString("Separated Waste", comment: "");
            case .wasteGeneral: return NSLocalizedString("Waste", comment: "");
            case .nehoda: return NSLocalizedString("Accident", comment: "");
            case .uzavirka: return NSLocalizedString("Roadblock", comment: "");
            }
        }
        else {
            return category;    // not in enum
        }
    }

    //---------------------------------------------------------------------------
    static func categoryIconName(category: String) -> String {
        if let cat = CRxCategory(rawValue: category) {
            switch cat {
            case .informace: return "c_info";
            case .lekarna: return "c_pharmacy";
            case .prvniPomoc: return "c_firstaid";
            case .policie: return "c_police";
            case .havarie: return "c_work";
            case .wc: return "c_toilet";
            case .pamatka: return "c_monument";
            case .pamatnyStrom: return "c_tree";
            case .vyznamnyStrom: return "c_tree";
            case .zajimavost: return "c_trekking";
            case .ohniste: return "c_campfire";
            case .remeslnik: return "c_work";
            case .restaurace: return "c_restaurant";
            case .obchod: return "c_shop";
            case .children: return "c_children";
            case .sport: return "c_sport";
            case .associations: return "c_usergroups";
            case .waste: return "c_waste";
            case .wasteElectro: return "c_electrical";
            case .wasteTextile: return "c_textile";
            case .wasteGeneral: return "c_recycle";
            case .wasteSeparated: return "c_recycle";
            case .nehoda: return "c_accident";
            case .uzavirka: return "c_roadblock";
            }
        }
        else {
            return "";
        }
    }

    //---------------------------------------------------------------------------
    func infoLinkUrl() -> URL? {
        if let link = m_sInfoLink {
            var sParameter: String = "";
            if let linkUtm = CRxAppDefinition.shared.m_sOutgoingLinkParameter {
                if link.contains("?") {
                    sParameter = "&";
                }
                else {
                    sParameter = "?";
                }
                sParameter += linkUtm;
            }
            return URL(string: link + sParameter);
        }
        return nil;
    }
    
    //---------------------------------------------------------------------------
    func openInfoLink(fromCtl sender: UIViewController?) {
        if let url = infoLinkUrl() {
            CRxEventRecord.openWebUrl(url, fromCtl: sender);
        }
    }
    
    //---------------------------------------------------------------------------
    func openBuyLink(fromCtl sender: UIViewController?) {
        if let link = m_sBuyLink,
            let url = URL(string: link) {
            CRxEventRecord.openWebUrl(url, fromCtl: sender);
        }
    }

    //---------------------------------------------------------------------------
    static func openWebUrl(_ url: URL, fromCtl: UIViewController?) {
        if let senderViewCtl = fromCtl, let scheme = url.scheme, (scheme == "http" || scheme == "https")  {
            let safariCtl = SFSafariViewController(url: url);
            if #available(iOS 10.0, *) {
                safariCtl.preferredBarTintColor = UIColor(red: 23.0/255.0, green: 37.0/255.0, blue: 96.0/255.0, alpha: 1.0);
                safariCtl.preferredControlTintColor = UIColor(white: 1.0, alpha: 1.0);
            }
            senderViewCtl.present(safariCtl, animated: true, completion: nil);
        }
        else {
            UIApplication.shared.open(url);
        }
    }
    
    //---------------------------------------------------------------------------
    static func openWebUrl(_ url: URL, inDataSource: CRxDataSource?, fromCtl: UIViewController?) {
        if let scheme = url.scheme, scheme == "applewebdata", let ds = inDataSource, let baseUrl = ds.m_sLinkBaseUrl  {
            var newPath = url.path;
            if let query = url.query {
                newPath = newPath + "?" + query;
            }
            let newUrl = URL.init(string: baseUrl + newPath);
            if let newUrl = newUrl {
                CRxEventRecord.openWebUrl(newUrl, fromCtl: fromCtl);
                return;
            }
        }
        CRxEventRecord.openWebUrl(url, fromCtl: fromCtl);
    }

    //---------------------------------------------------------------------------
    func recordHash() -> String {
        var sHash = m_sTitle;
        if let date = m_aDate {
            sHash += String(date.timeIntervalSinceReferenceDate);
        }
        return sHash;
    }
    
    //---------------------------------------------------------------------------
    func gameCheckInLocation() -> CLLocation? {
        if m_aLocCheckIn != nil {
            return m_aLocCheckIn;
        }
        return m_aLocation;
    }
    
    //---------------------------------------------------------------------------
    func nextEventOccurence() -> CRxEventInterval? {
        guard let events = m_arrEvents
            else { return nil; }
        // find next container at this location (intervals are pre-sorted)
        let dayToday = Date();
        
        var iBest = 0;
        for aInt in events {
            if aInt.m_dateEnd > dayToday {
                break;
            }
            iBest += 1;
        }
        if iBest >= events.count {
            iBest = events.count-1;  // not found, show last past
        }
        return events[iBest];
    }
    
    //---------------------------------------------------------------------------
    func nextEventOccurenceString() -> String? {
        if let aInt = nextEventOccurence() {
            return aInt.toRelativeIntervalString();
        }
        return nil;
    }

    //---------------------------------------------------------------------------
    func currentEvent() -> CRxEventInterval? {
        guard let events = m_arrEvents
            else { return nil; }
        // find current event (intervals are pre-sorted)
        let dayToday = Date();
        
        for aInt in events {
            if aInt.m_dateStart <= dayToday && dayToday <= aInt.m_dateEnd {
                return aInt;
            }
        }
        return nil;
    }

    //---------------------------------------------------------------------------
    func todayOpeningHoursString() -> String? {
        let dtc = Calendar.current.dateComponents([.weekday], from: Date());
        guard let hours = m_arrOpeningHours,
            var iWeekday = dtc.weekday
            else { return nil; }

        iWeekday -= 1;
        if iWeekday <= 0 {
            iWeekday += 7;
        }

        var sString = "";
        for aInt in hours {
            if aInt.m_weekday == iWeekday {
                if sString.isEmpty {
                    sString = aInt.toIntervalDisplayString();
                }
                else {
                    sString += " " + aInt.toIntervalDisplayString();
                }
            }
        }
        if sString.isEmpty {
            return NSLocalizedString("closed today", comment: "");
        }
        return NSLocalizedString("today", comment: "") + " " + sString;
    }
    
    //---------------------------------------------------------------------------
    func containsSearch(expression sExpr: String) -> Bool {
        if m_sTitle.range(of: sExpr, options: [.caseInsensitive, .diacriticInsensitive], range: nil, locale: Locale.current) != nil {
            return true;
        }
        if let cat = m_eCategory {
            if CRxEventRecord.categoryLocalName(category: cat).range(of: sExpr, options: [.caseInsensitive, .diacriticInsensitive], range: nil, locale: Locale.current) != nil {
                return true;
            }
        }
        if let filter = m_sFilter {
            if filter.range(of: sExpr, options: [.caseInsensitive, .diacriticInsensitive], range: nil, locale: Locale.current) != nil {
                return true;
            }
        }
        if let text = m_sText {
            if text.range(of: sExpr, options: [.caseInsensitive, .diacriticInsensitive], range: nil, locale: Locale.current) != nil {
                return true;
            }
        }
        return false;
    }
    //---------------------------------------------------------------------------
    func hasHtmlText() -> Bool {
        if let text = m_sText {
            return text.hasPrefix("<div") || text.hasPrefix("<dl")
        }
        return false;
    }
}

//--------------------------------------------------------------------------

