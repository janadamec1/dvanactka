package com.roomarranger.android.dvanactka;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.DialogInterface;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.drawable.BitmapDrawable;
import android.net.Uri;
import android.os.Bundle;
import android.text.Html;
import android.view.MenuItem;
import android.view.View;
import android.widget.Button;
import android.widget.CheckBox;
import android.widget.CompoundButton;
import android.widget.TextView;
import android.widget.Toast;

import com.google.android.gms.maps.CameraUpdate;
import com.google.android.gms.maps.CameraUpdateFactory;
import com.google.android.gms.maps.GoogleMap;
import com.google.android.gms.maps.MapFragment;
import com.google.android.gms.maps.OnMapReadyCallback;
import com.google.android.gms.maps.UiSettings;
import com.google.android.gms.maps.model.BitmapDescriptorFactory;
import com.google.android.gms.maps.model.LatLng;
import com.google.android.gms.maps.model.MarkerOptions;

import java.net.URLDecoder;
import java.text.DateFormat;
import java.text.DateFormatSymbols;
import java.util.Locale;

public class PlaceDetailCtl extends Activity implements OnMapReadyCallback {
    TextView m_lbTitle;
    TextView m_lbCategory;
    TextView m_lbValidDates;
    TextView m_lbText;
    TextView m_lbAddressTitle;
    TextView m_lbAddress;
    TextView m_lbOpeningHoursTitle;
    TextView m_lbOpeningHours;
    TextView m_lbOpeningHours2;
    TextView m_lbNote;
    Button m_btnWebsite;
    Button m_btnEmail;
    Button m_btnPhone;
    GoogleMap m_map;
    CheckBox m_chkShowNotifications;
    TextView m_lbNotificationExplanation;
    TextView m_lbContactNote;
    Button m_btnNavigate;
    Button m_btnReportMistake;
    TextView m_lbGame;
    TextView m_lbGameDist;
    Button m_btnGameCheckIn;

    CRxEventRecord rec = null;
    CRxDetailRefreshParentDelegate m_refreshParentDelegate = null;

    enum EGameStatus {
         disabled, tracking, visited
    }
    EGameStatus m_eGameStatus = EGameStatus.disabled;
    boolean m_bGameWrongTime = false;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_place_detail_ctl);

        m_refreshParentDelegate = EventCtl.g_CurrentRefreshDelegate;
        EventCtl.g_CurrentRefreshDelegate = null;

        String sDataSource = getIntent().getStringExtra(MainActivity.EXTRA_DATASOURCE);
        String sRecordHash = getIntent().getStringExtra(MainActivity.EXTRA_EVENT_RECORD);
        if (sDataSource == null || sRecordHash == null) return;
        CRxDataSource aDs = CRxDataSourceManager.sharedInstance().m_dictDataSources.get(sDataSource);
        if (aDs == null) return;
        rec = aDs.recordWithHash(sRecordHash);
        if (rec == null) return;

        m_lbTitle = (TextView)findViewById(R.id.title);
        m_lbCategory = (TextView)findViewById(R.id.category);
        m_lbValidDates = (TextView)findViewById(R.id.date);
        m_lbText = (TextView)findViewById(R.id.text);
        m_lbAddressTitle = (TextView)findViewById(R.id.address_title);
        m_lbAddress = (TextView)findViewById(R.id.address);
        m_lbOpeningHoursTitle = (TextView)findViewById(R.id.hours_title);
        m_lbOpeningHours = (TextView)findViewById(R.id.hours);
        m_lbOpeningHours2 = (TextView)findViewById(R.id.hours2);
        m_lbNote = (TextView)findViewById(R.id.note);
        m_btnWebsite = (Button)findViewById(R.id.btnWebsite);
        m_btnEmail = (Button)findViewById(R.id.btnEmail);
        m_btnPhone = (Button)findViewById(R.id.btnPhone);
        //m_map: MKMapView!
        m_chkShowNotifications = (CheckBox)findViewById(R.id.chkNotifications);
        m_lbNotificationExplanation = (TextView)findViewById(R.id.notificationNote);
        m_lbContactNote = (TextView)findViewById(R.id.contactNote);
        m_btnNavigate = (Button)findViewById(R.id.btnNavigate);
        m_btnReportMistake = (Button)findViewById(R.id.btnReportMistake);
        m_lbGame = (TextView)findViewById(R.id.gameTitle);
        m_lbGameDist = (TextView)findViewById(R.id.gameDistance);
        m_btnGameCheckIn = (Button)findViewById(R.id.btnGameCheckIn);

        setTitle("  "); // empty action bar title
        m_lbTitle.setText(rec.m_sTitle);
        m_lbText.setText(rec.m_sText);
        substituteRecordText();

        if (rec.m_eCategory != null) {
            String sCat = CRxCategory.categoryLocalName(rec.m_eCategory, this);
            if (rec.m_sFilter != null) {
                sCat += " - " + rec.m_sFilter;
            }
            m_lbCategory.setText(sCat);
        }
        else {
            m_lbCategory.setVisibility(View.GONE);
        }

        if (rec.m_aDate != null) {
            if (rec.m_aDateTo != null) {
                CRxEventInterval aInterval = new CRxEventInterval(rec.m_aDate, rec.m_aDateTo, "");
                m_lbValidDates.setText(aInterval.toDisplayString());
            }
            else {
                m_lbValidDates.setText(DateFormat.getDateTimeInstance(DateFormat.LONG, DateFormat.SHORT).format(rec.m_aDate));
            }
        }
        else {
            m_lbValidDates.setVisibility(View.GONE);
        }

        if (rec.m_sAddress != null) {
            m_lbAddress.setText(rec.m_sAddress);
        }
        else {
            m_lbAddressTitle.setVisibility(View.GONE);
            m_lbAddress.setVisibility(View.GONE);
        }
        m_lbNote.setVisibility(View.GONE);
        m_chkShowNotifications.setVisibility(View.GONE);
        m_lbNotificationExplanation.setVisibility(View.GONE);

        if (rec.m_arrOpeningHours != null) {
            DateFormatSymbols symbols = new DateFormatSymbols();
            String[] dayNames = symbols.getShortWeekdays();
            String sDays = "";
            String sHours = "";
            int iLastDay = 0;
            for (CRxHourInterval it : rec.m_arrOpeningHours) {
                String sWeekDay = dayNames[(it.m_weekday % 7)+ 1];
                String sRange = " " + it.toIntervalDisplayString();
                if (iLastDay == it.m_weekday) {
                    sHours += sRange;    // another interval within same day
                }
                else {
                    if (!sHours.isEmpty()) {
                        sHours += "\n";
                        sDays += "\n";
                    }
                    sDays += sWeekDay + ": ";
                    sHours += sRange;
                    iLastDay = it.m_weekday;
                }
            }
            m_lbOpeningHours.setText(sDays);
            m_lbOpeningHours2.setText(sHours);
        }
        else if (rec.m_arrEvents != null) {
            String sType = "";
            String sHours = "";
            boolean bHasVok = false;
            boolean bHasBio = false;
            for (CRxEventInterval it: rec.m_arrEvents) {
                if (!sHours.isEmpty()) {
                    sHours += "\n";
                    sType += "\n";
                }
                sType += it.m_sType + ": ";
                sHours += it.toDisplayString();

                if (it.m_sType.equals("obj. odpad")) {
                    bHasVok = true;
                }
                else if (it.m_sType.equals("bioodpad") || it.m_sType.equals("větve")) {
                    bHasBio = true;
                }

            }
            m_lbOpeningHoursTitle.setText(R.string.timetable);
            m_lbOpeningHours.setText(sType);
            m_lbOpeningHours2.setText(sHours);

            if (bHasVok || bHasBio) {
                String sNote = "";
                if (bHasVok) { sNote = getString(R.string.waste_vok_longdesc); }
                //if bHasVok && bHasBio { sNote += "\n"; }
                //if bHasBio { sNote += NSLocalizedString("Waste.bio.longdesc", comment: ""); }
                m_lbNote.setText(sNote);
                m_lbNote.setVisibility(View.VISIBLE);
            }
            m_chkShowNotifications.setVisibility(View.VISIBLE);
            m_lbNotificationExplanation.setVisibility(View.VISIBLE);
            m_chkShowNotifications.setChecked(rec.m_bMarkFavorite);
        }
        else {
            m_lbOpeningHoursTitle.setVisibility(View.GONE);
            m_lbOpeningHours.setVisibility(View.GONE);
            m_lbOpeningHours2.setVisibility(View.GONE);
        }

        if (rec.m_eCategory != null) {
            if (rec.m_eCategory.equals(CRxCategory.wasteTextile)) {
                m_lbNote.setText(R.string.waste_textile_longdesc);
                m_lbNote.setVisibility(View.VISIBLE);
            } else if (rec.m_eCategory.equals(CRxCategory.wasteElectro)) {
                m_lbNote.setText(R.string.waste_electro_longdesc);
                m_lbNote.setVisibility(View.VISIBLE);;
            }
        }

        if (rec.m_sInfoLink != null) {
            String link = rec.m_sInfoLink;
            try {
                link = URLDecoder.decode(link, "UTF-8");
            } catch(Exception e) {}
            m_btnWebsite.setText(link);  // remove percent encoding
        }
        else {
            m_btnWebsite.setVisibility(View.GONE);
        }
        if (rec.m_sContactNote != null) {
            m_lbContactNote.setText(rec.m_sContactNote);
        }
        else {
            m_lbContactNote.setVisibility(View.GONE);
        }
        if (rec.m_sEmail != null) {
            m_btnEmail.setText(rec.m_sEmail);
        }
        else {
            m_btnEmail.setVisibility(View.GONE);
        }
        if (rec.m_sPhoneNumber != null) {
            m_btnPhone.setText(rec.m_sPhoneNumber);
        }
        else {
            m_btnPhone.setVisibility(View.GONE);
        }

        MapFragment mapFragment = (MapFragment)(getFragmentManager().findFragmentById(R.id.map));
        if (rec.m_aLocation != null) {
            // Obtain the SupportMapFragment and get notified when the map is ready to be used.
            mapFragment.getMapAsync(this);

            /*let regView = MKCoordinateRegionMakeWithDistance(location.coordinate, 500, 500);
            m_map.setRegion(regView, animated:false);
            m_map.addAnnotation(CRxMapItem(record: rec));
            m_map.delegate = self;

            if CLLocationManager.locationServicesEnabled() && CLLocationManager.authorizationStatus() == .authorizedWhenInUse {
                m_map.showsUserLocation = true;
            }

            if (rec.m_aLocCheckIn != null) {
                m_map.addAnnotation(CRxMapItem(record: rec, forCheckIn: true));
            }*/
        }
        else {
            try {
                mapFragment.getView().setVisibility(View.GONE);
            } catch (Exception e) {}
            m_btnNavigate.setVisibility(View.GONE);
        }

        if (rec.m_aLocation != null && CRxGame.isCategoryCheckInAble(rec.m_eCategory)) {
            if (CRxGame.sharedInstance.playerWas(rec)) {
                m_eGameStatus = EGameStatus.visited;
                m_lbGameDist.setText(R.string.you_were_already_here);
                m_btnGameCheckIn.setVisibility(View.GONE);
            }
            else {
                // init tracking
                if (rec.m_arrEvents != null && rec.currentEvent() == null) {    // checkin at VOK location is also limited to time
                    m_bGameWrongTime = true;
                }
                m_eGameStatus = EGameStatus.tracking;
                m_lbGameDist.setText("N/A");
                m_btnGameCheckIn.setEnabled(false);

                /*m_locManager.delegate = self;
                m_locManager.distanceFilter = 4;
                if CLLocationManager.authorizationStatus() == .authorizedWhenInUse {
                    m_locManager.startUpdatingLocation();
                }*/
            }
        }
        else {
            m_lbGame.setVisibility(View.GONE);
            m_lbGameDist.setVisibility(View.GONE);
            m_btnGameCheckIn.setVisibility(View.GONE);
        }

        // define button actions
        m_btnWebsite.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                rec.openInfoLink(PlaceDetailCtl.this);
            }
        });
        if (rec.m_sPhoneNumber != null) {
            m_btnPhone.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View view) {
                    AlertDialog.Builder builder = new AlertDialog.Builder(PlaceDetailCtl.this);
                    builder.setMessage(R.string.call_prompt);
                    builder.setPositiveButton(R.string.yes, new DialogInterface.OnClickListener()
                    {
                        public void onClick(DialogInterface dialog, int which) {
                            dialog.dismiss();

                            Intent intent = new Intent(Intent.ACTION_CALL);
                            intent.setData(Uri.parse("tel:" + rec.m_sPhoneNumber.replace(" ", "")));
                            startActivity(intent);
                        }
                    });

                    builder.setNegativeButton(R.string.no, new DialogInterface.OnClickListener()
                    {
                        @Override
                        public void onClick(DialogInterface dialog, int which) {
                            dialog.dismiss();
                        }
                    });

                    AlertDialog alert = builder.create();
                    alert.show();
                }
            });
        }
        if (rec.m_sEmail != null) {
            m_btnEmail.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View view) {
                    Intent intent = new Intent(Intent.ACTION_SEND);
                    intent.setType("message/rfc822");
                    intent.putExtra(Intent.EXTRA_EMAIL, new String[]{rec.m_sEmail});

                    if (rec.m_eCategory != null) {
                        if (rec.m_eCategory.equals(CRxCategory.wasteTextile) || rec.m_eCategory.equals(CRxCategory.waste) || rec.m_eCategory.equals(CRxCategory.wasteElectro)) {
                            intent.putExtra(Intent.EXTRA_SUBJECT, rec.m_sTitle + ", Praha 12 - " + CRxCategory.categoryLocalName(rec.m_eCategory, PlaceDetailCtl.this));
                            intent.putExtra(Intent.EXTRA_TEXT, getString(R.string.please_describe_problem));
                        }
                    }
                    try {
                        startActivity(Intent.createChooser(intent, getString(R.string.send_mail)));
                    } catch (android.content.ActivityNotFoundException ex) {
                        Toast.makeText(PlaceDetailCtl.this, "There are no email clients installed.", Toast.LENGTH_SHORT).show();
                    }
                }
            });
        }
        m_btnReportMistake.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                Intent intent = new Intent(Intent.ACTION_SEND);
                intent.setType("message/rfc822");
                intent.putExtra(Intent.EXTRA_EMAIL, new String[]{"info@dvanactka.info"});
                intent.putExtra(Intent.EXTRA_SUBJECT, rec.m_sTitle + " - " + CRxCategory.categoryLocalName(rec.m_eCategory, PlaceDetailCtl.this) + " - problem (Android)");
                intent.putExtra(Intent.EXTRA_TEXT, getString(R.string.please_describe_problem));
                try {
                    startActivity(Intent.createChooser(intent, getString(R.string.send_mail)));
                } catch (android.content.ActivityNotFoundException ex) {
                    Toast.makeText(PlaceDetailCtl.this, "There are no email clients installed.", Toast.LENGTH_SHORT).show();
                }
            }
        });

        if (m_chkShowNotifications.getVisibility() != View.GONE) {
            m_chkShowNotifications.setOnCheckedChangeListener(new CompoundButton.OnCheckedChangeListener() {
                @Override
                public void onCheckedChanged(CompoundButton compoundButton, boolean bChecked) {
                    rec.m_bMarkFavorite = bChecked;
                    CRxDataSourceManager.sharedInstance().setFavorite(rec.m_sTitle, rec.m_bMarkFavorite);
                    if (m_refreshParentDelegate != null)
                        m_refreshParentDelegate.detailRequestsRefresh(); // change star icon, resort
                }
            });
        }
        if (rec.m_aLocation != null) {
            m_btnNavigate.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View view) {
                    String sLoc = String.format(Locale.US, "%.4f,%.4f", rec.m_aLocation.getLatitude(), rec.m_aLocation.getLongitude());
                    String sTitle = rec.m_sTitle.replaceAll(" ", "+");
                    Uri gmmIntentUri = Uri.parse("google.navigation:q=" + sLoc + "(" + sTitle + ")&mode=w");
                    Intent mapIntent = new Intent(Intent.ACTION_VIEW, gmmIntentUri);
                    mapIntent.setPackage("com.google.android.apps.maps");
                    startActivity(mapIntent);
                }
            });
        }
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        switch (item.getItemId()) {
            // Respond to the action bar's Up/Home button
            case android.R.id.home:
                onBackPressed();        // go to the activity that brought user here, not to parent activity
                return true;
        }
        return super.onOptionsItemSelected(item);
    }

    @Override
    public void onMapReady(GoogleMap googleMap) {
        m_map = googleMap;

        LatLng coord = MapCtl.loc2LatLng(rec.m_aLocation);

        MarkerOptions opt = new MarkerOptions().position(coord)
                .title(rec.m_sTitle);
        int iIcon = CRxCategory.categoryIconName(rec.m_eCategory);
        if (iIcon != -1)
            opt = opt.icon(BitmapDescriptorFactory.fromResource(iIcon));
        m_map.addMarker(opt);

        if (rec.m_aLocCheckIn != null) {
            m_map.addMarker(new MarkerOptions().position(MapCtl.loc2LatLng(rec.m_aLocCheckIn))
                    .icon(BitmapDescriptorFactory.defaultMarker(BitmapDescriptorFactory.HUE_AZURE)));
        }

        CameraUpdate cameraUpdate = CameraUpdateFactory.newLatLngZoom(coord, 15);
        m_map.moveCamera(cameraUpdate);

        UiSettings settings = m_map.getUiSettings();
        settings.setZoomControlsEnabled(true);
    }

    //--------------------------------------------------------------------------
    void substituteRecordText() {
        if (rec == null || rec.m_sText == null) return;
        if (rec.m_sText.equals("FAQ")) {

            String sNewText = "";
            sNewText += "<b>Kde se nechat vyfotit na průkazovou fotografii?</b><br>Ve Fotolabu na Sofijském náměstí.<br><br>";
            sNewText += "<b>Obtížné parkování před poliklinikou?</b><br>Volná místa najdete na parkovišti dostupném z ulice Povodňová, od kterého pak projdete pěšky ulicí Amortova. Při parkování přímo před vchodem do polikliniky musíte navíc použít parkovací hodiny.<br><br>";
            m_lbText.setText(Html.fromHtml(sNewText.toString()));
        }
    }
}
