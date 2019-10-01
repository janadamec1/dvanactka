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
import MapKit

//---------------------------------------------------------------------------
class CRxGameCell : UICollectionViewCell {
    @IBOutlet weak var m_lbName: UILabel!
    @IBOutlet weak var m_lbProgress: UILabel!
    var m_item: CRxGameCategory!;
    
    override func draw(_ rect: CGRect) {
        let fCellSize = bounds.width;

        /* // gradient background
        if let context = UIGraphicsGetCurrentContext() {

            let colorTop = UIColor(red: 255.0/255.0, green: 199.0/255.0, blue: 58.0/255.0, alpha: 1.0);
            let colorBot = UIColor(red: 226.0/255.0, green: 73.0/255.0, blue: 0.0/255.0, alpha: 1.0);

            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [colorTop.cgColor, colorBot.cgColor] as CFArray, locations: [0, 1])!

            let path = UIBezierPath(roundedRect: CGRect(x:0, y:0, width: frame.width, height: frame.height), cornerRadius: frame.width/4.0);
            context.saveGState()
            path.addClip()
            context.drawLinearGradient(gradient, start: CGPoint(x:frame.width / 2, y: 0), end: CGPoint(x: frame.width / 2, y: frame.height), options: CGGradientDrawingOptions())
            context.restoreGState()
        }*/

        // progress
        let fRadius = fCellSize/3;
        let fPi_2 = CGFloat.pi/2;
        
        let pathTrack = UIBezierPath(arcCenter: CGPoint(x: fCellSize/2, y: fCellSize/2), radius: fRadius, startAngle: -fPi_2, endAngle: CGFloat.pi + fPi_2, clockwise: true);
        pathTrack.lineWidth = 8;
        UIColor(white: 0.4, alpha: 0.3).setStroke();
        pathTrack.stroke();

        var fGameProgressRatio = CGFloat(m_item.m_iProgress) / CGFloat(m_item.nextStarPoints());
        if fGameProgressRatio > 1.0 { fGameProgressRatio = 1.0; }
        let pathProgress = UIBezierPath(arcCenter: CGPoint(x: fCellSize/2, y: fCellSize/2), radius: fRadius, startAngle: -fPi_2, endAngle: -fPi_2 + 2*CGFloat.pi*fGameProgressRatio, clockwise: true);
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

            let iStars = m_item.stars();
            if iStars > 0 { imgStar.draw(in: rc1); } else { imgEmptyStar.draw(in: rc1); }
            if iStars > 1 { imgStar.draw(in: rc2); } else { imgEmptyStar.draw(in: rc2); }
            if iStars > 2 { imgStar.draw(in: rc3); } else { imgEmptyStar.draw(in: rc3); }
        }
    }
}

//---------------------------------------------------------------------------
class CRxGameHeader : UICollectionReusableView {
    @IBOutlet weak var m_lbLevel: UILabel!
    @IBOutlet weak var m_progress: UIProgressView!
    @IBOutlet weak var m_lbXp: UILabel!
}

//---------------------------------------------------------------------------
class CRxGameFooter : UICollectionReusableView {
    @IBOutlet weak var m_lbNote: UILabel!
}

//---------------------------------------------------------------------------
class GameCtl: UICollectionViewController, UICollectionViewDelegateFlowLayout {
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = NSLocalizedString("Game", comment: "");
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: NSLocalizedString("Leaderboard", comment: ""), style: .plain, target: self, action: #selector(GameCtl.onBtnLeaderboard));
        
        if let aDS = CRxGame.dataSource() {
            if aDS.m_sUuid == nil && CRxGame.shared.m_iPoints > 0 {
                CRxGame.shared.sendScoreToServer();
            }
        }
    }

    //---------------------------------------------------------------------------
    // MARK: - UICollectionViewDataSource
    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        
        if kind == UICollectionView.elementKindSectionHeader {
            let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "headerGame", for: indexPath) as! CRxGameHeader;
            let aPlayerStats = CRxGame.shared.playerLevel();
            headerView.m_lbLevel.text = NSLocalizedString("Level", comment: "") + " \(aPlayerStats.level)";
            headerView.m_progress.progress = Float(aPlayerStats.points-aPlayerStats.pointsPrevLevel) / Float(aPlayerStats.pointsNextLevel-aPlayerStats.pointsPrevLevel);
            headerView.m_lbXp.text = "\(aPlayerStats.points) / \(aPlayerStats.pointsNextLevel) XP";
            return headerView;
        }
        if kind == UICollectionView.elementKindSectionFooter {
            let footerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "footerGame", for: indexPath) as! CRxGameFooter;
            
            if CLLocationManager.authorizationStatus() != .authorizedWhenInUse {
                footerView.m_lbNote.text = NSLocalizedString("In order to play the game, please go to Settings and give the app the permission to access your location.", comment: "");
            }
            else {
                footerView.m_lbNote.text = NSLocalizedString("Game progress is lost when uninstalling the app.", comment: "");
            }
            return footerView;
        }
        
        
        return UICollectionReusableView();
    }

    //---------------------------------------------------------------------------
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1;
    }
    
    //---------------------------------------------------------------------------
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return CRxGame.shared.m_arrCategories.count;
    }
    
    //---------------------------------------------------------------------------
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cellGame", for: indexPath) as! CRxGameCell
        let item = CRxGame.shared.m_arrCategories[indexPath.row];
        cell.m_item = item;
        cell.m_lbName.text = item.m_sName;
        cell.m_lbProgress.text = String(format: "%d / %d", item.m_iProgress, item.nextStarPoints());
        return cell;
    }
    
    //---------------------------------------------------------------------------
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        let nViewWidth = min(collectionView.bounds.width, collectionView.bounds.height);
        let nItemsPerRow: CGFloat = floor(max(2.0, nViewWidth / 250.0));       // at least 2 cols, max size of cell is 250 (for iPad)
        let nSpacing = 8*(nItemsPerRow-1);
        let nMinInsets: CGFloat = 24;
        let nCellWidth = floor((nViewWidth-nSpacing-2*nMinInsets) / nItemsPerRow);
        return CGSize(width: nCellWidth, height: nCellWidth + 32);
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt
        section: Int) -> UIEdgeInsets {
        
        // calculate cell size based on portait
        let nViewWidth = min(collectionView.bounds.width, collectionView.bounds.height);
        let nItemsPerRow: CGFloat = floor(max(2.0, nViewWidth / 250.0));       // at least 2 cols, max size of cell is 250 (for iPad)
        let nSpacing = 8*(nItemsPerRow-1);
        let nMinInsets: CGFloat = 24;
        let nCellWidth = floor((nViewWidth-nSpacing-2*nMinInsets) / nItemsPerRow);
        let leftInset = (collectionView.frame.width - CGFloat(nCellWidth*nItemsPerRow + nSpacing)) / 2; // center
        
        return UIEdgeInsets.init(top: 12, left: leftInset-1, bottom: 24, right: leftInset-1);
    }
    
    //---------------------------------------------------------------------------
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator);
        self.collectionView?.collectionViewLayout.invalidateLayout();
    }
    
    //---------------------------------------------------------------------------
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = CRxGame.shared.m_arrCategories[indexPath.row];
        showToast(message: item.m_sHintMessage);
    }
    
    //---------------------------------------------------------------------------
    func showToast(message: String) {
        let alertController = UIAlertController(title: nil,
                                                message: message, preferredStyle: .alert);
        let actionOK = UIAlertAction(title: "OK", style: .default, handler: { (result : UIAlertAction) -> Void in
            print("OK")})
        alertController.addAction(actionOK);
        self.present(alertController, animated: true, completion: nil);
    }
    
    //---------------------------------------------------------------------------
    @objc func onBtnLeaderboard() {
        guard let aDS = CRxGame.dataSource()
            else { return }
        if aDS.m_sUuid == nil {
            showToast(message: NSLocalizedString("GameStart.note", comment:""));
            return;
        }
        performSegue(withIdentifier: "segueLeaderboard", sender: self);
    }
}
