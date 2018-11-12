/*
 Copyright 2016-2018 Jan Adamec.
 
 This file is part of "Dvanactka".
 
 "Dvanactka" is free software; see the file COPYING.txt,
 included in this distribution, for details about the copyright.
 
 "Dvanactka" is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 ----------------------------------------------------------------------------
 */

import UIKit

protocol CRxFilterChangeDelegate {
    func filterChanged(setOut: Set<String>);
}

class FilterCtl: UITableViewController {
    var m_arrFilter = [String]()
    var m_setOut: Set<String> = [];
    var m_delegate: CRxFilterChangeDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = NSLocalizedString("Filter", comment: "");
        
        var arrBtnItems = [UIBarButtonItem]();
        arrBtnItems.append(UIBarButtonItem(title: NSLocalizedString("All", comment: ""), style: .plain, target: self, action: #selector(FilterCtl.onSelectAll)));
        arrBtnItems.append(UIBarButtonItem(title: NSLocalizedString("None", comment: ""), style: .plain, target: self, action: #selector(FilterCtl.onSelectNone)));
        self.navigationItem.setRightBarButtonItems(arrBtnItems, animated: false);

    }

    // MARK: - Table view data source
    //--------------------------------------------------------------------------
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    //--------------------------------------------------------------------------
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return m_arrFilter.count
    }

    //--------------------------------------------------------------------------
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cellFilter", for: indexPath)
        cell.textLabel?.text = m_arrFilter[indexPath.row];
        let chkOn = UISwitch();
        chkOn.isOn = !m_setOut.contains(m_arrFilter[indexPath.row]);
        chkOn.tag = indexPath.row;
        chkOn.addTarget(self, action: #selector(FilterCtl.onChkItemChanged), for: .valueChanged);
        cell.accessoryView = chkOn;
        return cell;
    }
    
    //--------------------------------------------------------------------------
    @objc func onChkItemChanged(_ sender: Any) {
        guard let chk = sender as? UISwitch
            else { return; }
        let item = m_arrFilter[chk.tag];
        if chk.isOn {
            m_setOut.remove(item);
        }
        else {
            m_setOut.insert(item);
        }
        m_delegate?.filterChanged(setOut: m_setOut);
    }
    
    //--------------------------------------------------------------------------
    @objc func onSelectAll() {
        m_setOut.removeAll();
        self.tableView.reloadData();
        m_delegate?.filterChanged(setOut: m_setOut);
    }
    
    //--------------------------------------------------------------------------
    @objc func onSelectNone() {
        m_setOut.removeAll();
        for it in m_arrFilter {
            m_setOut.insert(it);
        }
        self.tableView.reloadData();
        m_delegate?.filterChanged(setOut: m_setOut);
    }
}
