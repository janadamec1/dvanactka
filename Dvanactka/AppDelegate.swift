//
//  AppDelegate.swift
//  Dvanactka
//
//  Created by Jan Adamec on 30.10.16.
//  Copyright © 2016 Jan Adamec. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        let dsm = CRxDataSourceManager.sharedInstance;
        dsm.defineDatasources();
        dsm.loadData();
        dsm.refreshAllDataSources();
        //dsm.refreshDataSource(id: CRxDataSourceManager.dsSpolky, force: true);  // force reload for testing
        application.applicationIconBadgeNumber = 0;
        CRxGame.sharedInstance.reinit();
        
        // Configure tracker from GoogleService-Info.plist.
        var configureError:NSError?
        GGLContext.sharedInstance().configureWithError(&configureError)
        //assert(configureError == nil, "Error configuring Google services: \(configureError)")
        
        // Optional: configure GAI options.
        if let gai = GAI.sharedInstance() {
            gai.trackUncaughtExceptions = false  // report uncaught exceptions
            gai.logger.logLevel = GAILogLevel.none  // remove before app release
            //gai.logger.logLevel = GAILogLevel.verbose  // remove before app release
        }
        
        Appirater.setAppId("1184613212");
        Appirater.setDaysUntilPrompt(5);
        Appirater.setUsesUntilPrompt(10);
        Appirater.setSignificantEventsUntilPrompt(-1);
        Appirater.setTimeBeforeReminding(2);
        //Appirater.setDebug(true);
        Appirater.appLaunched(true);
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
        CRxDataSourceManager.sharedInstance.refreshAllDataSources();
        CRxGame.sharedInstance.reinit();
        Appirater.appEnteredForeground(true);

        // Google Analytics
        if let tracker = GAI.sharedInstance().defaultTracker {
            tracker.set(kGAIScreenName, value: "Home");
            if let builder = GAIDictionaryBuilder.createScreenView() {
                tracker.send(builder.build() as [NSObject : AnyObject])
            }
        }
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
    func application(_ application: UIApplication, didReceive notification: UILocalNotification) {
        if (application.applicationState == .active)
        {
            if let navCtl = application.keyWindow?.rootViewController as? UINavigationController,
                let currentViewCtl = navCtl.visibleViewController {
                let alertController =  UIAlertController(title: NSLocalizedString("Reminder", comment:""),
                                                        message: notification.alertBody, preferredStyle: .alert);
                let actionOK = UIAlertAction(title: "OK", style: .default, handler: { (result : UIAlertAction) -> Void in
                    print("OK")})
                alertController.addAction(actionOK);
                currentViewCtl.present(alertController, animated: true, completion: nil);
            }
        }
        // Set icon badge number to zero
        application.applicationIconBadgeNumber = 0;
    }


}

