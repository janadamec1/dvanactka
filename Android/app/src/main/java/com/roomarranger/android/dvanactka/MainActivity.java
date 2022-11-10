package com.roomarranger.android.dvanactka;

import android.app.Activity;
import android.app.AlarmManager;
import android.app.AlertDialog;
import android.app.Notification;
import android.app.PendingIntent;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.Manifest;
import android.os.Bundle;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.view.ViewGroup;
import android.widget.AdapterView;
import android.widget.BaseAdapter;
import android.widget.GridView;
import android.widget.ImageView;
import android.widget.TextView;

import java.util.ArrayList;
import java.util.Calendar;
import java.util.Date;
import java.util.Map;

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

public class MainActivity extends Activity implements CRxDataSourceRefreshDelegate, ActivityCompat.OnRequestPermissionsResultCallback
{
    static boolean s_bInited = false;
    static Date s_dateLastRefreshed = null;
    static private Context s_appContext = null;
    BaseAdapter m_adapter = null;

    public static final String EXTRA_DATASOURCE = "com.roomarranger.dvanactka.DATASOURCE";
    public static final String EXTRA_ASK_FOR_FILTER = "com.roomarranger.dvanactka.ASK_FOR_FILTER";
    public static final String EXTRA_PARENT_FILTER = "com.roomarranger.dvanactka.PARENT_FILTER";
    public static final String EXTRA_EVENT_RECORD = "com.roomarranger.dvanactka.EVENT_RECORD";
    public static final String EXTRA_USER_LOCATION_LAT = "com.roomarranger.dvanactka.USER_LOCATION_LAT";
    public static final String EXTRA_USER_LOCATION_LONG = "com.roomarranger.dvanactka.USER_LOCATION_LONG";
    public static final String PREFERENCES_FILE = "com.roomarranger.dvanactka.PREFERENCE_FILE";

    static final int MY_PERMISSION_REQUEST_LOCATION = 139;
    boolean m_bAskPermissionLocation = true;

    static void verifyDataInited(Context ctx) {
        // from AppDelegate.swift
        s_appContext = ctx.getApplicationContext();
        if (s_bInited) return;

        CRxDataSourceManager dsm = CRxDataSourceManager.shared;
        dsm.init(ctx);

        try {
            CRxAppDefinition.shared.loadFromJSONStream(ctx.getResources().getAssets().open("appDefinition.json"));
        }
        catch (Exception e) { e.printStackTrace(); return; }

        dsm.loadData();
        //dsm.refreshAllDataSources(false, false); // is called in onResume
        //dsm.refreshDataSource(CRxDataSourceManager.dsSosContacts, true);
        //application.applicationIconBadgeNumber = 0;
        CRxGame.shared.init(ctx);
        CRxGame.shared.reinit();
        s_bInited = true;
    }

    @Override
    protected void onCreate(Bundle savedInstanceState)
    {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        MainActivity.verifyDataInited(this);

        /*
        GoogleAnalytics analytics = GoogleAnalytics.getInstance(this);
        s_GlobalTracker = analytics.newTracker(R.xml.global_tracker);
        */

        // from ViewController.swift
        CRxDataSourceManager.shared.delegate = this;

        /*try {
            getActionBar().setBackgroundDrawable(new ColorDrawable(getResources().getColor(R.color.colorActionBarBkg)));
        } catch (Exception e) {}*/

        m_adapter = new ImageAdapter(this, CRxAppDefinition.shared.m_arrDataSourceOrder);
        GridView gridview = (GridView)findViewById(R.id.gridview);
        gridview.setAdapter(m_adapter);

        gridview.setOnItemClickListener(new AdapterView.OnItemClickListener() {
            public void onItemClick(AdapterView<?> parent, View v,
                                    int position, long id) {
                String sDsSelected = CRxAppDefinition.shared.m_arrDataSourceOrder.get(position);
                CRxDataSource aDS = CRxDataSourceManager.shared.m_dictDataSources.get(sDsSelected);

                // hide unread badge
                try {
                    if (v != null && v.getTag() != null){
                        CollectionViewHolder cell = (CollectionViewHolder)v.getTag();
                        if (cell.lbBadge != null)
                            cell.lbBadge.setVisibility(View.INVISIBLE);
                    }
                } catch (Exception e) {e.printStackTrace();}

                Intent intent = null;
                if (sDsSelected.equals(CRxDataSourceManager.dsReportFault)) {
                    intent = new Intent(MainActivity.this, ReportFaultCtl.class);
                }
                else if (sDsSelected.equals(CRxDataSourceManager.dsGame)) {
                    intent = new Intent(MainActivity.this, GameCtl.class);
                }
                else {
                    intent = new Intent(MainActivity.this, EventCtl.class);
                    intent.putExtra(MainActivity.EXTRA_DATASOURCE, sDsSelected);
                    intent.putExtra(MainActivity.EXTRA_ASK_FOR_FILTER, aDS != null && aDS.m_bFilterAsParentView);
                }
                if (intent != null)
                    startActivity(intent);
            }
        });
    }

    //---------------------------------------------------------------------------
    static boolean dsHasBadge(CRxDataSource ds) {
        return ds != null && ds.m_eType == CRxDataSource.DATATYPE_news;
    }

    //---------------------------------------------------------------------------
    static class CollectionViewHolder {
        ImageView imgIcon;
        TextView lbName;
        TextView lbBadge;
    }

    public class ImageAdapter extends BaseAdapter {
        private Context m_Context;
        private ArrayList<String> m_list;

        ImageAdapter(Context c, ArrayList<String> list) {
            m_Context = c;
            m_list = list;
        }

        public int getCount() { return m_list.size(); }
        public Object getItem(int position) { return null;}
        public long getItemId(int position) { return 0; }

        // create a new ImageView for each item referenced by the Adapter
        public View getView(int position, View convertView, ViewGroup parent) {
            CollectionViewHolder cell;
            if (convertView == null) {
                LayoutInflater inflater = getLayoutInflater();
                convertView = inflater.inflate(R.layout.cell_main_collection, parent, false);
                //convertView.setLayoutParams(new GridView.LayoutParams(85, 105));

                cell = new CollectionViewHolder();
                cell.lbName = (TextView)convertView.findViewById(R.id.textView);
                cell.imgIcon = (ImageView)convertView.findViewById(R.id.imageView);
                cell.lbBadge = (TextView)convertView.findViewById(R.id.badge);

                /*convertView.setOnTouchListener(new View.OnTouchListener() {
                    @Override
                    public boolean onTouch(View view, MotionEvent motionEvent) {
                        boolean bDown = motionEvent.getAction() == MotionEvent.ACTION_DOWN;
                        Drawable aBkg = view.getBackground();
                        if (aBkg instanceof ColorDrawable) {
                            int color = ((ColorDrawable)aBkg).getColor();
                            int newColor = Color.argb(bDown ? 160 : 255, Color.red(color), Color.green(color), Color.blue(color));
                            view.setBackgroundColor(newColor);
                        }
                        return false;
                    }
                });*/
                convertView.setTag(cell);
            } else {
                cell = (CollectionViewHolder)convertView.getTag();
            }

            CRxDataSource ds = CRxDataSourceManager.shared.m_dictDataSources.get(m_list.get(position));
            if (ds != null) {
                int iconId = m_Context.getResources().getIdentifier(ds.m_sIcon, "drawable", m_Context.getPackageName());
                cell.imgIcon.setImageResource(iconId);
                if (ds.m_sShortTitle != null)
                    cell.lbName.setText(ds.m_sShortTitle);
                else
                    cell.lbName.setText(ds.m_sTitle);

                if (MainActivity.dsHasBadge(ds) && !ds.m_bIsBeingRefreshed) {
                    int iUnread = ds.unreadItemsCount();
                    cell.lbBadge.setText(String.valueOf(iUnread));
                    cell.lbBadge.setVisibility(iUnread > 0 ? View.VISIBLE : View.INVISIBLE);
                }
                else {
                    cell.lbBadge.setVisibility(View.INVISIBLE);
                }
                int iCl = ds.m_iBackgroundColor;
                convertView.setBackgroundColor(Color.rgb((iCl&0xFF0000)>>16, (iCl&0xFF00)>>8, iCl&0xFF));
            }
            return convertView;
        }
    }

    //---------------------------------------------------------------------------
    @Override
    protected void onResume() {
        super.onResume();

        // this is called whenever the app is brought to foreground, but also when switching activities
        Date now = new Date();
        if (s_dateLastRefreshed == null || (now.getTime() - s_dateLastRefreshed.getTime()) > 10 * 60 * 1000) {  // 10 minutes from last global refresh
            s_dateLastRefreshed = now;
            CRxDataSourceManager.shared.refreshAllDataSources(false, false, this);
            CRxGame.shared.reinit();

            // Location permission
            if (m_bAskPermissionLocation && ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
                // Should we show an explanation?
                if (ActivityCompat.shouldShowRequestPermissionRationale(this, Manifest.permission.ACCESS_FINE_LOCATION)) {
                    AlertDialog.Builder builder = new AlertDialog.Builder(this);
                    builder.setMessage(R.string.permission_explain_location);
                    builder.setOnCancelListener(new DialogInterface.OnCancelListener() {
                        @Override
                        public void onCancel(DialogInterface dialogInterface) {
                            m_bAskPermissionLocation = false;
                            ActivityCompat.requestPermissions(MainActivity.this, new String[]{Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION},
                                    MY_PERMISSION_REQUEST_LOCATION);
                        }
                    });
                    builder.create().show();
                }
                else {
                    // No explanation needed, we can request the permission.
                    m_bAskPermissionLocation = false;
                    ActivityCompat.requestPermissions(this, new String[]{Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION},
                            MY_PERMISSION_REQUEST_LOCATION);
                }
            }
        }
    }

    //---------------------------------------------------------------------------
    // ActivityCompat.OnRequestPermissionsResultCallback
    @Override
    public void onRequestPermissionsResult (int requestCode, String[] permissions, int[] grantResults) {
        if (requestCode == MY_PERMISSION_REQUEST_LOCATION) {
            m_bAskPermissionLocation = (permissions.length == 0);   // dialog cancelled, ask again later
        }
    }

    //---------------------------------------------------------------------------
    @Override
    protected void onDestroy() {
        CRxDataSourceManager.shared.delegate = null;
        super.onDestroy();
    }

    //---------------------------------------------------------------------------
    @Override
    public void dataSourceRefreshEnded(String sDsId, String error) {
        if (error == null) {
            // TODO: refresh only one cell
            CRxDataSource ds = CRxDataSourceManager.shared.m_dictDataSources.get(sDsId);
            if (MainActivity.dsHasBadge(ds) && m_adapter != null)
                m_adapter.notifyDataSetChanged();  // update badges
            CRxGame.shared.reinit();
        }
    }

    //---------------------------------------------------------------------------
    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        getMenuInflater().inflate(R.menu.menu_main_ctl, menu);
        return true;
    }

    //---------------------------------------------------------------------------
    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        int id = item.getItemId();
        if (id == R.id.action_info) {
            Intent intent = new Intent(MainActivity.this, AppInfoCtl.class);
            startActivity(intent);
            return true;
        }
        return super.onOptionsItemSelected(item);
    }

    //---------------------------------------------------------------------------
    static private void scheduleNotification(Context ctx, String content, Date date, int iId) {
        // https://gist.github.com/BrandonSmith/6679223
        Notification.Builder builder = new Notification.Builder(ctx);
        builder.setContentTitle(ctx.getString(R.string.app_name))
                .setContentText(content)
                .setWhen(date.getTime())
                .setSmallIcon(R.mipmap.ic_notification)
                .setDefaults(Notification.DEFAULT_ALL);
        Notification notification = builder.build();

        Intent notificationIntent = new Intent(ctx, NotificationPublisher.class);
        notificationIntent.putExtra(NotificationPublisher.NOTIFICATION_ID, iId);
        notificationIntent.putExtra(NotificationPublisher.NOTIFICATION, notification);
        PendingIntent pendingIntent = PendingIntent.getBroadcast(ctx, iId, notificationIntent, PendingIntent.FLAG_UPDATE_CURRENT);

        AlarmManager alarmManager = (AlarmManager)ctx.getSystemService(Context.ALARM_SERVICE);
        if (alarmManager != null)
            alarmManager.set(AlarmManager.RTC_WAKEUP, date.getTime(), pendingIntent);
    }

    //---------------------------------------------------------------------------
    static void resetAllNotifications() {
        resetAllNotifications(s_appContext);
    }
    static void resetAllNotifications(Context ctx) {

        // TODO: rewrite this later to use AlarmManager.OnAlarmListener (API level 24)

        // cancel all previous notifications  ??? does it work
        SharedPreferences prefs = ctx.getSharedPreferences("com.roomarranger.android.dvanactka", Context.MODE_PRIVATE);
        int iLastNotificationCount = prefs.getInt("iLastNotificationCount", 0);

        if (iLastNotificationCount > 0) {
            AlarmManager alarmManager = (AlarmManager)ctx.getSystemService(Context.ALARM_SERVICE);
            Intent notificationIntent = new Intent(ctx, NotificationPublisher.class);
            for (int iId = 0; iId < iLastNotificationCount; iId++) {
                PendingIntent pendingIntent = PendingIntent.getBroadcast(ctx, iId, notificationIntent, PendingIntent.FLAG_NO_CREATE);
                if (alarmManager != null && pendingIntent != null)
                    alarmManager.cancel(pendingIntent);
            }
        }

        // go through all favorite locations and set notifications to future intervals
        Date dateNow = Calendar.getInstance().getTime();
        int iNotificationId = 0;

        CRxDataSourceManager manager = CRxDataSourceManager.shared;
        for (Map.Entry<String, CRxDataSource> itemIt: manager.m_dictDataSources.entrySet()) {
            CRxDataSource ds = itemIt.getValue();
            if (ds == null || !ds.m_bLocalNotificationsForEvents)
                continue;

            for (CRxEventRecord rec : ds.m_arrItems) {
                if (!manager.m_setPlacesNotified.contains(rec.m_sTitle)) {
                    continue;
                }
                Log.v("DVANACTKA", "Scheduling!");

                if (rec.m_arrEvents == null) {
                    continue;
                }
                for (CRxEventInterval aEvent : rec.m_arrEvents) {
                    if (aEvent.m_dateStart.after(dateNow)) {
                        scheduleNotification(ctx, String.format(ctx.getString(R.string.dumpster_at_s_arrived_s), rec.m_sTitle, aEvent.m_sType),
                                aEvent.m_dateStart, iNotificationId);
                        iNotificationId++;

                        // also add a notification one day earlier
                        Calendar cal = Calendar.getInstance();
                        cal.setTime(aEvent.m_dateStart);
                        cal.add(Calendar.DAY_OF_MONTH, -1);
                        Date dayBefore = cal.getTime();
                        if (dayBefore.after(dateNow)) {
                            scheduleNotification(ctx, String.format(ctx.getString(R.string.dumpster_at_s_tomorrow_s), rec.m_sTitle, aEvent.m_sType),
                                    dayBefore, iNotificationId);
                            iNotificationId++;
                        }
                    }
                }
            }
        }
        prefs.edit().putInt("iLastNotificationCount", iNotificationId).apply();  // save number of notification in order to be able to cancel them next time
    }
}
