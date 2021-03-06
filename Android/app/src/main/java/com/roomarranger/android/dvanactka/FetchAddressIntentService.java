package com.roomarranger.android.dvanactka;

import android.app.IntentService;
import android.content.Intent;
import android.location.Address;
import android.location.Geocoder;
import android.location.Location;
import android.os.Bundle;
import android.os.ResultReceiver;
import android.text.TextUtils;
import android.util.Log;

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

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

// from https://developer.android.com/reference/android/location/Address.html

public class FetchAddressIntentService extends IntentService {
    public static final int SUCCESS_RESULT = 0;
    public static final int FAILURE_RESULT = 1;
    public static final String PACKAGE_NAME = "com.roomarranger.dvanactka";
    public static final String RECEIVER = PACKAGE_NAME + ".RECEIVER";
    public static final String RESULT_DATA_KEY = PACKAGE_NAME + ".RESULT_DATA_KEY";
    public static final String LOCATION_DATA_EXTRA = PACKAGE_NAME + ".LOCATION_DATA_EXTRA";

    protected ResultReceiver mReceiver;

    public FetchAddressIntentService() {
        super("FetchAddressIntentService");
    }

    @Override
    protected void onHandleIntent(Intent intent) {
        String errorMessage = "";

        mReceiver = intent.getParcelableExtra(FetchAddressIntentService.RECEIVER);

        // Check if receiver was properly registered.
        if (mReceiver == null) {
            Log.wtf("Loc2Addr", "No receiver received. There is nowhere to send the results.");
            return;
        }

        // Get the location passed to this service through an extra.
        Location location = intent.getParcelableExtra(FetchAddressIntentService.LOCATION_DATA_EXTRA);

        Geocoder geocoder = new Geocoder(this, Locale.getDefault());

        List<Address> addresses = null;

        try {
            addresses = geocoder.getFromLocation(
                    location.getLatitude(),
                    location.getLongitude(),
                    // In this sample, get just a single address.
                    1);
        } catch (IOException ioException) {
            // Catch network or other I/O problems.
            errorMessage = "service_not_available";
            Log.e("Loc2Addr", errorMessage, ioException);
        } catch (IllegalArgumentException illegalArgumentException) {
            // Catch invalid latitude or longitude values.
            errorMessage = "invalid_lat_long_used";
            Log.e("Loc2Addr", errorMessage + ". " +
                    "Latitude = " + location.getLatitude() +
                    ", Longitude = " +
                    location.getLongitude(), illegalArgumentException);
        }

        // Handle case where no address was found.
        if (addresses == null || addresses.size()  == 0) {
            if (errorMessage.isEmpty()) {
                errorMessage = "No address found";
                Log.e("Loc2Addr", errorMessage);
            }
            deliverResultToReceiver(FetchAddressIntentService.FAILURE_RESULT, errorMessage);
        } else {
            Address address = addresses.get(0);
            ArrayList<String> addressFragments = new ArrayList<String>();

            // Fetch the address lines using getAddressLine,
            // join them, and send them to the thread.
            String sAddressOnLines = "";
            if (address.getMaxAddressLineIndex() > 0) {
                for (int i = 0; i < address.getMaxAddressLineIndex(); i++) {
                    addressFragments.add(address.getAddressLine(i));
                }
                sAddressOnLines = TextUtils.join(System.getProperty("line.separator"),
                        addressFragments);
            }
            else {
                // new version of Geocoder returns everything at index 0
                try {
                    sAddressOnLines = address.getAddressLine(0);
                    sAddressOnLines = sAddressOnLines.replaceAll(", ", System.getProperty("line.separator"));
                } catch (Exception ignored) {}
            }
            if (!sAddressOnLines.isEmpty()) {
                Log.i("Loc2Addr", "address found");
                deliverResultToReceiver(FetchAddressIntentService.SUCCESS_RESULT, sAddressOnLines);
            }
        }
    }

    private void deliverResultToReceiver(int resultCode, String message) {
        if (mReceiver == null) return;
        Bundle bundle = new Bundle();
        bundle.putString(FetchAddressIntentService.RESULT_DATA_KEY, message);
        mReceiver.send(resultCode, bundle);
    }
}
