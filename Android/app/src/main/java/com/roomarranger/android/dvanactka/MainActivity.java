package com.roomarranger.android.dvanactka;

import android.app.Activity;
import android.app.AlarmManager;
import android.app.Notification;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.Color;
import android.os.Bundle;
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

import com.google.android.gms.analytics.GoogleAnalytics;
import com.google.android.gms.analytics.Tracker;

import java.util.ArrayList;
import java.util.Calendar;
import java.util.Date;

public class MainActivity extends Activity implements CRxDataSourceRefreshDelegate
{
    ArrayList<String> m_arrSources = new ArrayList<String>();    // data source ids in order they should appear in the collection
    static boolean s_bInited = false;
    static Date s_dateLastRefreshed = null;
    static private Tracker s_GlobalTracker = null;
    static private Context s_appContext = null;
    BaseAdapter m_adapter = null;

    public static final String EXTRA_DATASOURCE = "com.roomarranger.dvanactka.DATASOURCE";
    public static final String EXTRA_PARENT_FILTER = "com.roomarranger.dvanactka.PARENT_FILTER";
    public static final String EXTRA_EVENT_RECORD = "com.roomarranger.dvanactka.EVENT_RECORD";
    public static final String EXTRA_USER_LOCATION_LAT = "com.roomarranger.dvanactka.USER_LOCATION_LAT";
    public static final String EXTRA_USER_LOCATION_LONG = "com.roomarranger.dvanactka.USER_LOCATION_LONG";

    static void initAllData(Context ctx) {
        // from AppDelegate.swift
        CRxDataSourceManager dsm = CRxDataSourceManager.sharedInstance();
        dsm.defineDatasources(ctx);
        dsm.loadData();
        //dsm.refreshAllDataSources(false); // is called in onResume
        //dsm.refreshDataSource(CRxDataSourceManager.dsSosContacts, true);
        //application.applicationIconBadgeNumber = 0;
        CRxGame.sharedInstance.init(ctx);
        CRxGame.sharedInstance.reinit();
        s_bInited = true;
    }

    @Override
    protected void onCreate(Bundle savedInstanceState)
    {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        s_appContext = getApplicationContext();
        if (!s_bInited) {
            initAllData(this);
        }

        GoogleAnalytics analytics = GoogleAnalytics.getInstance(this);
        s_GlobalTracker = analytics.newTracker(R.xml.global_tracker);

        // from ViewController.swift
        m_arrSources.add(CRxDataSourceManager.dsRadNews);
        m_arrSources.add(CRxDataSourceManager.dsSpolky);
        m_arrSources.add(CRxDataSourceManager.dsRadDeska);
        m_arrSources.add(CRxDataSourceManager.dsRadEvents);
        m_arrSources.add(CRxDataSourceManager.dsBiografProgram);
        m_arrSources.add(CRxDataSourceManager.dsSpolkyList);
        m_arrSources.add(CRxDataSourceManager.dsShops);
        m_arrSources.add(CRxDataSourceManager.dsWork);
        m_arrSources.add(CRxDataSourceManager.dsTraffic);
        m_arrSources.add(CRxDataSourceManager.dsWaste);
        m_arrSources.add(CRxDataSourceManager.dsReportFault);
        m_arrSources.add(CRxDataSourceManager.dsCooltour);
        m_arrSources.add(CRxDataSourceManager.dsSosContacts);
        m_arrSources.add(CRxDataSourceManager.dsGame);
        CRxDataSourceManager.sharedInstance().delegate = this;

        /*try {
            getActionBar().setBackgroundDrawable(new ColorDrawable(getResources().getColor(R.color.colorActionBarBkg)));
        } catch (Exception e) {}*/

        m_adapter = new ImageAdapter(this, m_arrSources);
        GridView gridview = (GridView)findViewById(R.id.gridview);
        gridview.setAdapter(m_adapter);

        gridview.setOnItemClickListener(new AdapterView.OnItemClickListener() {
            public void onItemClick(AdapterView<?> parent, View v,
                                    int position, long id) {
                String sDsSelected = m_arrSources.get(position);
                CRxDataSource aDS = CRxDataSourceManager.sharedInstance().m_dictDataSources.get(sDsSelected);

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
                else if (aDS != null && aDS.m_bFilterAsParentView) {
                    intent = new Intent(MainActivity.this, PlacesFilterCtl.class);
                    intent.putExtra(MainActivity.EXTRA_DATASOURCE, sDsSelected);
                }
                else {
                    intent = new Intent(MainActivity.this, EventCtl.class);
                    intent.putExtra(MainActivity.EXTRA_DATASOURCE, sDsSelected);
                }
                if (intent != null)
                    startActivity(intent);
            }
        });
    }

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
                convertView.setTag(cell);
            } else {
                cell = (CollectionViewHolder)convertView.getTag();
            }

            CRxDataSource ds = CRxDataSourceManager.sharedInstance().m_dictDataSources.get(m_list.get(position));
            if (ds != null) {
                int iconId = m_Context.getResources().getIdentifier(ds.m_sIcon, "drawable", m_Context.getPackageName());
                cell.imgIcon.setImageResource(iconId);
                if (ds.m_sShortTitle != null)
                    cell.lbName.setText(ds.m_sShortTitle);
                else
                    cell.lbName.setText(ds.m_sTitle);

                if (ds.m_eType != CRxDataSource.DATATYPE_news) {
                    cell.lbBadge.setVisibility(View.INVISIBLE);
                }
                else {
                    int iUnread = ds.unreadItemsCount();
                    cell.lbBadge.setText(String.valueOf(iUnread));
                    cell.lbBadge.setVisibility(iUnread > 0 ? View.VISIBLE : View.INVISIBLE);
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
        if (s_dateLastRefreshed == null || (now.getTime() - s_dateLastRefreshed.getTime()) > 10*60*1000) {  // 10 minutes from last global refresh
            s_dateLastRefreshed = now;
            CRxDataSourceManager.sharedInstance().refreshAllDataSources(false);
            CRxGame.sharedInstance.reinit();
        }
    }

    //---------------------------------------------------------------------------
    public void dataSourceRefreshEnded(String error) {
        if (error == null) {
            if (m_adapter != null)
                m_adapter.notifyDataSetChanged();  // update badges
            CRxGame.sharedInstance.reinit();
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
        switch (item.getItemId()) {
            case R.id.action_info: {
                Intent intent = new Intent(MainActivity.this, AppInfoCtl.class);
                startActivity(intent);
                return true;
            }
        }
        return super.onOptionsItemSelected(item);
    }

    //---------------------------------------------------------------------------
    public static Tracker getDefaultTracker() {
        return s_GlobalTracker;
    }

    //---------------------------------------------------------------------------
    static private void scheduleNotification(Context ctx, String content, Date date, int iId) {
        // https://gist.github.com/BrandonSmith/6679223
        Notification.Builder builder = new Notification.Builder(ctx);
        builder.setContentTitle(ctx.getString(R.string.app_name))
                .setContentText(content)
                .setSmallIcon(R.mipmap.ic_launcher);
        Notification notification = builder.build();

        Intent notificationIntent = new Intent(ctx, NotificationPublisher.class);
        notificationIntent.putExtra(NotificationPublisher.NOTIFICATION_ID, iId);
        notificationIntent.putExtra(NotificationPublisher.NOTIFICATION, notification);
        PendingIntent pendingIntent = PendingIntent.getBroadcast(ctx, iId, notificationIntent, PendingIntent.FLAG_UPDATE_CURRENT);

        AlarmManager alarmManager = (AlarmManager)ctx.getSystemService(Context.ALARM_SERVICE);
        alarmManager.set(AlarmManager.ELAPSED_REALTIME_WAKEUP, date.getTime(), pendingIntent);
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
                PendingIntent pendingIntent = PendingIntent.getBroadcast(ctx, iId, notificationIntent, PendingIntent.FLAG_UPDATE_CURRENT);
                alarmManager.cancel(pendingIntent);
            }
        }

        // go through all favorite locations and set notifications to future intervals
        Date dateNow = Calendar.getInstance().getTime();

        CRxDataSourceManager manager = CRxDataSourceManager.sharedInstance();
        CRxDataSource ds = manager.m_dictDataSources.get(CRxDataSourceManager.dsWaste);
        if (ds == null) return;

        int iNotificationId = 0;
        for (CRxEventRecord rec : ds.m_arrItems) {
            if (!manager.m_setPlacesNotified.contains(rec.m_sTitle)) {
                continue;
            }
            //Log.e("DVANACTKA", "Scheduling!");

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
        prefs.edit().putInt("iLastNotificationCount", iLastNotificationCount).apply();  // save number of notification in order to be able to cancel them next time
    }
}
