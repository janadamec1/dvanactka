package com.roomarranger.android.dvanactka;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

/**
 * Created by jadamec on 30.01.17.
 *
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
