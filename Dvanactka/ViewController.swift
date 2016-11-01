//
//  ViewController.swift
//  Dvanactka
//
//  Created by Jan Adamec on 30.10.16.
//  Copyright © 2016 Jan Adamec. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "radNews" {
            let destVC = segue.destination as! RadniceAktualCtl
            destVC.m_aDataSource = CRxDataSourceManager.sharedInstance.m_dictDataSources[CRxDataSourceManager.dsRadNews];
        }
        else if segue.identifier == "radAlerts" {
            let destVC = segue.destination as! RadniceAktualCtl
            destVC.m_aDataSource = CRxDataSourceManager.sharedInstance.m_dictDataSources[CRxDataSourceManager.dsRadAlerts];
        }
        else if segue.identifier == "biografProgram" {
            let destVC = segue.destination as! RadniceAktualCtl
            destVC.m_aDataSource = CRxDataSourceManager.sharedInstance.m_dictDataSources[CRxDataSourceManager.dsBiografProgram];
        }
    }
}

