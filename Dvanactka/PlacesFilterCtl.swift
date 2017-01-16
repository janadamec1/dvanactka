//
//  PlacesFilterCtl.swift
//  Dvanactka
//
//  Created by Jan Adamec on 09.12.16.
//  Copyright © 2016 Jan Adamec. All rights reserved.
//

import UIKit

class PlacesFilterCtl: UITableViewController {
    var m_aDataSource: CRxDataSource?
    var m_arrFilter = [String]();

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let ds = m_aDataSource {
            
            self.title = ds.m_sTitle;
            
            // get the list of filter items
            var arrFilter = [String]();
            for rec in ds.m_arrItems {
                if let sFilter = rec.m_sFilter {
                    if !arrFilter.contains(sFilter) {
                        arrFilter.append(sFilter);
                    }
                }
            }
            m_arrFilter = arrFilter.sorted();
            
            var arrBtnItems = [UIBarButtonItem]();
            if ds.m_eType == .places {
                // init location tracking
                arrBtnItems.append(UIBarButtonItem(title: NSLocalizedString("Map", comment: ""), style: .plain, target: self, action: #selector(PlacesFilterCtl.showMap)));
            }
            if arrBtnItems.count > 0 {
                self.navigationItem.setRightBarButtonItems(arrBtnItems, animated: false);
            }
        }

    }

    //--------------------------------------------------------------------------
    // MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    //--------------------------------------------------------------------------
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return m_arrFilter.count
    }

    //--------------------------------------------------------------------------
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cellPlacesFilter", for: indexPath)
        cell.textLabel?.text = m_arrFilter[indexPath.row];
        return cell
    }
    
    //--------------------------------------------------------------------------
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let eventCtl = storyboard.instantiateViewController(withIdentifier: "eventCtl") as! EventsCtl
        eventCtl.m_aDataSource = m_aDataSource;
        eventCtl.m_sParentFilter = m_arrFilter[indexPath.row];
        navigationController?.pushViewController(eventCtl, animated: true);
    }
    
    //--------------------------------------------------------------------------
    func showMap() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let mapCtl = storyboard.instantiateViewController(withIdentifier: "mapCtl") as! MapCtl
        mapCtl.m_aDataSource = m_aDataSource;
        navigationController?.pushViewController(mapCtl, animated: true);
    }
}
