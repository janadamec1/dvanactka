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

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        if let urlAppDef = Bundle.main.url(forResource: "appDefinition.json", withExtension: "") {
            CRxAppDefinition.shared.loadFromJson(file: urlAppDef);
            let dsm = CRxDataSourceManager.shared;
            dsm.loadData();
            dsm.refreshAllDataSources();
            //dsm.refreshDataSource(id: CRxDataSourceManager.dsSpolky, force: true);  // force reload for testing
        }
        application.applicationIconBadgeNumber = 0;
        CRxGame.shared.reinit();
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
        application.applicationIconBadgeNumber = 0;
        CRxDataSourceManager.shared.refreshAllDataSources();
        CRxGame.shared.reinit();
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Play sound and show alert to the user
        completionHandler([.alert,.sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        
        let sMessage = response.notification.request.content.body;
        let sMsgTitle = response.notification.request.content.title;

        if let navCtl = window?.rootViewController as? UINavigationController,
            let currentViewCtl = navCtl.visibleViewController {
            let alertController = UIAlertController(title: sMsgTitle, message: sMessage, preferredStyle: .alert);
            let actionOK = UIAlertAction(title: "OK", style: .default, handler: { (result : UIAlertAction) -> Void in
                print("OK")})
            alertController.addAction(actionOK);
            currentViewCtl.present(alertController, animated: true, completion: nil);
        }
        completionHandler();
    }
}

