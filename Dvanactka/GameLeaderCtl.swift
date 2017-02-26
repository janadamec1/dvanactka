//
//  GameLeaderCtl.swift
//  Dvanactka
//
//  Created by Jan Adamec on 24.02.17.
//  Copyright © 2017 Jan Adamec. All rights reserved.
//

import UIKit

class CRxBoardItem : NSObject {
    var m_iPlaceFrom: Int = 0;
    var m_iPlaceTo: Int = 0;
    var m_iScore: Int;
    
    init(score: Int) {
        m_iScore = score;
        super.init();
    }
}

class GameLeaderCtl: UITableViewController {
    
    var m_arrItems = [CRxBoardItem]();
    var m_sMyUuid: String?
    var m_iMyScore: Int = 0;
    var m_bLoading: Bool = true;

    override func viewDidLoad() {
        super.viewDidLoad();

        self.title = NSLocalizedString("Leaderboard", comment: "");
        
        m_iMyScore = CRxGame.sharedInstance.m_iPoints;
        if let aDS = CRxGame.dataSource() {
            m_sMyUuid = aDS.m_sUuid;
        }
        
        // start downloading leaderboard
        let url = URL(string: "https://dvanactka.info/own/p12/game_leaders.txt");
        if let url = url {
            CRxDataSourceManager.getDataFromUrl(url: url) { (data, response, error) in
                guard let data = data, error == nil
                    else {
                        if let error = error {
                            print("URL downloading failed: \(error.localizedDescription)");
                        }
                        DispatchQueue.main.async() { () -> Void in
                            self.showDownloadError();
                        }
                        return;
                }
                
                // process the data
                self.loadTableFrom(data: data);
                
                DispatchQueue.main.async() { () -> Void in
                    self.m_bLoading = false;
                    self.tableView.reloadData();
                }
            }
        }
    }

    //---------------------------------------------------------------------------
    // MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1;
    }

    //---------------------------------------------------------------------------
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if m_bLoading {
            return 1;
        }
        return m_arrItems.count;
    }

    //---------------------------------------------------------------------------
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cellBoard", for: indexPath);
        
        if m_bLoading {
            cell.textLabel?.text = NSLocalizedString("Downloading data...", comment: "");
            cell.detailTextLabel?.text = "";
            let spinner = UIActivityIndicatorView(activityIndicatorStyle: .gray);
            spinner.frame = CGRect(x:0, y:0, width:24, height:24);
            spinner.startAnimating();
            cell.accessoryView = spinner;
            return cell;
        }
        
        let item = m_arrItems[indexPath.row];
        var sPlace = "";
        if item.m_iPlaceFrom != item.m_iPlaceTo {
            sPlace = String(format: "%d. - %d.", item.m_iPlaceFrom, item.m_iPlaceTo);
        }
        else {
            sPlace = String(format: "%d.", item.m_iPlaceFrom);
        }
        let bIsPlayer = (item.m_iScore == m_iMyScore);
        if bIsPlayer {
            sPlace += " <-- " + NSLocalizedString("YOU", comment: "");
        }
        cell.textLabel?.text = sPlace;
        cell.detailTextLabel?.text = String(format: "%d XP", item.m_iScore);
        
        let cl = UIColor(white: bIsPlayer ? 1.0 : 0.85, alpha: 1.0);
        cell.textLabel?.textColor = cl;
        cell.detailTextLabel?.textColor = cl;
        
        cell.accessoryView = nil;
        return cell;
    }
    
    //---------------------------------------------------------------------------
    func loadTableFrom(data: Data) {
        guard let sData = String(data: data, encoding: .utf8)
            else { return; }
        var bPlayerFound = false;
        var arrNewItems = [CRxBoardItem]();
        let lines = sData.components(separatedBy: .newlines);
        for line in lines {
            let lineItems = line.components(separatedBy: "|");
            if lineItems.count < 2 {
                continue;
            }
            if let iScore = Int(lineItems[1]) {
                let aNewItem = CRxBoardItem(score: iScore);
                arrNewItems.append(aNewItem);
                
                if let sPlayerUuid = m_sMyUuid,
                    sPlayerUuid == lineItems[0] {
                    bPlayerFound = true;
                }
            }
        }
        if !bPlayerFound && m_iMyScore > 0 {
            arrNewItems.append(CRxBoardItem(score: m_iMyScore));
        }
        
        m_arrItems.removeAll();
        if arrNewItems.count > 0 {
            // sort by score
            var arrSortedItems: [CRxBoardItem] = arrNewItems.sorted(by: {$0.m_iScore > $1.m_iScore; });
            // calc places and filter out places with same score
            var arrFilteredItems = [CRxBoardItem]();
            var iPrevScore: Int = 99999999;
            for i in 0...arrSortedItems.count-1 {
                let aItem = arrSortedItems[i];
                if aItem.m_iScore != iPrevScore {
                    aItem.m_iPlaceFrom = i+1;
                    iPrevScore = aItem.m_iScore;
                    arrFilteredItems.append(aItem);
                }
            }
            // set shared place number
            var iPlayerIdx = 0;
            for i in 0...arrFilteredItems.count-1 {
                let aItem = arrFilteredItems[i];
                if aItem.m_iScore == m_iMyScore {
                    iPlayerIdx = i;
                }
                if i < arrFilteredItems.count-1 {
                    aItem.m_iPlaceTo = arrFilteredItems[i+1].m_iPlaceFrom - 1;
                }
                else {  // last item
                    aItem.m_iPlaceTo = arrSortedItems.count;
                }
            }
            // show only a few records above and below the player (iPlayerIdx)
            for i in 0...arrFilteredItems.count-1 {
                if (iPlayerIdx <= 6 && i < 10)           // at the top, show first 10 items)
                        || (iPlayerIdx > 4 && (i==0 || abs(i-iPlayerIdx) <= 4)) {   // below, show first and then 9 around player
                    m_arrItems.append(arrFilteredItems[i]);
                }
            }
        }
    }
    
    //---------------------------------------------------------------------------
    func showDownloadError() {
        let alertController = UIAlertController(title: nil, message: NSLocalizedString("Error when downloading data", comment: ""), preferredStyle: .alert);
        let actionOK = UIAlertAction(title: "OK", style: .cancel, handler: { (result : UIAlertAction) -> Void in
            self.dismiss(animated: true, completion: nil);  // go back to GameCtl
        });
        alertController.addAction(actionOK);
        self.present(alertController, animated: true, completion: nil);
    }
    
    //---------------------------------------------------------------------------
    @IBAction func OnBtnDone(_ sender: Any) {
        dismiss(animated: true, completion: nil);
    }
}
