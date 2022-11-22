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
import MapKit
import MessageUI
import EventKit
import EventKitUI
import SDWebImage

protocol CRxDetailRefreshParentDelegate {
    func detailRequestsRefresh();
}

class NewsCell: UITableViewCell {
    @IBOutlet weak var m_lbTitle: UILabel!
    @IBOutlet weak var m_lbText: UILabel!
    @IBOutlet weak var m_imgIllustration: UIImageView!
    @IBOutlet weak var m_lbDate: UILabel!
    @IBOutlet weak var m_btnWebsite: UIButton!
    @IBOutlet weak var m_btnFavorite: UIButton!
    @IBOutlet weak var m_btnAction: UIButton!
}
class EventCell: UITableViewCell {
    @IBOutlet weak var m_lbTitle: UILabel!
    @IBOutlet weak var m_lbAddress: UILabel!
    @IBOutlet weak var m_lbText: UILabel!
    @IBOutlet weak var m_lbDate: UILabel!
    @IBOutlet weak var m_btnWebsite: UIButton!
    @IBOutlet weak var m_btnBuy: UIButton!
    @IBOutlet weak var m_btnAddToCalendar: UIButton!
    @IBOutlet weak var m_stackContact: UIStackView!
    @IBOutlet weak var m_lbContact: UILabel!
    @IBOutlet weak var m_btnEmail: UIButton!
    @IBOutlet weak var m_btnPhone: UIButton!
}
class PlaceCell: UITableViewCell {
    @IBOutlet weak var m_lbTitle: UILabel!
    @IBOutlet weak var m_lbText: UILabel!
    @IBOutlet weak var m_imgIcon: UIImageView!
}
class FilterCell: UITableViewCell {
    @IBOutlet weak var m_lbTitle: UILabel!
}

class EventsCtl: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate, UISearchResultsUpdating, CLLocationManagerDelegate, EKEventEditViewDelegate, MFMailComposeViewControllerDelegate, CRxDataSourceRefreshDelegate, CRxDetailRefreshParentDelegate, CRxFilterChangeDelegate {
    
    @IBOutlet weak var m_searchBar: UISearchBar!
    @IBOutlet weak var m_tableView: UITableView!
    @IBOutlet weak var m_viewFooter: UIView!
    @IBOutlet weak var m_lbFooterText: UILabel!
    @IBOutlet weak var m_btnFooterButton: UIButton!
    
    var m_refreshCtl: UIRefreshControl!
    
    // input:
    var m_aDataSource: CRxDataSource?
    var m_bAskForFilter: Bool = false      // do not show items, present filter possibilites to pass next as ParentFilter
    var m_sParentFilter: String?           // show only items with this filter (for ds with filterAsParentView)
    var m_sSearchString: String?           // if not nil, use it as search string
    var m_searchController: UISearchController!
    
    // member variables:
    var m_orderedItems = [String : [CRxEventRecord]]()  // category localName -> array of records
    var m_orderedCategories = [String]()                // sorted category local names
    var m_arrFilterSelection = [String]();              // array when asing for filter (m_bAskForFilter). Used instead of orderedItems
    var m_locManager = CLLocationManager();
    var m_coordLast = CLLocationCoordinate2D(latitude:0, longitude: 0);
    var m_bUserLocationAcquired = false;

    var m_refreshParentDelegate: CRxDetailRefreshParentDelegate?;
    
    override func viewDidLoad() {
        super.viewDidLoad()

        m_refreshCtl = UIRefreshControl();
        m_refreshCtl.attributedTitle = NSAttributedString(string: stringWithLastUpdateDate());
        m_refreshCtl.addTarget(self, action:#selector(downloadData), for:.valueChanged);
        if #available(iOS 10.0, *) {
            m_tableView.refreshControl = m_refreshCtl;
        } else {
            m_tableView.backgroundView = m_refreshCtl;
        }
        
        m_searchBar.isHidden = true;

        var bAddSearchToolbarButton = true;
        if #available(iOS 11.0, *) {
            bAddSearchToolbarButton = false;
            m_searchController = UISearchController(searchResultsController: nil);
            m_searchBar.removeFromSuperview();      // tableView must be directly after navigationItem, hiding searchBar is not enough
            m_searchController.searchResultsUpdater = self
            m_searchController.hidesNavigationBarDuringPresentation = false;
            m_searchController.dimsBackgroundDuringPresentation = false;
            m_searchController.searchBar.sizeToFit();
            m_searchController.searchBar.tintColor = UIColor.white;
            //UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).defaultTextAttributes = convertToNSAttributedStringKeyDictionary([NSAttributedString.Key.foregroundColor.rawValue: UIColor.white]);
            UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).defaultTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white];
            
            self.navigationItem.searchController = m_searchController
            self.definesPresentationContext = true
        }
        else {
            m_refreshCtl.backgroundColor = UIColor(red:131.0/255.0, green:156.0/255.0, blue:192.0/255.0, alpha:1.0);
        }
        
        m_locManager.delegate = self;
        m_locManager.distanceFilter = 5;

        if let ds = m_aDataSource {
            if let sParentFilter = m_sParentFilter {
                self.title = sParentFilter;
            }
            else {
                self.title = ds.m_sTitle;
            }
            
            var arrBtnItems = [UIBarButtonItem]();
            if ds.m_bMapEnabled {
                // init location tracking
                arrBtnItems.append(UIBarButtonItem(title: NSLocalizedString("Map", comment: ""), style: .plain, target: self, action: #selector(EventsCtl.showMap)));

                if CLLocationManager.authorizationStatus() == .authorizedWhenInUse {
                    m_locManager.startUpdatingLocation();
                }
            } else if ds.m_eType == .news && ds.m_sId != CRxDataSourceManager.dsSavedNews {
                // link to saved news
                arrBtnItems.append(UIBarButtonItem(image: UIImage(named: "star"), style: .plain, target: self, action: #selector(EventsCtl.onSavedNews)));
            }
            if ds.m_bFilterable {
                arrBtnItems.append(UIBarButtonItem(image: UIImage(named: "filter"), style: .plain, target: self, action: #selector(EventsCtl.onDefineFilter)));
            }
            if bAddSearchToolbarButton {
                arrBtnItems.append(UIBarButtonItem(image: UIImage(named: "search"), style: .plain, target: self, action: #selector(EventsCtl.showSearch)));
            }
            if arrBtnItems.count > 0 {
                self.navigationItem.setRightBarButtonItems(arrBtnItems, animated: false);
            }
            m_tableView.rowHeight = UITableView.automaticDimension;
            m_tableView.estimatedRowHeight = 90.0;
            
            // footer
            if !ds.m_bListingFooterVisible {
                m_viewFooter.isHidden = true;
            }
            else {
                if let sCustomLabelText = ds.m_sListingFooterCustomLabelText {
                    m_lbFooterText.text = sCustomLabelText;
                }
                else {
                    m_lbFooterText.text = NSLocalizedString("Add record:", comment: "");
                }
                if let sCustomButtonText = ds.m_sListingFooterCustomButtonText {
                    m_btnFooterButton.setTitle(sCustomButtonText, for: .normal);
                }
                else if let email = CRxAppDefinition.shared.recordUpdateEmail() {
                    m_btnFooterButton.setTitle(email, for: .normal);
                }
            }
        }
        setRecordsDistance();
        sortRecords();
        
        // start with search bar visible in some cases
        if let ds = m_aDataSource {
            if ds.m_bListingSearchBarVisibleAtStart {
                if #available(iOS 11.0, *) {
                    self.navigationItem.hidesSearchBarWhenScrolling = false;
                }
            }
        }
    }
    
    //--------------------------------------------------------------------------
    deinit {
        if let ds = m_aDataSource {
            ds.delegate = nil;
        }
    }
    
    //--------------------------------------------------------------------------
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated);

        if #available(iOS 11.0, *) {
            self.navigationItem.hidesSearchBarWhenScrolling = true;
        }

        // clear selection when returning
        if let selIndexPath = m_tableView.indexPathForSelectedRow {
            m_tableView.deselectRow(at: selIndexPath, animated: animated);
        }
        
        guard let ds = m_aDataSource else { return }
        if ds.m_bIsBeingRefreshed {
            ds.delegate = self;
            
            // show refresh ctl, has to be when UI is visible (thus viewDidAppear)
            m_refreshCtl.beginRefreshing();
            //m_tableView.contentOffset = CGPoint(x:0, y:m_tableView.contentOffset.y-refreshCtl.frame.size.height);
            UIView.animate(withDuration: 0.25, delay: 0, options: .beginFromCurrentState, animations: {
                self.m_tableView.contentOffset = CGPoint(x:0, y:self.m_tableView.contentOffset.y-self.m_refreshCtl.frame.size.height);}
            );
        }
    }
    
    //--------------------------------------------------------------------------
    func sortRecords() {
        guard let ds = m_aDataSource else { return }
        
        m_orderedItems.removeAll();
        m_orderedCategories.removeAll();
        
        m_tableView.allowsSelection = (ds.m_eType == .places || ds.m_eType == .questions || isAskForFilterActive());
        let bAskingForFilter = isAskForFilterActive();
        if bAskingForFilter {
            var arrFilter = [String]();
            for rec in ds.m_arrItems {
                if let sFilter = rec.m_sFilter {
                    if !arrFilter.contains(sFilter) {
                        arrFilter.append(sFilter);
                    }
                }
            }
            if ds.m_eType == .questions {
                m_arrFilterSelection = arrFilter;
            }
            else {
                m_arrFilterSelection = arrFilter.sorted();
            }
            m_orderedCategories.append(NSLocalizedString("Subcategories", comment: ""));
        }
        
        let df = DateFormatter();
        df.dateStyle = .full;
        df.timeStyle = .none;
        let today = Date();
        
        var arrDateCategories = [Date]();
        
        // first add objects to groups
        for rec in ds.m_arrItems {
            // favorities
            if ds.m_eType == .news {
                rec.m_bMarkFavorite = (CRxDataSourceManager.shared.findFavorite(news: rec) != nil);
                
            } else if ds.m_eType == .places {
                rec.m_bMarkFavorite = CRxDataSourceManager.shared.m_setPlacesNotified.contains(rec.m_sTitle);
            }
            
            // filtering by filter set by user
            if ds.m_bFilterable {
                if let setFilter = ds.m_setFilter,
                    let sFilter = rec.m_sFilter {
                    if setFilter.contains(sFilter) {
                        continue;   // skip this record
                    }
                }
            }
            // filtering by category selected in parent tableView
            if ds.m_bFilterAsParentView && !bAskingForFilter {
                if rec.m_sFilter == nil {
                    continue;   // records without filter are shown in the parent tableView
                }
                if let sFilter = rec.m_sFilter,
                    let sParentFilter = m_sParentFilter {
                    if sFilter != sParentFilter {
                        continue;
                    }
                }
            }
            if bAskingForFilter && rec.m_sFilter != nil {
                continue;   // when asking for filter, show only records without filter (e.g. dsWaste)
            }
            
            // search
            if let sExpr = m_sSearchString {
                if !rec.containsSearch(expression: sExpr) {
                    continue;
                }
            }
            
            // categories
            var sCatName = "";
            var dateCat: Date?;
            switch ds.m_eType {
            case .news: break;    // one category for news
            case .questions: break;
                
            case .places:
                if ds.m_bGroupByCategory {
                    sCatName = CRxEventRecord.categoryLocalName(category: rec.m_eCategory);
                }
                break;
                
            case .events:   // use date as category
                guard let date = rec.m_aDate else {
                    continue    // remove records without date
                }
                if date < today && rec.m_aDateTo != nil && rec.m_aDateTo! >= today {    // happening now
                    if rec.m_aDateTo!.timeIntervalSince(date) > 24*60*60 {
                        // more then 1 day
                        sCatName = NSLocalizedString("Multi-day events", comment: "");
                        dateCat = date;
                    }
                    else {  // short events happening now
                        sCatName = df.string(from: date);
                        dateCat = date;
                    }
                }
                else if date < today {   // do not show old events
                    continue;
                }
                else {
                    sCatName = df.string(from: date);
                    dateCat = date;
                }
            }
            // categories
            if m_orderedItems[sCatName] == nil {
                m_orderedItems[sCatName] = [rec];   // new category
                m_orderedCategories.append(sCatName);
                
                if dateCat != nil {
                    arrDateCategories.append(dateCat!);
                }
            }
            else {
                m_orderedItems[sCatName]?.append(rec);  // into existing
            }
        }
        
        // sort date categories
        if ds.m_eType == .events {
            let combined = zip(arrDateCategories, m_orderedCategories).sorted {$0.0 < $1.0}
            m_orderedCategories = combined.map {$0.1};
        }
        
        // now sort each group by distance (places) or date (events, news)
        var sortedItems = [String : [CRxEventRecord]]();
        for groupIt in m_orderedItems {
            switch ds.m_eType {
            case .news:
                sortedItems[groupIt.key] = groupIt.value.sorted(by: {$0.m_aDate! > $1.m_aDate! });
            case .events:
                sortedItems[groupIt.key] = groupIt.value.sorted(by: {$0.m_aDate! < $1.m_aDate! });
            case .places:
                sortedItems[groupIt.key] = groupIt.value.sorted(by: {($0.m_bMarkFavorite && !$1.m_bMarkFavorite) || ($0.m_bMarkFavorite == $1.m_bMarkFavorite && $0.m_distFromUser < $1.m_distFromUser) });
            case .questions:
                sortedItems[groupIt.key] = groupIt.value; // no sorting
            }
        }
        m_orderedItems = sortedItems;
        
        // remember last item shown
        if ds.m_eType == .news && ds.m_sId != CRxDataSourceManager.dsSavedNews {
            if let recFirst = ds.m_arrItems.first {
                let sNewRecHash = recFirst.recordHash();
                if sNewRecHash != ds.m_sLastItemShown { // resave only when something changed
                    ds.m_sLastItemShown = sNewRecHash;
                    CRxDataSourceManager.shared.save(dataSource: ds);
                }
            }
        }
    }
    
    //--------------------------------------------------------------------------
    func setRecordsDistance() {
        guard let ds = m_aDataSource else {
            return
        }
        if !m_bUserLocationAcquired {
            return
        }
        let locUser = CLLocation(latitude: m_coordLast.latitude, longitude: m_coordLast.longitude);
        for rec in ds.m_arrItems {
            if let loc = rec.m_aLocation {
                rec.m_distFromUser = loc.distance(from: locUser);
            }
        }
    }
    
    //---------------------------------------------------------------------------
    func stringWithLastUpdateDate() -> String {
        if let ds = m_aDataSource, let date = ds.m_dateLastRefreshed {
            let sTime = DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .short);
            return NSLocalizedString("Last update:", comment: "") + " " + sTime;
        }
        else {
            return NSLocalizedString("Pull main table to refresh", comment:"");
        }
    }

    //---------------------------------------------------------------------------
    @objc func downloadData() {
        if let ds = m_aDataSource {
            ds.delegate = self;
            CRxDataSourceManager.shared.refreshDataSource(id: ds.m_sId, force: true);
        }
    }
    
    //---------------------------------------------------------------------------
    func dataSourceRefreshEnded(dsId: String, error: String?) { // protocol CRxDataSourceRefreshDelegate
        if let ds = m_aDataSource {
            ds.delegate = nil;
        }
        
        if let sErrorText = error {
            m_refreshCtl.attributedTitle = NSAttributedString(string: sErrorText);
            Timer.scheduledTimer(timeInterval: 2, target: m_refreshCtl as Any, selector: #selector(UIRefreshControl.endRefreshing), userInfo: nil, repeats: false);
        }
        else {
            setRecordsDistance();
            sortRecords();
            m_tableView.reloadData();
            m_refreshCtl.attributedTitle = NSAttributedString(string: stringWithLastUpdateDate());
            m_refreshCtl.endRefreshing();
        }
    }
    
    //--------------------------------------------------------------------------
    func detailRequestsRefresh()
    {
        sortRecords();
        m_tableView.reloadData();
    }

    //--------------------------------------------------------------------------
    // MARK: - Table view data source
    func numberOfSections(in tableView: UITableView) -> Int {
        return m_orderedCategories.count;
    }

    //--------------------------------------------------------------------------
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if isAskForFilterActive() && section == 0 {
            return m_arrFilterSelection.count;
        }
        else if let items = m_orderedItems[m_orderedCategories[section]] {
            return items.count;
        }
        else {
            return 0;
        }
    }
    
    //--------------------------------------------------------------------------
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if (m_orderedCategories.count < 2) {
            return nil
        }
        return m_orderedCategories[section];
    }
    
    //--------------------------------------------------------------------------
    func record(at indexPath:IndexPath) -> CRxEventRecord? {
        if indexPath.section >= m_orderedCategories.count {
            return nil;
        }
        if let items = m_orderedItems[m_orderedCategories[indexPath.section]] {
            return items[indexPath.row];
        }
        else {
            return nil;
        }
    }
    
    //--------------------------------------------------------------------------
    func btnTag(from indexPath:IndexPath) -> Int {
        return indexPath.section*10000 + indexPath.row;
    }
    func btnIndexPath(from tag:Int) -> IndexPath {
        return IndexPath(row: tag % 10000, section: tag / 10000);
    }

    //--------------------------------------------------------------------------
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        var cell: UITableViewCell!;
        if isAskForFilterActive() && indexPath.section == 0 {
            let cellFilter = tableView.dequeueReusableCell(withIdentifier: "cellFilter", for: indexPath) as! FilterCell;
            cellFilter.m_lbTitle.text = m_arrFilterSelection[indexPath.row];
            cell = cellFilter;
            return cell;
        }

        guard let rec = record(at: indexPath),
            let ds = m_aDataSource
            else {return UITableViewCell();}

        if ds.m_eType == .news {
            let cellNews = tableView.dequeueReusableCell(withIdentifier: "cellNews", for: indexPath) as! NewsCell
            // Localization
            cellNews.m_btnWebsite.setTitle(NSLocalizedString("Continue reading on website", comment: ""), for: .normal);

            cellNews.m_lbTitle.text = rec.m_sTitle;
            
            let sText = NSMutableAttributedString(string:"");
            if let sRecFilter = rec.m_sFilter {
                let aBoldAttr = [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: cellNews.m_lbText.font.pointSize)];
                sText.append(NSAttributedString(string:sRecFilter, attributes: aBoldAttr));
            }
            if let sRecText = rec.m_sText, !sRecText.isEmpty {
                if sText.length > 0 {
                    sText.append(NSAttributedString(string:" - "));
                }
                sText.append(NSAttributedString(string:sRecText));
            }
            cellNews.m_lbText.attributedText = sText;
            cellNews.m_lbText.isHidden = (sText.length == 0);
 
            var sDateText = "";
            if let aDate = rec.m_aDate {
                let df = DateFormatter();
                df.timeStyle = .none;
                if let aDateTo = rec.m_aDateTo {
                    df.dateStyle = .medium;
                    sDateText += df.string(from: aDate) + " - " + df.string(from: aDateTo);
                }
                else {
                    df.dateStyle = .full;
                    sDateText = df.string(from: aDate);
                }
            }
            cellNews.m_lbDate.text = sDateText

            var bImgPresent = false;
            if let sIllustrLink = rec.m_sIllustrationImgLink, !sIllustrLink.isEmpty {
                bImgPresent = true;
                cellNews.m_imgIllustration.sd_setImage(with: URL(string: sIllustrLink), placeholderImage: nil); // with SDWebImage package (using Swift Package Manager)
            }
            cellNews.m_imgIllustration.isHidden = !bImgPresent;

            cellNews.m_btnWebsite.isHidden = (rec.m_sInfoLink==nil);
            cellNews.m_btnAction.isHidden = (rec.m_sInfoLink==nil);
            cellNews.m_btnFavorite.setImage(UIImage(named: (rec.m_bMarkFavorite ? "goldstar25" : "goldstar25dis")), for: .normal);
            let iBtnTag = btnTag(from: indexPath);
            cellNews.m_btnWebsite.tag = iBtnTag;
            cellNews.m_btnAction.tag = iBtnTag;
            cellNews.m_btnFavorite.tag = iBtnTag;
            cell = cellNews;
        }
        else if ds.m_eType == .events {
            let cellEvent = tableView.dequeueReusableCell(withIdentifier: "cellEvent", for: indexPath) as! EventCell
            // Localization
            cellEvent.m_btnWebsite.setTitle(NSLocalizedString("Website", comment: ""), for: .normal);
            cellEvent.m_btnBuy.setTitle(NSLocalizedString("Buy", comment: ""), for: .normal);
            cellEvent.m_btnAddToCalendar.setTitle(NSLocalizedString("Add to Calendar", comment: ""), for: .normal);
            cellEvent.m_lbContact.text = NSLocalizedString("Contact:", comment: "")
            
            cellEvent.m_lbTitle.text = rec.m_sTitle;
            cellEvent.m_lbText.text = rec.m_sText ?? "";
            cellEvent.m_lbText.isHidden = (rec.m_sText == nil);
            
            if let address = rec.m_sAddress {
                cellEvent.m_lbAddress.text = address.replacingOccurrences(of: "\n", with: ", ");
            }
            cellEvent.m_lbAddress.isHidden = (rec.m_sAddress == nil || !ds.m_bListingShowEventAddress);
            
            var sDateText = "";
            if let aDate = rec.m_aDate {
                let df = DateFormatter();
                df.dateStyle = .none;
                df.timeStyle = .short;
                let calendar = Calendar.current;
                var dtc = calendar.dateComponents([.hour, .minute], from: aDate);
                if dtc.hour! == 0 && dtc.minute == 0 {
                    df.timeStyle = .none;
                }
                sDateText = df.string(from: aDate);
                if let aDateTo = rec.m_aDateTo {
                    dtc = calendar.dateComponents([.year, .month, .day], from: aDate);
                    let dayFrom = calendar.date(from: dtc);
                    dtc = calendar.dateComponents([.year, .month, .day], from: aDateTo);
                    let dayTo = calendar.date(from: dtc);
                    
                    if dayFrom != dayTo {
                        df.dateStyle = .short;
                        sDateText = df.string(from: aDate);
                    }

                    df.timeStyle = .short;
                    dtc = calendar.dateComponents([.hour, .minute], from: aDateTo);
                    if dtc.hour! == 0 && dtc.minute == 0 {
                        df.timeStyle = .none;
                    }
                    sDateText += "\n- " + df.string(from: aDateTo);
                }
            }
            cellEvent.m_lbDate.text = sDateText
            cellEvent.m_btnWebsite.isHidden = (rec.m_sInfoLink==nil);
            cellEvent.m_btnBuy.isHidden = (rec.m_sBuyLink==nil);
            cellEvent.m_btnAddToCalendar.isHidden = (rec.m_aDate==nil);
            
            cellEvent.m_stackContact.isHidden = (rec.m_sEmail == nil && rec.m_sPhoneNumber == nil);
            if !cellEvent.m_stackContact.isHidden {
                if let phone = rec.m_sPhoneNumber {
                    cellEvent.m_btnPhone.setTitle(phone, for: .normal);
                }
                cellEvent.m_btnEmail.isHidden = (rec.m_sEmail==nil);
                cellEvent.m_btnPhone.isHidden = (rec.m_sPhoneNumber==nil);
            }
            
            let iBtnTag = btnTag(from: indexPath);
            cellEvent.m_btnWebsite.tag = iBtnTag;
            cellEvent.m_btnBuy.tag = iBtnTag;
            cellEvent.m_btnAddToCalendar.tag = iBtnTag;
            cellEvent.m_btnEmail.tag = iBtnTag;
            cellEvent.m_btnPhone.tag = iBtnTag;
            cell = cellEvent;
        }
        else if ds.m_eType == .places {
            let cellPlace = tableView.dequeueReusableCell(withIdentifier: "cellPlace", for: indexPath) as! PlaceCell

            var sRecTitle = rec.m_sTitle;
            if (CRxGame.shared.playerWas(at: rec)) {
                sRecTitle += " ✓";
            }

            var bInFuture = false;
            if let date = rec.m_aDate {
                bInFuture = (date > Date());
            }
            var titleTextColor = UIColor(white: 0.5, alpha: 1.0);
            if !bInFuture {
                if #available(iOS 13, *) {
                    titleTextColor = UIColor.label;
                } else {
                    titleTextColor = UIColor.black;
                }
            }
            //cellPlace.m_lbTitle.textColor = UIColor(white: bInFuture ? 0.5 : 0.0, alpha: 1.0);
            cellPlace.m_lbTitle.textColor = titleTextColor;
            
            var bObsolete = false;   // strike-out obsolete accidents
            if let dateTo = rec.m_aDateTo {
                bObsolete = (dateTo < Date());
            }
            let aTitleAttr = (bObsolete ? [NSAttributedString.Key.strikethroughStyle: 2] : nil);
            cellPlace.m_lbTitle.attributedText = NSAttributedString(string: sRecTitle, attributes: aTitleAttr);
            
            var sDistance = "";
            if m_bUserLocationAcquired && rec.m_aLocation != nil {
                let nf = NumberFormatter()
                nf.minimumFractionDigits = 2;
                nf.maximumFractionDigits = 2;
                if rec.m_distFromUser > 1000 {
                    if let km = nf.string(from: NSNumber(value: rec.m_distFromUser/1000.0)) {   // using locale
                        sDistance = "\(km) km";
                    }
                }
                else {
                    sDistance = "\(Int(rec.m_distFromUser)) m";
                }
            }
            var sSubtitle = "";
            if let sNextEvent = rec.nextEventOccurenceString() {
                sSubtitle = sNextEvent;
            }
            else if let sTodayHours = rec.todayOpeningHoursString() {
                sSubtitle = sTodayHours;
            }
            /*else if let cat = rec.m_eCategory {
                sSubtitle = CRxEventRecord.categoryLocalName(category: cat);
            }*/
            else if !rec.hasHtmlText(), let text = rec.m_sText {
                sSubtitle = text;
            }
            if !sSubtitle.isEmpty {
                if !sDistance.isEmpty {
                    sDistance += " | ";
                }
                sDistance += sSubtitle;
            }
            cellPlace.m_lbText.isHidden = sDistance.isEmpty;
            cellPlace.m_lbText.text = sDistance;
            
            if rec.m_bMarkFavorite {
                cellPlace.m_imgIcon.image = UIImage(named: "goldstar25");
            }
            else if let category = rec.m_eCategory {
                cellPlace.m_imgIcon.image = UIImage(named: CRxEventRecord.categoryIconName(category: category));
            }
            else {
                cellPlace.m_imgIcon.image = nil;
            }
            cellPlace.m_imgIcon.isHidden = (cellPlace.m_imgIcon.image == nil);
            cell = cellPlace;
        }
        else if ds.m_eType == .questions {
            let cellFilter = tableView.dequeueReusableCell(withIdentifier: "cellFilter", for: indexPath) as! FilterCell;
            cellFilter.m_lbTitle.text = rec.m_sTitle;
            cell = cellFilter;
            return cell;
        }
        else {
            cell = UITableViewCell();
        }
        
        cell.setNeedsUpdateConstraints();
        cell.updateConstraintsIfNeeded();
        return cell;
    }
    
    //--------------------------------------------------------------------------
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        
        view.tintColor = UIColor(red: 74.0/255.0, green: 125.0/255.0, blue: 185.0/255.0, alpha: 1.0);    // background
        if let header = view as? UITableViewHeaderFooterView {          // text
            header.textLabel?.textColor = .white;
            //header.contentView.backgroundColor = UIColor(red: 36.0/255.0, green: 40.0/255.0, blue: 121.0/255.0, alpha: 1.0);
        }
    }
    
    //--------------------------------------------------------------------------
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil);
        if isAskForFilterActive() && indexPath.section == 0 {
            let eventCtl = storyboard.instantiateViewController(withIdentifier: "eventCtl") as! EventsCtl
            eventCtl.m_aDataSource = m_aDataSource;
            eventCtl.m_sParentFilter = m_arrFilterSelection[indexPath.row];
            navigationController?.pushViewController(eventCtl, animated: true);
        }
        else if let rec = record(at: indexPath), let ds = m_aDataSource {
            if ds.m_eType == .places {
                let placeCtl = storyboard.instantiateViewController(withIdentifier: "placeDetailCtl") as! PlaceDetailCtl;
                placeCtl.m_aDataSource = m_aDataSource;
                placeCtl.m_aRecord = rec;     // addRefs the object, keeps it even when it is deleted in DS during refresh
                placeCtl.m_refreshParentDelegate = self;
                navigationController?.pushViewController(placeCtl, animated: true);
            }
            else if ds.m_eType == .questions {
                let questionsCtl = storyboard.instantiateViewController(withIdentifier: "questionsCtl") as! QuestionsCtl;
                questionsCtl.m_aDataSource = m_aDataSource;
                questionsCtl.m_aRecord = rec;     // addRefs the object, keeps it even when it is deleted in DS during refresh
                navigationController?.pushViewController(questionsCtl, animated: true);

            }
        }
    }

    //--------------------------------------------------------------------------
    @IBAction func onBtnWebsiteTouched(_ sender: Any) {
        if let btn = sender as? UIButton,
            let rec = record(at: btnIndexPath(from: btn.tag)) {
            rec.openInfoLink(fromCtl: self);
        }
    }

    //--------------------------------------------------------------------------
    @IBAction func onBtnWebsiteNewsTouched(_ sender: Any) {
        if let btn = sender as? UIButton,
            let rec = record(at: btnIndexPath(from: btn.tag)) {
            rec.openInfoLink(fromCtl: self);
        }
    }
    
    //--------------------------------------------------------------------------
    @IBAction func onBtnBuyTouched(_ sender: Any) {
        if let btn = sender as? UIButton,
            let rec = record(at: btnIndexPath(from: btn.tag)) {
            rec.openBuyLink(fromCtl: self);
        }
    }
    
    //--------------------------------------------------------------------------
    @IBAction func onBtnActionTouched(_ sender: Any) {
        if let btn = sender as? UIButton,
            let rec = record(at: btnIndexPath(from: btn.tag)) {
            
            var items = [Any]();
            if let sText = rec.m_sText {
                items.append("\(rec.m_sTitle)\n\(sText)" as NSString);
            }
            if let sLink = rec.m_sInfoLink,
                let url = URL(string: sLink) {
                items.append(url as NSURL)
            }
            
            let activityViewController = UIActivityViewController(activityItems: items, applicationActivities: nil);
            present(activityViewController, animated: true, completion: nil)
        }
    }
    
    //--------------------------------------------------------------------------
    func addEventToCalendar(_ title: String, description: String?, location: String?, startDate: Date, endDate: Date) {
        let eventStore = EKEventStore()
        
        eventStore.requestAccess(to: .event, completion: { (granted, error) in
            if (granted) && (error == nil) {
                let event = EKEvent(eventStore: eventStore)
                event.title = title
                event.notes = description
                event.location = location?.replacingOccurrences(of: "\n", with: ", ")
                event.startDate = startDate
                event.endDate = endDate
                event.notes = description
                event.calendar = eventStore.defaultCalendarForNewEvents
                
                let eventController = EKEventEditViewController()
                eventController.eventStore = eventStore
                eventController.editViewDelegate = self
                eventController.event = event
                
                self.present(eventController, animated: true, completion: nil);
            } else {
                let alertController = UIAlertController(title: NSLocalizedString("Access Denied", comment:""),
                                              message: NSLocalizedString("Permission is needed to access the calendar. Go to Settings > Privacy > Calendars to allow access for this app.", comment:""), preferredStyle: .alert);
                let actionOK = UIAlertAction(title: "OK", style: .default, handler: { (result : UIAlertAction) -> Void in
                    print("OK")})
                alertController.addAction(actionOK);
                self.present(alertController, animated: true, completion: nil);
            }
        })
    }
    
    func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
        self.dismiss(animated: true, completion: nil);
    }
    
    //--------------------------------------------------------------------------
    @IBAction func onBtnCalendarTouched(_ sender: Any) {
        if let btn = sender as? UIButton,
            let rec = record(at: btnIndexPath(from: btn.tag)) {
            if let startDate = rec.m_aDate {
                var endDate = rec.m_aDateTo
                if endDate == nil {
                    endDate = startDate.addingTimeInterval(60*60)   // 1 hour
                }
                addEventToCalendar(rec.m_sTitle, description:nil, location:rec.m_sAddress, startDate: startDate, endDate: endDate!);
            }
        }
    }

    //--------------------------------------------------------------------------
    @IBAction func onBtnEmailTouched(_ sender: Any) {
        if let btn = sender as? UIButton,
            let rec = record(at: btnIndexPath(from: btn.tag)),
            let email = rec.m_sEmail {
            
            let mailer = MFMailComposeViewController();
            if mailer == nil { return; }
            mailer.mailComposeDelegate = self;
            
            mailer.setToRecipients(["\(email)"]);
            var sSubject = "Zájem o " + rec.m_sTitle;
            if let date = rec.m_aDate {
                let df = DateFormatter();
                df.dateStyle = .short;
                df.timeStyle = .short;
                sSubject += " @ " + df.string(from: date);
            }
            mailer.setSubject(sSubject);
            
            mailer.modalPresentationStyle = .formSheet;
            present(mailer, animated: true, completion: nil);
        }
    }

    //--------------------------------------------------------------------------
    @IBAction func onBtnPhoneTouched(_ sender: Any) {
        if let btn = sender as? UIButton,
            let rec = record(at: btnIndexPath(from: btn.tag)),
            let phone = rec.m_sPhoneNumber {
            
            let cleanedNumber = phone.replacingOccurrences(of: " ", with: "")
            
            if let url = URL(string: "telprompt://\(cleanedNumber)") {
                UIApplication.shared.open(url);
            }
        }
    }
    
    //--------------------------------------------------------------------------
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let lastLocation = locations.last {
            m_coordLast = lastLocation.coordinate;
            m_bUserLocationAcquired = true;
            
            setRecordsDistance();
            sortRecords();
            m_tableView.reloadData();
        }
    }

    //--------------------------------------------------------------------------
    @objc func showMap() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let mapCtl = storyboard.instantiateViewController(withIdentifier: "mapCtl") as! MapCtl
        mapCtl.m_aDataSource = m_aDataSource;
        mapCtl.m_sParentFilter = m_sParentFilter;
        mapCtl.m_coordLast = m_coordLast;
        navigationController?.pushViewController(mapCtl, animated: true);
    }
    
    //--------------------------------------------------------------------------
    @IBAction func onBtnNewsFavorite(_ sender: Any) {
        if let btn = sender as? UIButton,
            let rec = record(at: btnIndexPath(from: btn.tag)) {
            rec.m_bMarkFavorite = !rec.m_bMarkFavorite;
            btn.setImage(UIImage(named: (rec.m_bMarkFavorite ? "goldstar25" : "goldstar25dis")), for: .normal);
            CRxDataSourceManager.shared.setFavorite(news: rec, set: rec.m_bMarkFavorite);
            
            if let ds = m_aDataSource {
                if ds.m_sId == CRxDataSourceManager.dsSavedNews {
                    m_refreshParentDelegate?.detailRequestsRefresh();
                }
            }
        }
    }
    
    //--------------------------------------------------------------------------
    @objc func onSavedNews() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let eventCtl = storyboard.instantiateViewController(withIdentifier: "eventCtl") as! EventsCtl
        eventCtl.m_aDataSource = CRxDataSourceManager.shared.m_aSavedNews;
        eventCtl.m_refreshParentDelegate = self;
        navigationController?.pushViewController(eventCtl, animated: true);
    }

    //--------------------------------------------------------------------------
    @objc func onDefineFilter() {
        guard let ds = m_aDataSource else { return }
        
        // get the list of filter items
        var arrFilter = [String]();
        for rec in ds.m_arrItems {
            if let sFilter = rec.m_sFilter {
                if !arrFilter.contains(sFilter) {
                    arrFilter.append(sFilter);
                }
            }
        }
        
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let filterCtl = storyboard.instantiateViewController(withIdentifier: "filterCtl") as! FilterCtl
        filterCtl.m_delegate = self;
        filterCtl.m_arrFilter = arrFilter.sorted { $0.localizedCompare($1) == .orderedAscending };
        if let setOut = ds.m_setFilter {
            filterCtl.m_setOut = setOut;
        }
        navigationController?.pushViewController(filterCtl, animated: true);
    }
    
    //--------------------------------------------------------------------------
    func filterChanged(setOut: Set<String>) {
        guard let ds = m_aDataSource else { return }
        ds.m_setFilter = setOut;
        CRxDataSourceManager.shared.save(dataSource: ds);
        sortRecords();
        m_tableView.reloadData();
    }
    
    //--------------------------------------------------------------------------
    @objc func showSearch() {

        if m_searchBar.isHidden {
            UIView.animate(withDuration: 0.25, delay: 0, options: .beginFromCurrentState, animations: {
                self.m_searchBar.isHidden = false;
            });
            m_searchBar.text = "";
            m_searchBar.becomeFirstResponder();
        }
        else {
            m_searchBar.resignFirstResponder();
            UIView.animate(withDuration: 0.25, delay: 0, options: .beginFromCurrentState, animations: {
                self.m_searchBar.isHidden = true;
            });
            m_searchBar.text = "";
            m_sSearchString = nil;
            sortRecords();
            m_tableView.reloadData();
        }
    }

    //--------------------------------------------------------------------------
    func isSearchActive() -> Bool {
        return m_sSearchString != nil;
    }
    
    //--------------------------------------------------------------------------
    func isAskForFilterActive() -> Bool {
        return m_bAskForFilter && !isSearchActive();
    }
    
    //--------------------------------------------------------------------------
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        let bSearchActive = (searchText.count > 1);
        let bWasActive = isSearchActive();
        if !bSearchActive && !bWasActive {
            return;
        }
        else if !bSearchActive && bWasActive {
            m_sSearchString = nil;
        }
        else {
            m_sSearchString = searchText;
        }
        sortRecords();
        m_tableView.reloadData();
    }
    
    //--------------------------------------------------------------------------
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        m_searchBar.resignFirstResponder(); // hide keyboard after Search button pressed
    }
    
    //--------------------------------------------------------------------------
    // from UISearchResultsUpdating
    func updateSearchResults(for searchController: UISearchController) {
        let searchText: String? = searchController.searchBar.text;
        var bSearchActive = searchController.isActive
        if let searchText = searchText {
            bSearchActive = bSearchActive && (searchText.count > 0);
        }
        
        let bWasActive = isSearchActive();
        if !bSearchActive && !bWasActive {
            return;
        }
        else if !bSearchActive && bWasActive {
            m_sSearchString = nil;
        }
        else {
            m_sSearchString = searchText!;
        }
        sortRecords();
        m_tableView.reloadData();
    }

    //--------------------------------------------------------------------------
    @IBAction func onBtnFooterTouched(_ sender: Any) {
        guard let ds = m_aDataSource else { return; }
        if let sFooterCustomButtonTargetUrl = ds.m_sListingFooterCustomButtonTargetUrl,
            let url = URL(string: sFooterCustomButtonTargetUrl) {
            UIApplication.shared.open(url);
        }
        else if MFMailComposeViewController.canSendMail() {

            guard let email = CRxAppDefinition.shared.recordUpdateEmail() else { return; }
            
            let mailer = MFMailComposeViewController();
            if mailer == nil { return; }
            mailer.mailComposeDelegate = self;
            
            mailer.setToRecipients([email]);
            
            var sAppName = "CityApp";
            if let appTitle = CRxAppDefinition.shared.m_sTitle {
                sAppName = appTitle;
            }
            mailer.setSubject("Aplikace " + sAppName + " - přidat záznam");
            
            var sTitle = ds.m_sTitle;
            if let sParentFilter = m_sParentFilter {
                sTitle = sParentFilter;
            }
            mailer.setMessageBody("Data Source: \(sTitle)\n", isHTML: false);
            mailer.modalPresentationStyle = .formSheet;
            present(mailer, animated: true, completion: nil);
        }
    }

    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true, completion: nil);
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToNSAttributedStringKeyDictionary(_ input: [String: Any]) -> [NSAttributedString.Key: Any] {
	return Dictionary(uniqueKeysWithValues: input.map { key, value in (NSAttributedString.Key(rawValue: key), value)})
}
