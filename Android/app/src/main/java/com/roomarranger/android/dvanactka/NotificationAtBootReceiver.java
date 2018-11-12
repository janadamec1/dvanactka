package com.roomarranger.android.dvanactka;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

/*
 Copyright 2017-2018 Jan Adamec.

 This file is part of "Dvanactka".

 "Dvanactka" is free software; see the file COPYING.txt,
 included in this distribution, for details about the copyright.

 "Dvanactka" is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 ----------------------------------------------------------------------------
*/

/**
 * This class receives the broadcast about reboot (see manifest). Time to re-schedule our notifications.
 */

public class NotificationAtBootReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        if ("android.intent.action.BOOT_COMPLETED".equals(intent.getAction())) {

            //Log.e("DVANACTKA", "We got reboot!");

            // Load waste data source
            MainActivity.verifyDataInited(context);
            // reset all notifications
            MainActivity.resetAllNotifications(context);
        }
    }
}
