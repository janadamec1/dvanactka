package com.roomarranger.android.dvanactka;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.Context;

import androidx.annotation.NonNull;
import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;
import androidx.work.Data;
import androidx.work.Worker;
import androidx.work.WorkerParameters;

import android.os.Build;
import android.provider.Settings;
import android.util.Log;

/*
 Copyright 2017-2022 Jan Adamec.

 This file is part of "Dvanactka".

 "Dvanactka" is free software; see the file COPYING.txt,
 included in this distribution, for details about the copyright.

 "Dvanactka" is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 ----------------------------------------------------------------------------
*/

public class NotificationPublisher extends Worker {

    private final Context m_context;

    public NotificationPublisher(@NonNull Context context, @NonNull WorkerParameters params) {
        super(context, params);
        m_context = context;
    }

    @NonNull
    @Override
    public Result doWork() {

        NotificationHelper.triggerNotification(m_context, getInputData());

        return Result.success();
        // (Returning RETRY tells WorkManager to try this task again
        // later; FAILURE says not to try again.)
    }
}

class NotificationHelper {
    public static String NOTIFICATION_ID = "notification-id";
    public static String CHANNEL_ID  = "dvanactka-channel-id";
    public static String NOTIFICATION_WORK_TAG = "com.roomarranger.dvanactka-notify.tag";
    public static String NOTIFICATION_DATA_TITLE = "contentTitle";
    public static String NOTIFICATION_DATA_TEXT = "contentText";

    public NotificationHelper() {
    }

    static public void triggerNotification(Context ctx, Data inputData) {

        Log.v("DVANACTKA", "Show notification!");

        createNotificationChannel(ctx);

        Notification notification = new NotificationCompat.Builder(ctx, NotificationHelper.CHANNEL_ID)
                .setContentTitle(inputData.getString(NotificationHelper.NOTIFICATION_DATA_TITLE))
                .setContentText(inputData.getString(NotificationHelper.NOTIFICATION_DATA_TEXT))
                .setSmallIcon(R.mipmap.ic_notification)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_EVENT)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setSound(Settings.System.DEFAULT_NOTIFICATION_URI)
                .build();

        NotificationManagerCompat.from(ctx).notify(inputData.getInt(NotificationHelper.NOTIFICATION_ID, 1), notification);
    }

    //---------------------------------------------------------------------------
    static void createNotificationChannel(Context ctx) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            /*
            NotificationChannelCompat channel = new NotificationChannelCompat.Builder(NotificationHelper.CHANNEL_ID, NotificationManager.IMPORTANCE_HIGH)
                    .setDescription(ctx.getString(R.string.app_name))
                    .setLightsEnabled(true)
                    .setVibrationEnabled(true)
                    .setSound(Settings.System.DEFAULT_NOTIFICATION_URI, null)
                    .build();
            /*/
            NotificationChannel channel = new NotificationChannel(NotificationHelper.CHANNEL_ID, NotificationHelper.CHANNEL_ID, NotificationManager.IMPORTANCE_HIGH);
            channel.setDescription(ctx.getString(R.string.app_name));
            channel.enableLights(true);
            channel.enableVibration(true);
            channel.setLockscreenVisibility(Notification.VISIBILITY_PUBLIC);
            channel.setSound(Settings.System.DEFAULT_NOTIFICATION_URI, null);

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                channel.setAllowBubbles(true);
            }
            //*/

            NotificationManagerCompat notificationManager = NotificationManagerCompat.from(ctx);
            notificationManager.createNotificationChannel(channel);
        }
    }
}
