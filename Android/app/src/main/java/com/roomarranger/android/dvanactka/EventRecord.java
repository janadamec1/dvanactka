package com.roomarranger.android.dvanactka;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.res.Resources;
import android.location.Location;
import android.net.Uri;
import android.support.customtabs.CustomTabsIntent;

import org.json.JSONException;
import org.json.JSONObject;

import java.text.Normalizer;
import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.Collections;
import java.util.Comparator;
import java.util.Date;
import java.util.Locale;
import java.util.regex.Pattern;

/**
 * Created by jadamec on 28.12.16.
 */

class CRxHourInterval
{
    int m_weekday;          // weekday (1 = monday, 7 = sunday)
    int m_hourStart;        // int as 1235 = 12:35, or 1000 = 10:00
    int m_hourEnd;

    CRxHourInterval(int weekday, int start, int end) {
        super();
        m_weekday = weekday;
        m_hourStart = start;
        m_hourEnd = end;
    }

    static CRxHourInterval fromString(String string) {
        int iColon = string.indexOf(':');
        int iHyphen = string.indexOf('-');
        if (iColon > 0 && iHyphen > 0) {
            String day = string.substring(0, iColon);
            String hourStart = string.substring(iColon+1, iHyphen);
            String hourEnd = string.substring(iHyphen+1);
            try {
                int iDay = Integer.parseInt(day);
                int iHourStart = Integer.parseInt(hourStart);
                int iHourEnd = Integer.parseInt(hourEnd);

                return new CRxHourInterval(iDay, iHourStart, iHourEnd);
            }
            catch (NumberFormatException e) {}
        }
        return null;
    }

    @Override
    public String toString()
    {
        return String.format(Locale.US, "%d: %d-%d", m_weekday, m_hourStart, m_hourEnd);
    }

    String toIntervalDisplayString() {
        String sStart = String.format(Locale.US, "%d:%02d", (m_hourStart/100), (m_hourStart%100));
        String sEnd = String.format(Locale.US, "%d:%02d", (m_hourEnd/100), (m_hourEnd%100));
        return sStart + " - " + sEnd;
    }
}

//---------------------------------------------------------------------------
// this class is used for waste containers records
class CRxEventInterval
{
    Date m_dateStart;
    Date m_dateEnd;
    String m_sType;

    CRxEventInterval(Date start, Date end, String type) {
        super();
        m_dateStart = start;
        m_dateEnd = end;
        m_sType = type;
    }

    static CRxEventInterval fromString(String string) {
        String[] items = string.split(";");
        if (items.length < 3)
            return null;
        Date start = CRxEventRecord.loadDate(items[1]);
        Date end = CRxEventRecord.loadDate(items[2]);
        if (start == null || end == null)
            return null;
        return new CRxEventInterval(start, end, items[0]);
    }

    @Override
    public String toString()
    {
        return m_sType + ";" + CRxEventRecord.saveDate(m_dateStart) + ";" + CRxEventRecord.saveDate(m_dateEnd);
    }

    String toDisplayString()
    {
        // skip dayTo when on the same day (different time)
        Calendar calFrom = Calendar.getInstance();
        Calendar calTo = Calendar.getInstance();
        calFrom.setTime(m_dateStart);
        calTo.setTime(m_dateEnd);

        String sFrom = new SimpleDateFormat("dd.MM.yy HH:mm").format(m_dateStart);
        String sTo;
        if (calFrom.get(Calendar.DAY_OF_YEAR) == calTo.get(Calendar.DAY_OF_YEAR))
            sTo = new SimpleDateFormat("HH:mm").format(m_dateEnd);
        else
            sTo = new SimpleDateFormat("dd.MM.yy HH:mm").format(m_dateEnd);

        SimpleDateFormat weekDayFormat = new SimpleDateFormat("EEE");
        String sWeekDay = weekDayFormat.format(m_dateStart);

        return String.format("%s %s - %s", sWeekDay, sFrom, sTo);
    }

    String toRelativeIntervalString(Context ctx)
    {
        Calendar c = Calendar.getInstance();
        Date dayToday = c.getTime();

        String sString;
        Resources res = ctx.getResources();

        if (dayToday.after(m_dateEnd))
        {
            long aDiff = (dayToday.getTime() - m_dateEnd.getTime())/1000;    // in seconds
            int nDaysAgo = (int)aDiff/(60*60*24);
            sString = String.format(res.getString(R.string.d_days_ago), nDaysAgo);
        }
        else
        {
            long aDiff = (m_dateStart.getTime() - dayToday.getTime())/1000;
            int nMinutes = ((int)aDiff / 60) % 60;
            int nHours = ((int)aDiff / 3600) % 24;
            int nDays = ((int)aDiff / (3600*24));

            if (aDiff < 0)
                sString = res.getString(R.string.now);
            else
            {
                if (nDays > 2)
                    sString = String.format(res.getString(R.string.in_d_days), nDays);
                else if (nDays > 0)
                    sString = String.format(res.getString(R.string.in_d_days_d_hours), nDays, nHours);
                else if (nHours > 0)   // less then day
                    sString = String.format(res.getString(R.string.in_d_hours_d_minutes), nHours, nMinutes);
                else
                    sString = String.format(res.getString(R.string.in_d_minutes), nMinutes);
            }
        }

        if (!m_sType.isEmpty()) {
            if (sString.length() > 0)
                sString += String.format(" (%s)", m_sType);
            else
                sString = m_sType;
        }

        return sString;
    }
}

//---------------------------------------------------------------------------
class CRxCategory {
    static final String informace = "informace", lekarna = "lekarna", prvniPomoc = "prvniPomoc", policie = "policie";
    static final String pamatka = "pamatka", pamatnyStrom = "pamatnyStrom", vyznamnyStrom = "vyznamnyStrom", zajimavost = "zajimavost";
    static final String remeslnik = "remeslnik", restaurace = "restaurace", obchod = "obchod";
    static final String children = "children", sport = "sport", associations = "associations";
    static final String waste = "waste", wasteElectro = "wasteElectro", wasteTextile = "wasteTextile", wasteGeneral = "wasteGeneral";
    static final String nehoda = "nehoda", uzavirka = "uzavirka";

    //---------------------------------------------------------------------------
    static String categoryLocalName(String category, Context ctx) {
        if (category == null) return "";
        Resources res = ctx.getResources();
        switch (category) {
            case informace: return res.getString(R.string.c_information);
            case lekarna: return res.getString(R.string.c_pharmacies);
            case prvniPomoc: return res.getString(R.string.c_first_aid);
            case policie: return res.getString(R.string.c_police);
            case pamatka: return res.getString(R.string.c_landmarks);
            case pamatnyStrom: return res.getString(R.string.c_memorial_trees);
            case vyznamnyStrom: return res.getString(R.string.c_significant_trees);
            case zajimavost: return res.getString(R.string.c_points_of_interest);
            case remeslnik: return res.getString(R.string.c_artisans);
            case restaurace: return res.getString(R.string.c_restaurants);
            case obchod: return res.getString(R.string.c_shops);
            case children: return res.getString(R.string.c_children);
            case sport: return res.getString(R.string.c_sport);
            case associations: return res.getString(R.string.c_associations);
            case waste: return res.getString(R.string.c_waste_dumpsters);
            case wasteElectro: return res.getString(R.string.c_waste_electro);
            case wasteTextile: return res.getString(R.string.c_waste_textile);
            case wasteGeneral: return res.getString(R.string.c_waste);
            case nehoda: return res.getString(R.string.c_accident);
            case uzavirka: return res.getString(R.string.c_roadblock);
        }
        return category;
    }

    //---------------------------------------------------------------------------
    static int categoryIconName(String category) {
        if (category == null) return -1;
        switch (category) {
            case informace: return R.drawable.c_info;
            case lekarna: return R.drawable.c_pharmacy;
            case prvniPomoc: return R.drawable.c_firstaid;
            case policie: return R.drawable.c_police;
            case pamatka: return R.drawable.c_monument;
            case pamatnyStrom: return R.drawable.c_tree;
            case vyznamnyStrom: return R.drawable.c_tree;
            case zajimavost: return R.drawable.c_trekking;
            case remeslnik: return R.drawable.c_work;
            case restaurace: return R.drawable.c_restaurant;
            case obchod: return R.drawable.c_shop;
            case children: return R.drawable.c_children;
            case sport: return R.drawable.c_sport;
            case associations: return R.drawable.c_usergroups;
            case waste: return R.drawable.c_waste;
            case wasteElectro: return R.drawable.c_electrical;
            case wasteTextile: return R.drawable.c_textile;
            case wasteGeneral: return R.drawable.c_recycle;
            case nehoda: return R.drawable.c_accident;
            case uzavirka: return R.drawable.c_roadblock;
            default: return -1;
        }
    }
}

//---------------------------------------------------------------------------
class CRxEventRecord
{
    String m_sTitle = "";
    String m_sInfoLink = null;
    String m_sBuyLink = null;
    String m_eCategory = null;
    String m_sFilter = null;  // filter records accoring to this member
    String m_sText = null;
    Date m_aDate = null;      // date and time of an event start or publish date of an article
    Date m_aDateTo = null;    // date and time of an evend end
    String m_sAddress = null; // location address
    Location m_aLocation = null;    // event location
    Location m_aLocCheckIn = null;  // location for game check-in (usually not preset)
    String m_sPhoneNumber = null;
    String m_sEmail = null;
    String m_sContactNote = null;
    ArrayList<CRxHourInterval> m_arrOpeningHours = null;
    ArrayList<CRxEventInterval> m_arrEvents = null;

    // members for display only, not stored or read in the record
    double m_distFromUser = Double.MAX_VALUE;
    boolean m_bMarkFavorite = false;      // saved news, marked dumpsters

    CRxEventRecord(String title) {
        super();
        m_sTitle = title;
    }

    static Date loadDate(String string) {
        if (string == null) return null;
        SimpleDateFormat df = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm", Locale.US);
        Date date = null;
        try {
            date = df.parse(string);
        }
        catch (ParseException e) {}
        return date;
    }

    static String saveDate(Date date) {
        if (date == null) return null;
        SimpleDateFormat df = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm", Locale.US);
        return df.format(date);
    }

    //---------------------------------------------------------------------------
    static CRxEventRecord fromJson(JSONObject jsonItem) {
        String sTitle = "";
        try {
            sTitle = jsonItem.getString("title");
        }
        catch (JSONException e) { return null; }
        if (sTitle.isEmpty()) return null;

        CRxEventRecord pThis = new CRxEventRecord(sTitle);
        pThis.m_sInfoLink = jsonItem.optString("infoLink", null);
        pThis.m_sBuyLink = jsonItem.optString("buyLink", null);
        pThis.m_eCategory = jsonItem.optString("category", null);
        pThis.m_sFilter = jsonItem.optString("filter", null);
        pThis.m_sText = jsonItem.optString("text", null);
        pThis.m_sPhoneNumber = jsonItem.optString("phone", null);
        pThis.m_sEmail = jsonItem.optString("email", null);
        pThis.m_sContactNote = jsonItem.optString("contactNote", null);
        pThis.m_sAddress = jsonItem.optString("address", null);
        pThis.m_aDate = loadDate(jsonItem.optString("date", null));
        pThis.m_aDateTo = loadDate(jsonItem.optString("dateTo", null));

        try {
            String locationLat = jsonItem.getString("locationLat");
            String locationLong = jsonItem.getString("locationLong");
            double dLocLat = Double.parseDouble(locationLat);
            double dLocLong = Double.parseDouble(locationLong);
            pThis.m_aLocation = new Location("json");
            pThis.m_aLocation.setLatitude(dLocLat);
            pThis.m_aLocation.setLongitude(dLocLong);
        }
        catch (Exception e) {}

        try {
            String locationLat = jsonItem.getString("checkinLocationLat");
            String locationLong = jsonItem.getString("checkinLocationLong");
            double dLocLat = Double.parseDouble(locationLat);
            double dLocLong = Double.parseDouble(locationLong);
            pThis.m_aLocCheckIn = new Location("json");
            pThis.m_aLocCheckIn.setLatitude(dLocLat);
            pThis.m_aLocCheckIn.setLongitude(dLocLong);
        }
        catch (Exception e) {}

        try {
            String hours = jsonItem.getString("openingHours");
            pThis.m_arrOpeningHours = new ArrayList<CRxHourInterval>();
            String[] lstDays = hours.replaceAll(" ", "").split(",");
            for (String dayIt : lstDays) {
                CRxHourInterval interval = CRxHourInterval.fromString(dayIt);
                if (interval != null)
                    pThis.m_arrOpeningHours.add(interval);
            }
        }
        catch (JSONException e) {}

        try {
            String hours = jsonItem.getString("events");
            pThis.m_arrEvents = new ArrayList<CRxEventInterval>();
            String[] lstEvents = hours.split("\\|");
            for (String it : lstEvents) {
                CRxEventInterval interval = CRxEventInterval.fromString(it);
                if (interval != null)
                    pThis.m_arrEvents.add(interval);
            }
            Collections.sort(pThis.m_arrEvents, new Comparator<CRxEventInterval>() {
                @Override
                public int compare(CRxEventInterval t0, CRxEventInterval t1) {
                    return t0.m_dateStart.compareTo(t1.m_dateStart);
                }
            });
        }
        catch (JSONException e) {}
        return pThis;
    }

    //---------------------------------------------------------------------------
    JSONObject saveToJSON() {
        JSONObject item = new JSONObject();
        try { item.put("title", m_sTitle); } catch (JSONException e) {}
        try { item.put("infoLink", m_sInfoLink); } catch (JSONException e) {}
        try { item.put("buyLink", m_sBuyLink); } catch (JSONException e) {}
        try { item.put("category", m_eCategory); } catch (JSONException e) {}
        try { item.put("filter", m_sFilter); } catch (JSONException e) {}
        try { item.put("text", m_sText); } catch (JSONException e) {}
        try { item.put("phone", m_sPhoneNumber); } catch (JSONException e) {}
        try { item.put("email", m_sEmail); } catch (JSONException e) {}
        try { item.put("contactNote", m_sContactNote); } catch (JSONException e) {}
        try { item.put("address", m_sAddress); } catch (JSONException e) {}
        try { item.put("date", saveDate(m_aDate)); } catch (JSONException e) {}
        try { item.put("dateTo", saveDate(m_aDateTo)); } catch (JSONException e) {}
        if (m_aLocation != null) {
            try { item.put("locationLat", Double.toString(m_aLocation.getLatitude())); } catch (JSONException e) {}
            try { item.put("locationLong", Double.toString(m_aLocation.getLongitude())); } catch (JSONException e) {}
        }
        if (m_aLocCheckIn != null) {
            try { item.put("checkinLocationLat", Double.toString(m_aLocCheckIn.getLatitude())); } catch (JSONException e) {}
            try { item.put("checkinLocationLong", Double.toString(m_aLocCheckIn.getLongitude())); } catch (JSONException e) {}
        }
        if (m_arrOpeningHours != null) {
            String sVal = "";
            for (CRxHourInterval it: m_arrOpeningHours) {
                if (!sVal.isEmpty())
                    sVal += ", ";
                sVal += it.toString();
            }
            try { item.put("openingHours", sVal); } catch (JSONException e) {}
        }
        if (m_arrEvents != null) {
            String sVal = "";
            for (CRxEventInterval it: m_arrEvents) {
                if (!sVal.isEmpty())
                    sVal += "|";
                sVal += it.toString();
            }
            try { item.put("events", sVal); } catch (JSONException e) {}
        }
        return item;
    }

    //---------------------------------------------------------------------------
    String infoLinkUrl() {
        if (m_sInfoLink != null) {
            String link = m_sInfoLink;
            if (m_sInfoLink.contains("?"))
                link += "&";
            else
                link += "?";
            link += "utm_source=dvanactka.info&utm_medium=app";
            return link;
        }
        return null;
    }

    //---------------------------------------------------------------------------
    void openInfoLink(Activity sender) {
        String sUrl = infoLinkUrl();
        if (sUrl != null)
            CRxEventRecord.openWebUrl(sUrl, sender);
    }

    //---------------------------------------------------------------------------
    void openBuyLink(Activity sender) {
        if (m_sBuyLink != null)
            CRxEventRecord.openWebUrl(m_sBuyLink, sender);
    }

    //---------------------------------------------------------------------------
    static void openWebUrl(String sUrl, Activity sender) {
        boolean bOK = false;
        try {
            // try using Custom Chrome Tabs first https://developer.chrome.com/multidevice/android/customtabs
            CustomTabsIntent.Builder builder = new CustomTabsIntent.Builder();
            builder.setToolbarColor(sender.getResources().getColor(R.color.colorActionBarBkg))
                    .setShowTitle(true)
                    .addDefaultShareMenuItem();
            CustomTabsIntent customTabsIntent = builder.build();
            customTabsIntent.intent.setPackage("com.android.chrome");
            customTabsIntent.launchUrl(sender, Uri.parse(sUrl));
            bOK = true;
        }
        catch (Exception e) { bOK = false; }

        if (!bOK) { // fallback - open in default browser
            try {
                Intent browserIntent = new Intent(Intent.ACTION_VIEW, Uri.parse(sUrl));
                sender.startActivity(browserIntent);
            } catch (Exception e) {
                e.printStackTrace();
            }
        }
    }

    //---------------------------------------------------------------------------
    String recordHash() {
        String sHash = m_sTitle;
        if (m_aDate != null) {
            sHash += String.valueOf(m_aDate.hashCode());
        }
        return sHash;
    }

    //---------------------------------------------------------------------------
    Location gameCheckInLocation() {
        if (m_aLocCheckIn != null) {
            return m_aLocCheckIn;
        }
        return m_aLocation;
    }

    //---------------------------------------------------------------------------
    CRxEventInterval nextEventOccurence() {
        if (m_arrEvents == null) return null;
        // find next container at this location (intervals are pre-sorted)
        Calendar c = Calendar.getInstance();
        Date dayToday = c.getTime();

        int iBest = 0;
        for (CRxEventInterval aInt : m_arrEvents)
        {
            if (aInt.m_dateEnd.after(dayToday))
                break;
            else
                iBest++;
        }
        if (iBest >= m_arrEvents.size())
            iBest = (int)m_arrEvents.size()-1; // not found, show last past

        return m_arrEvents.get(iBest);
    }

    //---------------------------------------------------------------------------
    String nextEventOccurenceString(Context ctx) {
        CRxEventInterval aInt = nextEventOccurence();
        if (aInt != null) {
            return aInt.toRelativeIntervalString(ctx);
        }
        return null;
    }

    //---------------------------------------------------------------------------
    CRxEventInterval currentEvent() {
        if (m_arrEvents == null) return null;
        // find current event (intervals are pre-sorted)
        Calendar c = Calendar.getInstance();
        Date dayToday = c.getTime();

        for (CRxEventInterval aInt : m_arrEvents) {
            if (aInt.m_dateStart.after(dayToday) && dayToday.before(aInt.m_dateEnd)) {
                return aInt;
            }
        }
        return null;
    }

    //---------------------------------------------------------------------------
    String todayOpeningHoursString(Context ctx) {
        if (m_arrOpeningHours == null) return null;

        Calendar c = Calendar.getInstance();
        int iWeekday = c.get(Calendar.DAY_OF_WEEK);

        iWeekday -= 1;
        if (iWeekday <= 0) {
            iWeekday += 7;
        }

        String sString = "";
        for (CRxHourInterval aInt: m_arrOpeningHours) {
            if (aInt.m_weekday == iWeekday) {
                if (sString.isEmpty()) {
                    sString = aInt.toIntervalDisplayString();
                }
                else {
                    sString += " " + aInt.toIntervalDisplayString();
                }
            }
        }
        Resources res = ctx.getResources();
        if (sString.isEmpty()) {
            return res.getString(R.string.closed_today);
        }
        return res.getString(R.string.today) + " " + sString;
    }

    //---------------------------------------------------------------------------
    private static final Pattern ACCENTS_PATTERN = Pattern.compile("\\p{InCombiningDiacriticalMarks}+");

    boolean containsSearch(String sExpr, Context ctx) {
        //Collator insensitiveComparator = Collator.getInstance();
        //insensitiveComparator.setStrength(Collator.PRIMARY);      // this is unfortunately only for comparing not "contains"

        Locale loc = Locale.getDefault();
        String sExprNorm = ACCENTS_PATTERN.matcher(Normalizer.normalize(sExpr, Normalizer.Form.NFD)).replaceAll("").toLowerCase(loc);

        String sTitleNorm = ACCENTS_PATTERN.matcher(Normalizer.normalize(m_sTitle, Normalizer.Form.NFD)).replaceAll("").toLowerCase(loc);
        if (sTitleNorm.contains(sExprNorm))
            return true;
        if (m_eCategory != null) {
            String sCategoryNorm = ACCENTS_PATTERN.matcher(Normalizer.normalize(CRxCategory.categoryLocalName(m_eCategory, ctx), Normalizer.Form.NFD)).replaceAll("").toLowerCase(loc);
            if (sCategoryNorm.contains(sExprNorm))
                return true;
        }
        if (m_sFilter != null) {
            String sFilterNorm = ACCENTS_PATTERN.matcher(Normalizer.normalize(m_sFilter, Normalizer.Form.NFD)).replaceAll("").toLowerCase(loc);
            if (sFilterNorm.contains(sExprNorm))
                return true;
        }
        if (m_sText != null) {
            String sTextNorm = ACCENTS_PATTERN.matcher(Normalizer.normalize(m_sText, Normalizer.Form.NFD)).replaceAll("").toLowerCase(loc);
            if (sTextNorm.contains(sExprNorm))
                return true;
        }
        return false;
    }

}
