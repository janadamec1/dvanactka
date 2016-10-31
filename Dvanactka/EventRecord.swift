//
//  EventRecord.swift
//  Dvanactka
//
//  Created by Jan Adamec on 30.10.16.
//  Copyright © 2016 Jan Adamec. All rights reserved.
//

import UIKit

class CRxEventRecord: NSObject {
    var m_sTitle: String = ""
    var m_sLink: String?
    var m_sCategory: String?
    var m_sText: String?
    var m_aDate: Date?
    
    init(title sTitle: String) {
        m_sTitle = sTitle
    }
}
