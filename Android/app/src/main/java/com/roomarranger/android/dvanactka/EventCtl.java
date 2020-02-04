package com.roomarranger.android.dvanactka;

import android.app.Activity;
import android.content.ClipData;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.graphics.Paint;
import android.location.Location;
import android.Manifest;
import android.net.Uri;
import android.os.Bundle;
import android.provider.CalendarContract;
import android.support.v4.content.ContextCompat;
import android.support.v4.widget.SwipeRefreshLayout;
import android.text.Spannable;
import android.text.SpannableString;
import android.view.LayoutInflater;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.view.ViewGroup;
import android.widget.BaseExpandableListAdapter;
import android.widget.Button;
import android.widget.ExpandableListView;
import android.widget.ImageButton;
import android.widget.ImageView;
import android.widget.SearchView;
import android.widget.TextView;
import android.widget.Toast;

import com.google.android.gms.common.ConnectionResult;
import com.google.android.gms.common.api.GoogleApiClient;
import com.google.android.gms.location.LocationListener;
import com.google.android.gms.location.LocationRequest;
import com.google.android.gms.location.LocationServices;

import com.squareup.picasso.Picasso;

import java.text.Collator;
import java.text.DateFormat;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Calendar;
import java.util.Collections;
import java.util.Comparator;
import java.util.Date;
import java.util.HashMap;
import java.util.Locale;
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

public class EventCtl extends Activity implements GoogleApiClient.ConnectionCallbacks, GoogleApiClient.OnConnectionFailedListener, LocationListener,
        CRxDataSourceRefreshDelegate, SwipeRefreshLayout.OnRefreshListener {

    CRxDataSource m_aDataSource = null;
    boolean m_bAskForFilter = false;        // do not show items, present filter possibilites to pass next as ParentFilter
    String m_sParentFilter = null;          // show only items with this filter (for ds with filterAsParentView)
    String m_sSearchString = null;          // if not nil, use it as search string

    static final int CODE_DETAIL_PLACE_REFRESH = 3;         // from place detail
    static final int CODE_DETAIL_REFRESH_PARENT = 4;        // from saved news
    static final int CODE_FILTER_CTL = 5;                   // from filter control

    HashMap<String, ArrayList<CRxEventRecord>> m_orderedItems = new HashMap<String, ArrayList<CRxEventRecord>>();
    ArrayList<String> m_orderedCategories = new ArrayList<String>();    // sorted category local names
    ArrayList<String> m_arrFilterSelection = new ArrayList<String>();   // array when asing for filter (m_bAskForFilter). Used instead of orderedItems
    boolean m_bUserLocationAcquired = false;
    Location m_coordLast = null;
    GoogleApiClient m_GoogleApiClient = null;
    LocationRequest m_LocationRequest;
    SwipeRefreshLayout m_refreshControl;
    Toast m_refreshMessage;

    ExpandListAdapter m_adapter;

    static String formatDate(int iDateStyle, int iTimeStyle, Date date) {
        if (iDateStyle == -1 && iTimeStyle == -1) return "";
        if (iDateStyle == -1) return new SimpleDateFormat("HH:mm").format(date);// DateFormat.getTimeInstance(iTimeStyle).format(date);
        if (iTimeStyle == -1) return DateFormat.getDateInstance(iDateStyle).format(date);
        return new SimpleDateFormat("dd.MM.yy HH:mm").format(date);//DateFormat.getDateTimeInstance(iDateStyle, iTimeStyle).format(date);
    }

    static class NewsListItemHolder {
        int m_idLayout;
        TextView m_lbTitle;
        TextView m_lbText;
        TextView m_lbDate;
        Button m_btnWebsite;
        ImageButton m_btnFavorite;
        ImageButton m_btnAction;
        Button m_btnBuy;
        Button m_btnAddToCalendar;
        TextView m_lbAddress;
        View m_stackContact;
        Button m_btnEmail;
        Button m_btnPhone;
        ImageView m_imgIcon;
        ImageView m_imgIllustration;
    }

    public class ExpandListAdapter extends BaseExpandableListAdapter {
        private Context m_context;

        ExpandListAdapter(Context context) {
            super();
            m_context = context;
        }

        public int getGroupCount() {
            return m_orderedCategories.size();
        }

        public long getGroupId(int groupPosition) {
            return groupPosition;
        }

        public Object getGroup(int groupPosition) {
            return null;
        }

        public int getChildrenCount(int groupPosition) {
            if (isAskForFilterActive() && groupPosition == 0)
                return m_arrFilterSelection.size();
            ArrayList<CRxEventRecord> arr = m_orderedItems.get(m_orderedCategories.get(groupPosition));
            if (arr != null)
                return arr.size();
            else
                return 0;
        }

        public View getGroupView(int groupPosition, boolean isLastChild, View view,
                                 ViewGroup parent)
        {
            ExpandableListView pListView = (ExpandableListView)parent;  // expand the group
            pListView.expandGroup(groupPosition);

            if (view == null) {
                LayoutInflater inInflater = (LayoutInflater) m_context.getSystemService(Context.LAYOUT_INFLATER_SERVICE);
                view = inInflater.inflate(R.layout.group_header, null);
            }
            TextView tvName = (TextView) view.findViewById(android.R.id.text1);
            tvName.setText(m_orderedCategories.get(groupPosition));
            //if (m_orderedCategories.size() < 2)
            //    view.setVisibility(View.GONE);
            return view;
        }

        public Object getChild(int groupPosition, int childPosition) {
            return null;
        }

        public long getChildId(int groupPosition, int childPosition) {
            return childPosition;
        }

        public View getChildView(int groupPosition, int childPosition, boolean isLastChild, View view,
                                 ViewGroup parent) {

            boolean bCellForAskingForFilter = isAskForFilterActive() && groupPosition == 0;
            int resId = R.layout.list_item_places;
            if (bCellForAskingForFilter)
                resId = R.layout.list_item_filter;
            else {
                switch (m_aDataSource.m_eType) {
                    case CRxDataSource.DATATYPE_news:
                        resId = R.layout.list_item_news;
                        break;
                    case CRxDataSource.DATATYPE_events:
                        resId = R.layout.list_item_events;
                        break;
                    case CRxDataSource.DATATYPE_places:
                        resId = R.layout.list_item_places;
                        break;
                    case CRxDataSource.DATATYPE_questions:
                        resId = R.layout.list_item_filter;
                        break;
                }
            }
            NewsListItemHolder cell;
            if (view != null) { // check if row compatible
                cell = (NewsListItemHolder)view.getTag();

                if (cell.m_idLayout != resId)
                    view = null;
            }

            if (view == null) {
                LayoutInflater inInflater = (LayoutInflater)m_context.getSystemService(Context.LAYOUT_INFLATER_SERVICE);
                view = inInflater.inflate(resId, null);

                cell = new NewsListItemHolder();
                cell.m_idLayout = resId;

                if (bCellForAskingForFilter) {
                    cell.m_lbTitle = (TextView) view.findViewById(R.id.title);
                }
                else {
                    switch (m_aDataSource.m_eType) {
                        case CRxDataSource.DATATYPE_news:
                            cell.m_lbTitle = (TextView) view.findViewById(R.id.title);
                            cell.m_imgIllustration = (ImageView) view.findViewById(R.id.imgIllustration);
                            cell.m_lbText = (TextView) view.findViewById(R.id.text);
                            cell.m_btnFavorite = (ImageButton) view.findViewById(R.id.btnFavorite);
                            cell.m_lbDate = (TextView) view.findViewById(R.id.date);
                            cell.m_btnWebsite = (Button) view.findViewById(R.id.btnWebsite);
                            cell.m_btnAction = (ImageButton) view.findViewById(R.id.btnAction);
                            break;
                        case CRxDataSource.DATATYPE_events:
                            cell.m_lbTitle = (TextView) view.findViewById(R.id.title);
                            cell.m_lbText = (TextView) view.findViewById(R.id.text);
                            cell.m_lbDate = (TextView) view.findViewById(R.id.date);
                            cell.m_lbAddress = (TextView) view.findViewById(R.id.address);
                            cell.m_btnWebsite = (Button) view.findViewById(R.id.btnWebsite);
                            cell.m_btnBuy = (Button) view.findViewById(R.id.btnBuy);
                            cell.m_btnAddToCalendar = (Button) view.findViewById(R.id.btnAddToCalendar);
                            cell.m_stackContact = view.findViewById(R.id.stackContact);
                            cell.m_btnEmail = (Button) view.findViewById(R.id.btnEmail);
                            cell.m_btnPhone = (Button) view.findViewById(R.id.btnPhone);
                            break;
                        case CRxDataSource.DATATYPE_places:
                            cell.m_lbTitle = (TextView) view.findViewById(R.id.title);
                            cell.m_lbText = (TextView) view.findViewById(R.id.text);
                            cell.m_imgIcon = (ImageView) view.findViewById(R.id.icon);
                            break;
                        case CRxDataSource.DATATYPE_questions:
                            cell.m_lbTitle = (TextView) view.findViewById(R.id.title);
                            break;
                    }
                }
                if (cell.m_btnWebsite != null)
                    cell.m_btnWebsite.setOnClickListener(new View.OnClickListener() {
                        @Override
                        public void onClick(View view) {
                            CRxEventRecord aRecClicked = (CRxEventRecord)view.getTag();
                            if (aRecClicked != null)
                                aRecClicked.openInfoLink(EventCtl.this);
                        }
                    });
                if (cell.m_btnBuy != null)
                    cell.m_btnBuy.setOnClickListener(new View.OnClickListener() {
                        @Override
                        public void onClick(View view) {
                            CRxEventRecord aRecClicked = (CRxEventRecord)view.getTag();
                            if (aRecClicked != null)
                                aRecClicked.openBuyLink(EventCtl.this);
                        }
                    });
                if (cell.m_btnFavorite != null)
                    cell.m_btnFavorite.setOnClickListener(new View.OnClickListener() {
                        @Override
                        public void onClick(View view) {
                            CRxEventRecord aRecClicked = (CRxEventRecord)view.getTag();
                            if (aRecClicked != null) {
                                aRecClicked.m_bMarkFavorite = !aRecClicked.m_bMarkFavorite;
                                ImageButton btn = (ImageButton)view;
                                btn.setImageResource(aRecClicked.m_bMarkFavorite ? R.drawable.goldstar25 : R.drawable.goldstar25dis);
                                CRxDataSourceManager.shared.setFavorite(aRecClicked, aRecClicked.m_bMarkFavorite);

                                if (m_aDataSource.m_sId.equals(CRxDataSourceManager.dsSavedNews)){
                                    setResult(EventCtl.CODE_DETAIL_REFRESH_PARENT);
                                }
                            }
                        }
                    });
                if (cell.m_btnAddToCalendar != null)
                    cell.m_btnAddToCalendar.setOnClickListener(new View.OnClickListener() {
                        @Override
                        public void onClick(View view) {
                            CRxEventRecord aRecClicked = (CRxEventRecord)view.getTag();
                            if (aRecClicked != null) {
                                Intent calIntent = new Intent(Intent.ACTION_INSERT);
                                calIntent.setData(CalendarContract.Events.CONTENT_URI);
                                calIntent.putExtra(CalendarContract.Events.TITLE, aRecClicked.m_sTitle);
                                if (aRecClicked.m_sAddress != null)
                                    calIntent.putExtra(CalendarContract.Events.EVENT_LOCATION, aRecClicked.m_sAddress);
                                if (aRecClicked.m_sText != null)
                                    calIntent.putExtra(CalendarContract.Events.DESCRIPTION, aRecClicked.m_sText);
                                if (aRecClicked.m_aDate != null)
                                    calIntent.putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, aRecClicked.m_aDate.getTime());
                                if (aRecClicked.m_aDateTo != null)
                                    calIntent.putExtra(CalendarContract.EXTRA_EVENT_END_TIME, aRecClicked.m_aDateTo.getTime());
                                startActivity(calIntent);
                            }
                        }
                    });
                if (cell.m_btnAction != null)
                    cell.m_btnAction.setOnClickListener(new View.OnClickListener() {
                        @Override
                        public void onClick(View view) {
                            CRxEventRecord aRecClicked = (CRxEventRecord)view.getTag();
                            if (aRecClicked != null) {
                                Intent sharingIntent = new Intent(android.content.Intent.ACTION_SEND);
                                sharingIntent.setType("text/plain");
                                String shareText = aRecClicked.m_sTitle;
                                if (aRecClicked.m_sText != null)
                                    shareText += "\n" + aRecClicked.m_sText;
                                if (aRecClicked.m_sInfoLink != null)
                                    shareText += "\n" + aRecClicked.m_sInfoLink;
                                sharingIntent.putExtra(android.content.Intent.EXTRA_TEXT, shareText);
                                sharingIntent.putExtra(android.content.Intent.EXTRA_SUBJECT, aRecClicked.m_sTitle);
                                startActivity(Intent.createChooser(sharingIntent, getString(R.string.share_via)));
                            }
                        }
                    });
                if (cell.m_btnEmail != null)
                    cell.m_btnEmail.setOnClickListener(new View.OnClickListener() {
                        @Override
                        public void onClick(View view) {
                            CRxEventRecord aRecClicked = (CRxEventRecord)view.getTag();
                            if (aRecClicked != null) {
                                Intent intent = new Intent(Intent.ACTION_SEND);
                                intent.setType("message/rfc822");
                                intent.putExtra(Intent.EXTRA_EMAIL, new String[]{aRecClicked.m_sEmail});

                                String sSubject = "Zájem o " + aRecClicked.m_sTitle;
                                if (aRecClicked.m_aDate != null) {
                                    sSubject += " @ " + EventCtl.formatDate(DateFormat.SHORT, DateFormat.SHORT, aRecClicked.m_aDate);
                                }
                                intent.putExtra(Intent.EXTRA_SUBJECT, sSubject);
                                try {
                                    startActivity(Intent.createChooser(intent, getString(R.string.send_mail)));
                                } catch (android.content.ActivityNotFoundException ex) {
                                    Toast.makeText(EventCtl.this, "There are no email clients installed.", Toast.LENGTH_SHORT).show();
                                }
                            }
                        }
                    });
                if (cell.m_btnPhone != null)
                    cell.m_btnPhone.setOnClickListener(new View.OnClickListener() {
                        @Override
                        public void onClick(View view) {
                            CRxEventRecord aRecClicked = (CRxEventRecord)view.getTag();
                            if (aRecClicked != null) {
                                try {
                                    Intent intent = new Intent(Intent.ACTION_DIAL, Uri.fromParts("tel", aRecClicked.m_sPhoneNumber.replace(" ", ""), null));
                                    intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                                    startActivity(intent);
                                } catch (Exception e) {
                                    e.printStackTrace();
                                }
                            }
                        }
                    });

                view.setTag(cell);
            }
            else {
                cell = (NewsListItemHolder)view.getTag();
            }

            // fill cell contents
            if (bCellForAskingForFilter) {
                cell.m_lbTitle.setText(m_arrFilterSelection.get(childPosition));
                return view;
            }

            ArrayList<CRxEventRecord> arr = m_orderedItems.get(m_orderedCategories.get(groupPosition));
            CRxEventRecord rec = arr.get(childPosition);

            if (cell.m_btnWebsite != null)
                cell.m_btnWebsite.setTag(rec);
            if (cell.m_btnAction != null)
                cell.m_btnAction.setTag(rec);
            if (cell.m_btnBuy != null)
                cell.m_btnBuy.setTag(rec);
            if (cell.m_btnAddToCalendar != null)
                cell.m_btnAddToCalendar.setTag(rec);
            if (cell.m_btnFavorite != null)
                cell.m_btnFavorite.setTag(rec);
            if (cell.m_btnEmail != null)
                cell.m_btnEmail.setTag(rec);
            if (cell.m_btnPhone != null)
                cell.m_btnPhone.setTag(rec);

            switch (m_aDataSource.m_eType) {
                case CRxDataSource.DATATYPE_news: {

                    cell.m_lbTitle.setText(rec.m_sTitle);

                    String sText = "";
                    int iBoldTo = 0;
                    if (rec.m_sFilter != null) {
                        sText += rec.m_sFilter;
                        iBoldTo = sText.length();
                    }
                    if (rec.m_sText != null && !rec.m_sText.isEmpty()) {
                        if (sText.length() > 0) {
                            sText += " - ";
                        }
                        sText += rec.m_sText;
                    }
                    final SpannableString str = new SpannableString(sText);
                    if (iBoldTo > 0)
                        str.setSpan(new android.text.style.StyleSpan(android.graphics.Typeface.BOLD), 0, iBoldTo, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
                    cell.m_lbText.setText(str);
                    cell.m_lbText.setVisibility(sText.isEmpty() ? View.GONE : View.VISIBLE);

                    String sDateText = "";
                    if (rec.m_aDate != null) {
                        if (rec.m_aDateTo != null) {
                            DateFormat df = DateFormat.getDateInstance(DateFormat.MEDIUM);
                            sDateText += df.format(rec.m_aDate) + " - " + df.format(rec.m_aDateTo);
                        }
                        else {
                            DateFormat df = DateFormat.getDateInstance(DateFormat.FULL);
                            sDateText = df.format(rec.m_aDate);
                        }
                    }
                    cell.m_lbDate.setText(sDateText);

                    boolean bImgPresent = false;
                    if (rec.m_sIllustrationImgLink != null && !rec.m_sIllustrationImgLink.isEmpty()) {
                        bImgPresent = true;
                        Picasso.get().load(rec.m_sIllustrationImgLink).into(cell.m_imgIllustration); // with Picasso library for downloading and caching (using Gradle)
                    }
                    cell.m_imgIllustration.setVisibility(!bImgPresent ? View.GONE : View.VISIBLE);

                    cell.m_btnWebsite.setVisibility(rec.m_sInfoLink == null ? View.GONE : View.VISIBLE);
                    cell.m_btnAction.setVisibility(rec.m_sInfoLink == null ? View.GONE : View.VISIBLE);
                    cell.m_btnFavorite.setImageResource(rec.m_bMarkFavorite ? R.drawable.goldstar25 : R.drawable.goldstar25dis);
                    break;
                }

                case CRxDataSource.DATATYPE_events: {

                    cell.m_lbTitle.setText(rec.m_sTitle);

                    if (rec.m_sText != null)
                        cell.m_lbText.setText(rec.m_sText);
                    cell.m_lbText.setVisibility(rec.m_sText == null ? View.GONE : View.VISIBLE);

                    if (rec.m_sAddress != null)
                        cell.m_lbAddress.setText(rec.m_sAddress.replaceAll("\n", ", "));
                    cell.m_lbAddress.setVisibility(rec.m_sAddress == null || !m_aDataSource.m_bListingShowEventAddress ? View.GONE : View.VISIBLE);

                    String sDateText = "";
                    if (rec.m_aDate != null) {
                        int iDateStyle = -1;
                        int iTimeStyle = DateFormat.SHORT;

                        Calendar calFrom = Calendar.getInstance();
                        calFrom.setTime(rec.m_aDate);

                        if (calFrom.get(Calendar.HOUR_OF_DAY) == 0 && calFrom.get(Calendar.MINUTE) == 0) {
                            iTimeStyle = -1;
                        }
                        sDateText = EventCtl.formatDate(iDateStyle, iTimeStyle, rec.m_aDate);
                        if (rec.m_aDateTo != null) {
                            Calendar calTo = Calendar.getInstance();
                            calTo.setTime(rec.m_aDateTo);

                            if (calFrom.get(Calendar.DAY_OF_YEAR) != calTo.get(Calendar.DAY_OF_YEAR)) {
                                iDateStyle = DateFormat.SHORT;
                                sDateText = EventCtl.formatDate(iDateStyle, iTimeStyle, rec.m_aDate);
                            }

                            iTimeStyle = DateFormat.SHORT;
                            if (calTo.get(Calendar.HOUR_OF_DAY) == 0 && calTo.get(Calendar.MINUTE) == 0) {
                                iTimeStyle = -1;
                            }
                            sDateText += "\n- " + EventCtl.formatDate(iDateStyle, iTimeStyle, rec.m_aDateTo);
                        }
                    }
                    cell.m_lbDate.setText(sDateText);
                    cell.m_btnWebsite.setVisibility(rec.m_sInfoLink == null ? View.GONE : View.VISIBLE);
                    cell.m_btnBuy.setVisibility(rec.m_sBuyLink == null ? View.GONE : View.VISIBLE);
                    cell.m_btnAddToCalendar.setVisibility(rec.m_aDate==null ? View.GONE : View.VISIBLE);

                    cell.m_stackContact.setVisibility(rec.m_sEmail == null && rec.m_sPhoneNumber == null ? View.GONE : View.VISIBLE);
                    if (rec.m_sEmail != null || rec.m_sPhoneNumber != null) {
                        if (rec.m_sPhoneNumber != null) {
                            cell.m_btnPhone.setText(rec.m_sPhoneNumber);
                        }
                        cell.m_btnEmail.setVisibility(rec.m_sEmail==null ? View.GONE : View.VISIBLE);
                        cell.m_btnPhone.setVisibility(rec.m_sPhoneNumber==null ? View.GONE : View.VISIBLE);
                    }
                    break;
                }

                case CRxDataSource.DATATYPE_places: {

                    String sRecTitle = rec.m_sTitle;
                    if (CRxGame.shared.playerWas(rec))
                        sRecTitle += " ✓";
                    cell.m_lbTitle.setText(sRecTitle);

                    // gray future roadblocks
                    Date now = new Date();
                    boolean bInFuture = (rec.m_aDate != null && rec.m_aDate.after(now));
                    if (bInFuture)
                        cell.m_lbTitle.setTextColor(Color.rgb(128, 128, 128));
                    else
                        cell.m_lbTitle.setTextColor(Color.BLACK);
                    // strike-out obsolete accidents
                    boolean bObsolete = (rec.m_aDateTo != null && rec.m_aDateTo.before(now));
                    if (bObsolete)
                        cell.m_lbTitle.setPaintFlags(cell.m_lbTitle.getPaintFlags() | Paint.STRIKE_THRU_TEXT_FLAG);
                    else
                        cell.m_lbTitle.setPaintFlags(cell.m_lbTitle.getPaintFlags() & (~Paint.STRIKE_THRU_TEXT_FLAG));

                    String sDistance = "";
                    if (m_bUserLocationAcquired && rec.m_aLocation != null) {
                        if (rec.m_distFromUser > 1000) {
                            sDistance = String.format(Locale.getDefault(),"%.2f km ", rec.m_distFromUser/1000.0);
                        }
                        else {
                            sDistance = String.format(Locale.getDefault(), "%d m ", (int)rec.m_distFromUser);
                        }
                    }
                    String sSubtitle = "";
                    String sNextEvent = rec.nextEventOccurenceString(m_context);
                    String sTodayHours = rec.todayOpeningHoursString(m_context);
                    if (sNextEvent != null) {
                        sSubtitle = sNextEvent;
                    }
                    else if (sTodayHours != null) {
                        sSubtitle = sTodayHours;
                    }
                    else if (rec.m_sText != null && !rec.hasHtmlText()) {
                        sSubtitle = rec.m_sText;
                    }
                    if (!sSubtitle.isEmpty()) {
                        if (!sDistance.isEmpty()) {
                            sDistance += " | ";
                        }
                        sDistance += sSubtitle;
                    }
                    /*if (sDistance.isEmpty()) {
                        sDistance = "  ";    // must not be empty, causes strange effects
                    }*/
                    cell.m_lbText.setText(sDistance);
                    cell.m_lbText.setVisibility(!sDistance.isEmpty() ? View.VISIBLE : View.GONE);

                    int iIcon = CRxCategory.categoryIconName(rec.m_eCategory);
                    if (rec.m_bMarkFavorite)
                        iIcon = R.drawable.goldstar25;
                    if (iIcon != -1)
                        cell.m_imgIcon.setImageResource(iIcon);
                    cell.m_imgIcon.setVisibility(iIcon != -1 ? View.VISIBLE : View.GONE);
                    break;
                }
                case CRxDataSource.DATATYPE_questions: {
                    cell.m_lbTitle.setText(rec.m_sTitle);
                    break;
                }
            }
            return view;
        }

        public boolean hasStableIds() {
            return true;
        }

        public boolean isChildSelectable(int arg0, int arg1) {
            return true;
        }
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_event_ctl);

        MainActivity.verifyDataInited(this);

        String sDataSource = getIntent().getStringExtra(MainActivity.EXTRA_DATASOURCE);
        if (sDataSource == null) return;
        if (sDataSource.equals(CRxDataSourceManager.dsSavedNews))
            m_aDataSource = CRxDataSourceManager.shared.m_aSavedNews;
        else
            m_aDataSource = CRxDataSourceManager.shared.m_dictDataSources.get(sDataSource);
        if (m_aDataSource == null) return;
        m_bAskForFilter = getIntent().getBooleanExtra(MainActivity.EXTRA_ASK_FOR_FILTER, false);
        m_sParentFilter = getIntent().getStringExtra(MainActivity.EXTRA_PARENT_FILTER);

        if (m_aDataSource.m_bIsBeingRefreshed)
            m_aDataSource.delegate = this;

        if (m_sParentFilter != null) {
            setTitle(m_sParentFilter);
        }
        else {
            setTitle(m_aDataSource.m_sTitle);
        }

        setRecordsDistance();
        sortRecords();

        ExpandableListView ExpandList = (ExpandableListView)findViewById(R.id.ExpList);
        m_adapter = new ExpandListAdapter(this);
        ExpandList.setAdapter(m_adapter);
        if (m_bAskForFilter || m_aDataSource.m_eType == CRxDataSource.DATATYPE_places || m_aDataSource.m_eType == CRxDataSource.DATATYPE_questions) {
            ExpandList.setOnChildClickListener(new ExpandableListView.OnChildClickListener() {
                @Override
                public boolean onChildClick(ExpandableListView expandableListView, View view, int groupPosition, int childPosition, long id) {
                    if (isAskForFilterActive() && groupPosition == 0) {
                        Intent intent = new Intent(EventCtl.this, EventCtl.class);
                        intent.putExtra(MainActivity.EXTRA_DATASOURCE, m_aDataSource.m_sId);
                        intent.putExtra(MainActivity.EXTRA_PARENT_FILTER, m_arrFilterSelection.get(childPosition));
                        startActivity(intent);
                        return false;
                    }
                    else {
                        ArrayList<CRxEventRecord> arr = m_orderedItems.get(m_orderedCategories.get(groupPosition));
                        try {
                            CRxEventRecord rec = arr.get(childPosition);
                            if (m_aDataSource.m_eType == CRxDataSource.DATATYPE_places) {
                                Intent intent = new Intent(EventCtl.this, PlaceDetailCtl.class);
                                intent.putExtra(MainActivity.EXTRA_DATASOURCE, m_aDataSource.m_sId);
                                intent.putExtra(MainActivity.EXTRA_EVENT_RECORD, rec.recordHash());
                                startActivityForResult(intent, EventCtl.CODE_DETAIL_PLACE_REFRESH);
                            }
                            else if (m_aDataSource.m_eType == CRxDataSource.DATATYPE_questions) {
                                Intent intent = new Intent(EventCtl.this, QuestionsCtl.class);
                                intent.putExtra(MainActivity.EXTRA_DATASOURCE, m_aDataSource.m_sId);
                                intent.putExtra(MainActivity.EXTRA_EVENT_RECORD, rec.recordHash());
                                startActivity(intent);
                            }
                        }
                        catch (NullPointerException e) {}
                        return false;
                    }
                }
            });
        }
        if (m_aDataSource.m_eType == CRxDataSource.DATATYPE_places) {

            m_GoogleApiClient = new GoogleApiClient.Builder(this)
                    .addConnectionCallbacks(this)
                    .addOnConnectionFailedListener(this)
                    .addApi(LocationServices.API)
                    .build();

            m_LocationRequest = new LocationRequest();
            m_LocationRequest.setInterval(10000);
            m_LocationRequest.setFastestInterval(5000);
            m_LocationRequest.setPriority(LocationRequest.PRIORITY_HIGH_ACCURACY);
        }

        m_refreshControl = (SwipeRefreshLayout)findViewById(R.id.swipe_container);
        m_refreshControl.setOnRefreshListener(this);
        m_refreshMessage = Toast.makeText(getApplicationContext(), "", Toast.LENGTH_LONG);
        if (m_aDataSource.m_bIsBeingRefreshed)
            m_refreshControl.setRefreshing(true);

        // footer
        View viewFooter = findViewById(R.id.footer);
        TextView lbFooterText = (TextView)findViewById(R.id.footerText);
        Button btnFooterButton = (Button)findViewById(R.id.btnFooter);

        if (!m_aDataSource.m_bListingFooterVisible) {
            viewFooter.setVisibility(View.GONE);
        }
        else {
            if (m_aDataSource.m_sListingFooterCustomLabelText != null)
                lbFooterText.setText(m_aDataSource.m_sListingFooterCustomLabelText);
            if (m_aDataSource.m_sListingFooterCustomButtonText != null)
                btnFooterButton.setText(m_aDataSource.m_sListingFooterCustomButtonText);
            else if (CRxAppDefinition.shared.recordUpdateEmail() != null)
                btnFooterButton.setText(CRxAppDefinition.shared.recordUpdateEmail());
        }

        btnFooterButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                if (m_aDataSource.m_sListingFooterCustomButtonTargetUrl != null) {
                    Intent browserIntent = new Intent(Intent.ACTION_VIEW, Uri.parse(m_aDataSource.m_sListingFooterCustomButtonTargetUrl));
                    startActivity(browserIntent);
                }
                else if (CRxAppDefinition.shared.recordUpdateEmail() != null) {
                    Intent intent = new Intent(Intent.ACTION_SEND);
                    intent.setType("message/rfc822");
                    intent.putExtra(Intent.EXTRA_EMAIL, new String[]{CRxAppDefinition.shared.recordUpdateEmail()});

                    String sAppName = "CityApp";
                    if (CRxAppDefinition.shared.m_sTitle != null)
                        sAppName = CRxAppDefinition.shared.m_sTitle;
                    intent.putExtra(Intent.EXTRA_SUBJECT, "Aplikace " + sAppName + " - přidat záznam");

                    String sTitle = m_aDataSource.m_sTitle;
                    if (m_sParentFilter != null)
                        sTitle += m_sParentFilter;
                    intent.putExtra(Intent.EXTRA_TEXT, sTitle);
                    try {
                        startActivity(Intent.createChooser(intent, getString(R.string.send_mail)));
                    } catch (android.content.ActivityNotFoundException ex) {
                        Toast.makeText(EventCtl.this, "There are no email clients installed.", Toast.LENGTH_SHORT).show();
                    }
                }
            }
        });
    }

    //--------------------------------------------------------------------------
    private class DateCategoryZip {
        String m_sName;
        Date m_date;
        DateCategoryZip(String name, Date date) { m_sName = name; m_date = date;}
    }

    void sortRecords() {
        CRxDataSource ds = m_aDataSource;
        if (ds == null) return;

        m_orderedItems.clear();
        m_orderedCategories.clear();

        boolean bAskingForFilter = isAskForFilterActive();
        if (bAskingForFilter) {
            m_arrFilterSelection.clear();
            // get the list of filter items
            for (CRxEventRecord rec: m_aDataSource.m_arrItems) {
                if (rec.m_sFilter != null) {
                    if (!m_arrFilterSelection.contains(rec.m_sFilter)) {
                        m_arrFilterSelection.add(rec.m_sFilter);
                    }
                }
            }
            Collator coll = Collator.getInstance(); // for sorting with locale
            coll.setStrength(Collator.PRIMARY);
            Collections.sort(m_arrFilterSelection, coll);
            m_orderedCategories.add(getString(R.string.subcategories));
        }

        DateFormat df = DateFormat.getDateInstance(DateFormat.FULL);

        Calendar c = Calendar.getInstance();
        Date today = c.getTime();

        ArrayList<Date> arrDateCategories = new ArrayList<>();

        // first add objects to groups
        for (CRxEventRecord rec: ds.m_arrItems) {
            // favorities
            if (ds.m_eType == CRxDataSource.DATATYPE_news) {
                rec.m_bMarkFavorite = (CRxDataSourceManager.shared.findFavorite(rec) != null);

            } else if (ds.m_eType == CRxDataSource.DATATYPE_places) {
                rec.m_bMarkFavorite = CRxDataSourceManager.shared.m_setPlacesNotified.contains(rec.m_sTitle);
            }

            // filtering by filter set by user
            if (ds.m_bFilterable) {
                if (ds.m_setFilter != null && rec.m_sFilter != null)
                {
                    if (ds.m_setFilter.contains(rec.m_sFilter) ){
                        continue;   // skip this record
                    }
                }
            }
            // filtering by category selected in parent tableView
            if (ds.m_bFilterAsParentView && !bAskingForFilter) {
                if (rec.m_sFilter == null) {
                    continue;   // records without filter are shown in the parent tableView
                }
                if (rec.m_sFilter != null && m_sParentFilter != null) {
                    if (!rec.m_sFilter.equals(m_sParentFilter)) {
                        continue;
                    }
                }
            }
            if (bAskingForFilter && rec.m_sFilter != null) {
                continue;   // when asking for filter, show only records without filter (e.g. dsWaste)
            }

            // search
            if (m_sSearchString != null) {
                if (!rec.containsSearch(m_sSearchString, this)) {
                    continue;
                }
            }

            // categories
            String sCatName = "";
            Date dateCat = null;
            switch (ds.m_eType) {
            case CRxDataSource.DATATYPE_news: break;    // one category for news
            case CRxDataSource.DATATYPE_questions: break;

            case CRxDataSource.DATATYPE_places:
                if (ds.m_bGroupByCategory) {
                    sCatName = CRxCategory.categoryLocalName(rec.m_eCategory, this);
                }
                break;

            case CRxDataSource.DATATYPE_events:   // use date as category
                if (rec.m_aDate == null) {
                    continue;    // remove records without date
                }
                if (rec.m_aDate.before(today) && rec.m_aDateTo != null && rec.m_aDateTo.after(today)) {
                    if (rec.m_aDateTo.getTime()-rec.m_aDate.getTime() > 24*60*60*1000) {     // more then 1 day
                        sCatName = getString(R.string.multi_day_events);
                        dateCat = rec.m_aDate;
                    }
                    else {  // short events happening now
                        sCatName = df.format(rec.m_aDate);
                        dateCat = rec.m_aDate;
                    }
                }
                else if (rec.m_aDate.before(today)) {   // do not show old events
                    continue;
                }
                else {
                    sCatName = df.format(rec.m_aDate);
                    dateCat = rec.m_aDate;
                }
                break;
            }
            // categories
            if (!m_orderedItems.containsKey(sCatName)) {
                ArrayList<CRxEventRecord> arr = new ArrayList<>();
                arr.add(rec);
                m_orderedItems.put(sCatName, arr);   // new category
                m_orderedCategories.add(sCatName);

                if (dateCat != null)
                    arrDateCategories.add(dateCat);
            }
            else {
                ArrayList<CRxEventRecord> arr = m_orderedItems.get(sCatName);
                arr.add(rec);  // into existing
            }
        }

        // sort date categories and then
        if (ds.m_eType == CRxDataSource.DATATYPE_events) {
            DateCategoryZip[] zip = new DateCategoryZip[Math.min(arrDateCategories.size(), m_orderedCategories.size())];
            for (int i = 0; i < zip.length; i++) zip[i] = new DateCategoryZip(m_orderedCategories.get(i), arrDateCategories.get(i));
            Arrays.sort(zip, new Comparator<DateCategoryZip>() {
                @Override
                public int compare(DateCategoryZip t0, DateCategoryZip t1) {
                    return t0.m_date.compareTo(t1.m_date);
                }
            });
            m_orderedCategories.clear();
            for (int i = 0; i < zip.length; i++) m_orderedCategories.add(zip[i].m_sName);
        }

        // now sort each group by distance (places) or date (events, news)
        for (Map.Entry<String, ArrayList<CRxEventRecord>> groupIt: m_orderedItems.entrySet()) {
            ArrayList<CRxEventRecord> arr = groupIt.getValue();
            switch (ds.m_eType) {
                case CRxDataSource.DATATYPE_news:
                    Collections.sort(arr, new Comparator<CRxEventRecord>() {
                        @Override
                        public int compare(CRxEventRecord t0, CRxEventRecord t1)
                        {
                            return -t0.m_aDate.compareTo(t1.m_aDate);
                        }
                    });
                    break;
                case CRxDataSource.DATATYPE_events:
                    Collections.sort(arr, new Comparator<CRxEventRecord>() {
                        @Override
                        public int compare(CRxEventRecord t0, CRxEventRecord t1)
                        {
                            return t0.m_aDate.compareTo(t1.m_aDate);
                        }
                    });
                    break;
                case CRxDataSource.DATATYPE_places:
                    Collections.sort(arr, new Comparator<CRxEventRecord>() {
                        @Override
                        public int compare(CRxEventRecord t0, CRxEventRecord t1)
                        {
                            if (t0.m_bMarkFavorite != t1.m_bMarkFavorite)        // show favorite first
                                return t0.m_bMarkFavorite ? -1 : 1;
                            return Double.compare(t0.m_distFromUser, t1.m_distFromUser);
                        }
                    });
                    break;
                case CRxDataSource.DATATYPE_questions:
                    // no sorting
                    break;
            }
        }

        // remember last item shown
        if (ds.m_eType == CRxDataSource.DATATYPE_news && !ds.m_sId.equals(CRxDataSourceManager.dsSavedNews)) {
            if (ds.m_arrItems.size() > 0) {
                String sNewRecHash = ds.m_arrItems.get(0).recordHash();
                if (!sNewRecHash.equals(ds.m_sLastItemShown)) { // resave only when something changed
                    ds.m_sLastItemShown = sNewRecHash;
                    CRxDataSourceManager.shared.save(ds);
                }
            }
        }
    }

    //--------------------------------------------------------------------------
    void setRecordsDistance() {
        CRxDataSource ds = m_aDataSource;
        if (ds == null) return;

        if (!m_bUserLocationAcquired || m_coordLast == null) {
            return;
        }
        for (CRxEventRecord rec : ds.m_arrItems) {
            if (rec.m_aLocation != null) {
                rec.m_distFromUser = rec.m_aLocation.distanceTo(m_coordLast);
            }
        }
    }

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        if (m_aDataSource == null) return super.onCreateOptionsMenu(menu);

        // Inflate the menu; this adds items to the action bar if it is present.
        getMenuInflater().inflate(R.menu.menu_event_ctl, menu);

        MenuItem actFilter = menu.findItem(R.id.action_filter);
        MenuItem actMap = menu.findItem(R.id.action_map);
        MenuItem actSaved = menu.findItem(R.id.action_saved);
        MenuItem actSearch = menu.findItem(R.id.action_search);
        actFilter.setVisible(m_aDataSource.m_bFilterable);
        actMap.setVisible(m_aDataSource.m_bMapEnabled);
        actSaved.setVisible(m_aDataSource.m_eType == CRxDataSource.DATATYPE_news && !m_aDataSource.m_sId.equals(CRxDataSourceManager.dsSavedNews));

        SearchView viewSearch = (SearchView)actSearch.getActionView();
        viewSearch.setOnQueryTextListener(new SearchView.OnQueryTextListener() {
            @Override
            public boolean onQueryTextSubmit(String searchText) {
                return false;
            }

            @Override
            public boolean onQueryTextChange(String searchText) {
                // do search
                boolean bSearchActive = (searchText.length() > 1);
                boolean bWasActive = isSearchActive();
                if (!bSearchActive && !bWasActive) {
                    return false;
                }
                else if (!bSearchActive && bWasActive) {
                    m_sSearchString = null;
                }
                else {
                    m_sSearchString = searchText;
                }
                sortRecords();
                if (m_adapter != null)
                    m_adapter.notifyDataSetChanged();
                return false;
            }
        });
        return true;
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        switch (item.getItemId()) {
            // Respond to the action bar's Up/Home button
            case android.R.id.home:
                onBackPressed();        // go to the activity that brought user here, not to parent activity
                return true;

            case R.id.action_map: {
                Intent intent = new Intent(EventCtl.this, MapCtl.class);
                intent.putExtra(MainActivity.EXTRA_DATASOURCE, m_aDataSource.m_sId);
                if (m_sParentFilter != null)
                    intent.putExtra(MainActivity.EXTRA_PARENT_FILTER, m_sParentFilter);
                if (m_bUserLocationAcquired)
                {
                    intent.putExtra(MainActivity.EXTRA_USER_LOCATION_LAT, m_coordLast.getLatitude());
                    intent.putExtra(MainActivity.EXTRA_USER_LOCATION_LONG, m_coordLast.getLongitude());
                }
                startActivity(intent);
                return true;
            }
            case R.id.action_saved: {
                Intent intent = new Intent(EventCtl.this, EventCtl.class);
                intent.putExtra(MainActivity.EXTRA_DATASOURCE, CRxDataSourceManager.dsSavedNews);
                startActivityForResult(intent, EventCtl.CODE_DETAIL_REFRESH_PARENT);
                return true;
            }

            case R.id.action_filter: {
                Intent intent = new Intent(EventCtl.this, FilterCtl.class);
                intent.putExtra(MainActivity.EXTRA_DATASOURCE, m_aDataSource.m_sId);
                startActivityForResult(intent, EventCtl.CODE_FILTER_CTL);
                return true;
            }
        }
        return super.onOptionsItemSelected(item);
    }

    @Override
    protected void onStart()
    {
        super.onStart();
        if (m_GoogleApiClient != null)
            m_GoogleApiClient.connect();
    }

    @Override
    protected void onPause()
    {
        super.onPause();
        if (m_GoogleApiClient != null)
            stopLocationUpdates();
    }

    @Override
    public void onResume()
    {
        super.onResume();
        if (m_GoogleApiClient != null && m_GoogleApiClient.isConnected())
            startLocationUpdates();
    }

    @Override
    public void onConnected(Bundle connectionHint) {

        //Toast.makeText(this, "Connected", Toast.LENGTH_SHORT).show();
        //if (servicesConnected())
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED) {
            Location aLastLocation = LocationServices.FusedLocationApi.getLastLocation(m_GoogleApiClient);
            if (aLastLocation != null)
            {
                m_coordLast = aLastLocation;
                m_bUserLocationAcquired = true;
                updateListWhenLocationChanged();
            }
            startLocationUpdates();
        }
    }

    protected void startLocationUpdates() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED) {
            try {
                LocationServices.FusedLocationApi.requestLocationUpdates(m_GoogleApiClient, m_LocationRequest, this);
            } catch (Exception e) {
                e.printStackTrace();
            }
        }
    }

    protected void stopLocationUpdates() {
        try {
            LocationServices.FusedLocationApi.removeLocationUpdates(m_GoogleApiClient, this);
        }
        catch(Exception e){
            e.printStackTrace();
        }
    }

    //---------------------------------------------------------------------------
    void updateListWhenLocationChanged()
    {
        // reorder list of VOKs and show distance to current location
        setRecordsDistance();
        sortRecords();
        if (m_adapter != null)
            m_adapter.notifyDataSetChanged();
    }

    //---------------------------------------------------------------------------
    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);

        if (requestCode == EventCtl.CODE_DETAIL_REFRESH_PARENT || requestCode == EventCtl.CODE_DETAIL_PLACE_REFRESH) {   // saved news and favorite waste location
            sortRecords();
            if (m_adapter != null)
                m_adapter.notifyDataSetChanged();
        }
        else if (requestCode == EventCtl.CODE_FILTER_CTL) {  // filter changed
            sortRecords();
            if (m_adapter != null)
                m_adapter.notifyDataSetChanged();
        }
    }

    //---------------------------------------------------------------------------
    @Override
    public void onConnectionSuspended(int i) {
        Toast.makeText(this, "Google Play Services disconnected. Please re-connect.",
                Toast.LENGTH_SHORT).show();
    }

    //---------------------------------------------------------------------------
    @Override
    public void onConnectionFailed(ConnectionResult connectionResult) {
        Toast.makeText(this, "Connection to Google Play Services failed.",
                Toast.LENGTH_SHORT).show();
    }

    //---------------------------------------------------------------------------
    @Override
    public void onLocationChanged(Location location) {
        m_coordLast = location;
        m_bUserLocationAcquired = true;
        updateListWhenLocationChanged();
    }

    //---------------------------------------------------------------------------
    @Override
    public void onRefresh() {       // from refreshLayout
        m_aDataSource.delegate = this;
        CRxDataSourceManager.shared.refreshDataSource(m_aDataSource.m_sId, true, false);
    }

    //---------------------------------------------------------------------------
    @Override
    public void dataSourceRefreshEnded(String sDsId, String error) { // protocol CRxDataSourceRefreshDelegate
        m_aDataSource.delegate = null;

        if (error != null) {
            m_refreshControl.setRefreshing(false);
            m_refreshMessage.setText(error);
            m_refreshMessage.show();
        }
        else {
            setRecordsDistance();
            sortRecords();
            if (m_adapter != null)
                m_adapter.notifyDataSetChanged();
            ////self.refreshControl?.attributedTitle = NSAttributedString(string: stringWithLastUpdateDate());
            m_refreshControl.setRefreshing(false);
        }
    }

    //--------------------------------------------------------------------------
    boolean isSearchActive() {
        return m_sSearchString != null;
    }

    //--------------------------------------------------------------------------
    boolean isAskForFilterActive() {
        return m_bAskForFilter && !isSearchActive();
    }
}
