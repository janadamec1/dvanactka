//
//  GameCtl.swift
//  Dvanactka
//
//  Created by Jan Adamec on 05.12.16.
//  Copyright © 2016 Jan Adamec. All rights reserved.
//

import UIKit

//---------------------------------------------------------------------------
class CRxGameCell : UICollectionViewCell {
    @IBOutlet weak var m_lbName: UILabel!
    @IBOutlet weak var m_lbProgress: UILabel!
    var m_item: CRxGameCategory!;
    
    override func draw(_ rect: CGRect) {
        if let context = UIGraphicsGetCurrentContext() {

            /*let colorTop = UIColor(red: 255.0/255.0, green: 199.0/255.0, blue: 58.0/255.0, alpha: 1.0);
            let colorBot = UIColor(red: 226.0/255.0, green: 73.0/255.0, blue: 0.0/255.0, alpha: 1.0);

            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [colorTop.cgColor, colorBot.cgColor] as CFArray, locations: [0, 1])!

            let path = UIBezierPath(roundedRect: CGRect(x:0, y:0, width: frame.width, height: frame.height), cornerRadius: frame.width/4.0);
            context.saveGState()
            path.addClip()
            context.drawLinearGradient(gradient, start: CGPoint(x:frame.width / 2, y: 0), end: CGPoint(x: frame.width / 2, y: frame.height), options: CGGradientDrawingOptions())
            context.restoreGState()*/
            
            let fCellSize = bounds.width;

            // progress
            let fRadius = fCellSize/3;
            let fPi_2 = CGFloat(M_PI_2);
            
            let pathTrack = UIBezierPath(arcCenter: CGPoint(x: fCellSize/2, y: fCellSize/2), radius: fRadius, startAngle: -fPi_2, endAngle: CGFloat(M_PI+M_PI_2), clockwise: true);
            pathTrack.lineWidth = 8;
            UIColor(white: 0.4, alpha: 0.3).setStroke();
            pathTrack.stroke();

            let pathProgress = UIBezierPath(arcCenter: CGPoint(x: fCellSize/2, y: fCellSize/2), radius: fRadius, startAngle: -fPi_2, endAngle: -fPi_2 + 2*CGFloat(M_PI)*(CGFloat(m_item.m_iProgress) / CGFloat(m_item.m_iTotal)), clockwise: true);
            pathProgress.lineWidth = 8;
            pathProgress.lineCapStyle = .round;
            UIColor(red: 36.0/255.0, green: 90.0/255.0, blue: 0.5, alpha: 1.0).setStroke();
            pathProgress.stroke();
            
            // stars
            if let imgStar = UIImage(named: "goldstar25"),
                    let imgEmptyStar = UIImage(named: "goldstar25dis") {
                let fStarSize = fCellSize/4;
                let fStarSize_2 = fStarSize/2;
                let rc1 = CGRect(x: fCellSize/2 - fStarSize - fStarSize_2, y: fCellSize/2-fStarSize_2, width: fStarSize, height: fStarSize);
                let rc2 = CGRect(x: fCellSize/2             - fStarSize_2, y: fCellSize/2-fStarSize_2, width:fStarSize, height:fStarSize);
                let rc3 = CGRect(x: fCellSize/2 + fStarSize - fStarSize_2, y: fCellSize/2-fStarSize_2, width: fStarSize, height: fStarSize);

                if m_item.m_iStars > 0 { imgStar.draw(in: rc1); } else { imgEmptyStar.draw(in: rc1); }
                if m_item.m_iStars > 1 { imgStar.draw(in: rc2); } else { imgEmptyStar.draw(in: rc2); }
                if m_item.m_iStars > 2 { imgStar.draw(in: rc3); } else { imgEmptyStar.draw(in: rc3); }
            }
        }
    }
}

//---------------------------------------------------------------------------
class GameCtl: UICollectionViewController, UICollectionViewDelegateFlowLayout {
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = NSLocalizedString("Game", comment: "");
    }

    //---------------------------------------------------------------------------
    // MARK: - Table view data source
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1;
    }
    
    //---------------------------------------------------------------------------
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return CRxGame.sharedInstance.m_arrCategories.count;
    }
    
    //---------------------------------------------------------------------------
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cellGame", for: indexPath) as! CRxGameCell
        let item = CRxGame.sharedInstance.m_arrCategories[indexPath.row];
        cell.m_item = item;
        cell.m_lbName.text = item.m_sName;
        cell.m_lbProgress.text = String(format: "%d / %d", item.m_iProgress, item.m_iTotal);
        return cell
    }
    
    //---------------------------------------------------------------------------
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        let nItemsPerRow: CGFloat = 2.0;
        let nViewWidth = min(collectionView.frame.width, collectionView.frame.height);
        let nSpacing = 8*(nItemsPerRow-1);
        let nMinInsets: CGFloat = 24;
        let nCellWidth = floor((nViewWidth-nSpacing-2*nMinInsets) / nItemsPerRow);
        return CGSize(width: nCellWidth, height: nCellWidth);
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt
        section: Int) -> UIEdgeInsets {
        
        // calculate cell size based on portait
        let nItemsPerRow: CGFloat = 2.0;
        let nViewWidth = min(collectionView.frame.width, collectionView.frame.height);
        let nSpacing = 8*(nItemsPerRow-1);
        let nMinInsets: CGFloat = 24;
        let nCellWidth = floor((nViewWidth-nSpacing-2*nMinInsets) / nItemsPerRow);
        let leftInset = (collectionView.frame.width - CGFloat(nCellWidth*nItemsPerRow + nSpacing)) / 2; // center
        
        return UIEdgeInsetsMake(nMinInsets, leftInset-1, nMinInsets, leftInset-1);
    }
}
