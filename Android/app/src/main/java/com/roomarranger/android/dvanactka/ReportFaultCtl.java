package com.roomarranger.android.dvanactka;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Matrix;
import android.graphics.drawable.BitmapDrawable;
import android.location.Geocoder;
import android.location.Location;
import android.Manifest;
import android.media.ExifInterface;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.provider.MediaStore;
import android.support.v4.content.ContextCompat;
import android.support.v4.content.FileProvider;
import android.support.v4.os.ResultReceiver;
import android.util.Log;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.view.inputmethod.InputMethodManager;
import android.widget.Button;
import android.widget.EditText;
import android.widget.ImageButton;
import android.widget.TextView;
import android.widget.Toast;

import com.google.android.gms.analytics.HitBuilders;
import com.google.android.gms.analytics.Tracker;
import com.google.android.gms.common.ConnectionResult;
import com.google.android.gms.common.api.GoogleApiClient;
import com.google.android.gms.location.LocationListener;
import com.google.android.gms.location.LocationRequest;
import com.google.android.gms.location.LocationServices;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.List;
import java.util.Locale;

public class ReportFaultCtl extends Activity implements GoogleApiClient.ConnectionCallbacks, GoogleApiClient.OnConnectionFailedListener, LocationListener {

    static final int ACT_RESULT_TAKE_PHOTO = 0;
    static final int ACT_RESULT_PICK_PHOTO = 1;
    static final int ACT_RESULT_REFINE_LOCATION = 2;

    ImageButton m_btnPhoto;
    EditText m_edDescription;
    TextView m_lbLocation;
    Button m_btnRefineLocation;

    boolean m_bImageSelected = false;
    boolean m_bImageOmitted = false;
    File m_fileFromCamera;
    GoogleApiClient m_GoogleApiClient = null;
    LocationRequest m_LocationRequest;
    Location m_location = null;
    boolean m_bLocationRefined = false;
    private AddressResultReceiver m_AddressResultReceiver;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_report_fault_ctl);

        setTitle("  "); // empty action bar title

        if (savedInstanceState != null) {
            // save the camera filename in case the activity gets destroyed while capturing
            String sFile = savedInstanceState.getString("m_fileFromCamera");
            if (sFile != null && !sFile.isEmpty())
                m_fileFromCamera = new File(sFile);
        }

        m_btnPhoto = (ImageButton)findViewById(R.id.btnPhoto);
        m_edDescription = (EditText)findViewById(R.id.edDescription);
        m_lbLocation = (TextView)findViewById(R.id.lbLocation);
        m_btnRefineLocation = (Button)findViewById(R.id.btnRefine);

        m_GoogleApiClient = new GoogleApiClient.Builder(this)
                .addConnectionCallbacks(this)
                .addOnConnectionFailedListener(this)
                .addApi(LocationServices.API)
                .build();

        m_LocationRequest = new LocationRequest();
        m_LocationRequest.setInterval(10000);
        m_LocationRequest.setFastestInterval(5000);
        m_LocationRequest.setPriority(LocationRequest.PRIORITY_HIGH_ACCURACY);

        m_AddressResultReceiver = new AddressResultReceiver(new Handler());

        m_btnPhoto.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                hideKeyboard();

                AlertDialog.Builder builder = new AlertDialog.Builder(ReportFaultCtl.this);
                builder.setTitle(R.string.select_photo);
                builder.setPositiveButton(R.string.take_a_photo, new DialogInterface.OnClickListener() {
                    @Override
                    public void onClick(DialogInterface dialogInterface, int i) {
                        Intent intentTakePicture = new Intent(MediaStore.ACTION_IMAGE_CAPTURE);
                        m_fileFromCamera = new File(getCacheDir(), "foto.jpg");
                        Uri uriToStore = FileProvider.getUriForFile(ReportFaultCtl.this, "com.roomarranger.android.dvanactka.fileprovider", m_fileFromCamera);

                        // need to set the permission to all possible camera apps
                        List<ResolveInfo> resInfoList = getPackageManager().queryIntentActivities(intentTakePicture, PackageManager.MATCH_DEFAULT_ONLY);
                        for (ResolveInfo resolveInfo : resInfoList) {
                            String sPackageName = resolveInfo.activityInfo.packageName;
                            grantUriPermission(sPackageName, uriToStore, Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_GRANT_WRITE_URI_PERMISSION);
                        }

                        intentTakePicture.putExtra(MediaStore.EXTRA_OUTPUT, uriToStore);
                        intentTakePicture.setFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_GRANT_WRITE_URI_PERMISSION);
                        startActivityForResult(intentTakePicture, ACT_RESULT_TAKE_PHOTO);
                    }
                });
                builder.setNeutralButton(R.string.from_gallery, new DialogInterface.OnClickListener() {
                    @Override
                    public void onClick(DialogInterface dialogInterface, int i) {
                        Intent pickPhoto = new Intent(Intent.ACTION_PICK,
                                android.provider.MediaStore.Images.Media.EXTERNAL_CONTENT_URI);
                        startActivityForResult(pickPhoto, ACT_RESULT_PICK_PHOTO);
                    }
                });
                builder.create().show();
            }
        });

        m_btnRefineLocation.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                hideKeyboard();

                Intent intent = new Intent(ReportFaultCtl.this, RefineLocCtl.class);
                if (m_location != null) {
                    intent.putExtra(MainActivity.EXTRA_USER_LOCATION_LAT, m_location.getLatitude());
                    intent.putExtra(MainActivity.EXTRA_USER_LOCATION_LONG, m_location.getLongitude());
                }
                startActivityForResult(intent, ACT_RESULT_REFINE_LOCATION);
            }
        });

        // Google Analytics
        Tracker aTracker = MainActivity.getDefaultTracker();
        if (aTracker != null) {
            aTracker.setScreenName("DS_ReportFault");
            aTracker.send(new HitBuilders.ScreenViewBuilder().build());
        }
    }

    //---------------------------------------------------------------------------
    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        // Inflate the menu; this adds items to the action bar if it is present.
        getMenuInflater().inflate(R.menu.menu_report_fault_ctl, menu);
        return true;
    }

    //---------------------------------------------------------------------------
    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        switch (item.getItemId()) {
            // Respond to the action bar's Up/Home button
            case android.R.id.home:
                onBackPressed();        // go to the activity that brought user here, not to parent activity
                return true;

            case R.id.action_send_email:
                onBtnSend();
                return true;
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
                onLocationChanged(aLastLocation);
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
        catch(Exception e) {e.printStackTrace();}
    }

    //---------------------------------------------------------------------------
    @Override
    public void onLocationChanged(Location location) {
        if (m_bLocationRefined) { return; }
        if (location != null) {
            displayLocation(location, null);
            decodeAddressFrom(location);
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
    void showError(String message, View viewSetFocus) {
        AlertDialog.Builder builder = new AlertDialog.Builder(this);
        builder.setMessage(message);
        /*  // this requires API 17
        builder.setOnDismissListener(new DialogInterface.OnDismissListener() {
            @Override
            public void onDismiss(DialogInterface dialogInterface) {

            }
        });*/
        AlertDialog alert = builder.create();
        alert.show();
    }

    //---------------------------------------------------------------------------
    void hideKeyboard() {
        // Check if no view has focus:
        View view = this.getCurrentFocus();
        if (view != null) {
            InputMethodManager imm = (InputMethodManager)getSystemService(Context.INPUT_METHOD_SERVICE);
            imm.hideSoftInputFromWindow(view.getWindowToken(), 0);
        }
    }

    //---------------------------------------------------------------------------
    void onBtnSend() {
        hideKeyboard();
        if (m_edDescription.getText().length() == 0) {
            showError(getString(R.string.fill_description), m_edDescription);
            return;
        }
        if (!m_bImageSelected && !m_bImageOmitted) {
            AlertDialog.Builder builder = new AlertDialog.Builder(this);
            builder.setMessage(getString(R.string.fill_photo));
            builder.setPositiveButton(R.string.dlg_yes, new DialogInterface.OnClickListener() {
                @Override
                public void onClick(DialogInterface dialogInterface, int i) {
                    m_bImageOmitted = true;
                    onBtnSend();
                }
            });
            builder.setNegativeButton(R.string.dlg_cancel, null);
            AlertDialog alert = builder.create();
            alert.show();
            return;
        }
        if (m_location == null) {
            showError(getString(R.string.fill_location), null);
            return;
        }


        String sMessageBody = m_edDescription.getText().toString();
        String sAddress = m_lbLocation.getText().toString();
        if (!sAddress.isEmpty()) {
            sMessageBody += "\n\n" + sAddress;
        }
        if (m_location != null) {
            // send location as this link: https://mapy.cz/zakladni?x=14.4185889&y=50.0018275&z=17&source=coor&id=14.4185889%2C50.0020275
            String sMapLink = String.format(Locale.US, "https://mapy.cz/zakladni?x=%.8f&y=%.8f&z=17&source=coor&id=%.8f%%2C%.8f", m_location.getLongitude(), m_location.getLatitude(), m_location.getLongitude(), m_location.getLatitude());
            sMessageBody += "\n" + sMapLink;
        }
        sMessageBody += "\n\n";


        Intent intent = new Intent(Intent.ACTION_SEND);
        intent.setType("message/rfc822");
        intent.putExtra(Intent.EXTRA_EMAIL, new String[]{"informace@praha12.cz"});
        intent.putExtra(Intent.EXTRA_CC, new String[] {"info@dvanactka.info"});
        intent.putExtra(Intent.EXTRA_SUBJECT, "Hlášení závady");
        intent.putExtra(Intent.EXTRA_TEXT, sMessageBody);

        // add image
        if (m_bImageSelected) {
            Uri uriAttach = null;
            if (m_fileFromCamera != null) {
                //uriAttach = Uri.fromFile(m_fileFromCamera);
                uriAttach = FileProvider.getUriForFile(this, "com.roomarranger.android.dvanactka.fileprovider", m_fileFromCamera);   // this way we don't need permission to write_external_storage
            }
            else {
                try {
                    File pic = new File(getCacheDir(), "foto.jpg");
                    FileOutputStream out = new FileOutputStream(pic);
                    ((BitmapDrawable) m_btnPhoto.getDrawable()).getBitmap().compress(Bitmap.CompressFormat.JPEG, 85, out);
                    out.flush();
                    out.close();

                    uriAttach = FileProvider.getUriForFile(this, "com.roomarranger.android.dvanactka.fileprovider", pic);
                } catch (IOException e) {
                    Log.e("BROKEN", "Could not write file " + e.getMessage());
                }
            }
            if (uriAttach != null) {
                intent.setType("application/image");
                intent.putExtra(Intent.EXTRA_STREAM, uriAttach);
                intent.setFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
            }
        }

        try {
            startActivity(Intent.createChooser(intent, getString(R.string.send_mail)));
        } catch (android.content.ActivityNotFoundException ex) {
            Toast.makeText(this, "There are no email clients installed.", Toast.LENGTH_SHORT).show();
        }
    }

    //---------------------------------------------------------------------------
    void decodeAddressFrom(Location location) {
        if (!Geocoder.isPresent()) return;

        Intent intent = new Intent(this, FetchAddressIntentService.class);
        intent.putExtra(FetchAddressIntentService.RECEIVER, m_AddressResultReceiver);
        intent.putExtra(FetchAddressIntentService.LOCATION_DATA_EXTRA, location);
        startService(intent);
    }

    //---------------------------------------------------------------------------
    class AddressResultReceiver extends ResultReceiver {
        public AddressResultReceiver(Handler handler) {
            super(handler);
        }

        @Override
        protected void onReceiveResult(int resultCode, Bundle resultData) {
            String sAddressOutput = resultData.getString(FetchAddressIntentService.RESULT_DATA_KEY);
            if (resultCode == FetchAddressIntentService.SUCCESS_RESULT) {
                displayLocation(m_location, sAddressOutput);
            }
        }
    }

    //---------------------------------------------------------------------------
    void displayLocation(Location loc, String address) {
        if (loc == null) return;
        m_location = loc;
        String sLocation = String.format(Locale.getDefault(), "GPS: %.8gN, %.8gE", loc.getLatitude(), loc.getLongitude());
        if (address != null) {
            sLocation += "\n" + address;
        }
        m_lbLocation.setText(sLocation);
    }

    //---------------------------------------------------------------------------
    protected void onActivityResult(int requestCode, int resultCode, Intent imageReturnedIntent) {
        super.onActivityResult(requestCode, resultCode, imageReturnedIntent);

        Bundle extras = null;
        if (imageReturnedIntent != null)
            extras = imageReturnedIntent.getExtras();

        switch(requestCode) {
            case ACT_RESULT_TAKE_PHOTO: {
                if (m_fileFromCamera != null) {
                    Uri uriToStore = FileProvider.getUriForFile(ReportFaultCtl.this, "com.roomarranger.android.dvanactka.fileprovider", m_fileFromCamera);
                    revokeUriPermission(uriToStore, Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_GRANT_WRITE_URI_PERMISSION);
                }
                if (resultCode == RESULT_OK) {
                    if (extras != null && extras.get("data") != null) {
                        Bitmap aBitmap = (Bitmap) extras.get("data");   // this gets only a thumbnail!
                        //Uri selectedImage = imageReturnedIntent.getData();
                        m_btnPhoto.setAdjustViewBounds(true);
                        m_btnPhoto.setImageBitmap(aBitmap);
                        m_bImageSelected = true;
                        m_fileFromCamera = null;
                    }
                    else if (m_fileFromCamera != null) {
                        m_btnPhoto.setAdjustViewBounds(true);
                        Uri uriFile = Uri.fromFile(m_fileFromCamera);
                        try {
                            m_btnPhoto.setImageBitmap(handleSamplingAndRotationBitmap(this, uriFile));
                            m_fileFromCamera = null;
                        } catch (Exception e) {
                            // fallback, do without rotation
                            m_btnPhoto.setImageURI(uriFile);
                        }
                        m_bImageSelected = true;
                    }
                }
            }
            break;

            case ACT_RESULT_PICK_PHOTO:
                if (resultCode == RESULT_OK && imageReturnedIntent != null) {
                    Uri selectedImage = imageReturnedIntent.getData();
                    m_btnPhoto.setAdjustViewBounds(true);
                    m_btnPhoto.setImageURI(selectedImage);
                    m_fileFromCamera = null;
                    m_bImageSelected = true;
                }
                break;

            case ACT_RESULT_REFINE_LOCATION:
                if (resultCode == RESULT_OK && extras != null) {
                    double dLat = extras.getDouble(MainActivity.EXTRA_USER_LOCATION_LAT, 0.0);
                    double dLong = extras.getDouble(MainActivity.EXTRA_USER_LOCATION_LONG, 0.0);
                    if (dLat != 0.0 && dLong != 0.0) {
                        Location loc = new Location("refined");
                        loc.setLatitude(dLat);
                        loc.setLongitude(dLong);

                        m_bLocationRefined = true;
                        displayLocation(loc, null);
                        decodeAddressFrom(loc);
                    }
                }
                break;
        }
    }

    //---------------------------------------------------------------------------
    @Override
    public void onSaveInstanceState(Bundle bundle)
    {
        super.onSaveInstanceState(bundle);

        // save the camera filename in case the activity gets destroyed while capturing
        bundle.putString("m_fileFromCamera", m_fileFromCamera == null ? "" : m_fileFromCamera.getAbsolutePath());
    }

    //---------------------------------------------------------------------------
    //---------------------------------------------------------------------------
    // handling the captured image - needs to be rotated
    /**
     * This method is responsible for solving the rotation issue if exist. Also scale the images to
     * 1024x1024 resolution
     *
     * @param context       The current context
     * @param selectedImage The Image URI
     * @return Bitmap image results
     * @throws IOException
     */
    public static Bitmap handleSamplingAndRotationBitmap(Context context, Uri selectedImage)
            throws IOException {
        int MAX_HEIGHT = 1024;
        int MAX_WIDTH = 1024;

        // First decode with inJustDecodeBounds=true to check dimensions
        final BitmapFactory.Options options = new BitmapFactory.Options();
        options.inJustDecodeBounds = true;
        InputStream imageStream = context.getContentResolver().openInputStream(selectedImage);
        BitmapFactory.decodeStream(imageStream, null, options);
        imageStream.close();

        // Calculate inSampleSize
        options.inSampleSize = calculateInSampleSize(options, MAX_WIDTH, MAX_HEIGHT);

        // Decode bitmap with inSampleSize set
        options.inJustDecodeBounds = false;
        imageStream = context.getContentResolver().openInputStream(selectedImage);
        Bitmap img = BitmapFactory.decodeStream(imageStream, null, options);

        img = rotateImageIfRequired(img, selectedImage);
        return img;
    }

    /**
     * Calculate an inSampleSize for use in a {@link BitmapFactory.Options} object when decoding
     * bitmaps using the decode* methods from {@link BitmapFactory}. This implementation calculates
     * the closest inSampleSize that will result in the final decoded bitmap having a width and
     * height equal to or larger than the requested width and height. This implementation does not
     * ensure a power of 2 is returned for inSampleSize which can be faster when decoding but
     * results in a larger bitmap which isn't as useful for caching purposes.
     *
     * @param options   An options object with out* params already populated (run through a decode*
     *                  method with inJustDecodeBounds==true
     * @param reqWidth  The requested width of the resulting bitmap
     * @param reqHeight The requested height of the resulting bitmap
     * @return The value to be used for inSampleSize
     */
    private static int calculateInSampleSize(BitmapFactory.Options options,
                                             int reqWidth, int reqHeight) {
        // Raw height and width of image
        final int height = options.outHeight;
        final int width = options.outWidth;
        int inSampleSize = 1;

        if (height > reqHeight || width > reqWidth) {

            // Calculate ratios of height and width to requested height and width
            final int heightRatio = Math.round((float) height / (float) reqHeight);
            final int widthRatio = Math.round((float) width / (float) reqWidth);

            // Choose the smallest ratio as inSampleSize value, this will guarantee a final image
            // with both dimensions larger than or equal to the requested height and width.
            inSampleSize = heightRatio < widthRatio ? heightRatio : widthRatio;

            // This offers some additional logic in case the image has a strange
            // aspect ratio. For example, a panorama may have a much larger
            // width than height. In these cases the total pixels might still
            // end up being too large to fit comfortably in memory, so we should
            // be more aggressive with sample down the image (=larger inSampleSize).

            final float totalPixels = width * height;

            // Anything more than 2x the requested pixels we'll sample down further
            final float totalReqPixelsCap = reqWidth * reqHeight * 2;

            while (totalPixels / (inSampleSize * inSampleSize) > totalReqPixelsCap) {
                inSampleSize++;
            }
        }
        return inSampleSize;
    }

    /**
     * Rotate an image if required.
     *
     * @param img           The image bitmap
     * @param selectedImage Image URI
     * @return The resulted Bitmap after manipulation
     */
    private static Bitmap rotateImageIfRequired(Bitmap img, Uri selectedImage) throws IOException {

        ExifInterface ei = new ExifInterface(selectedImage.getPath());
        int orientation = ei.getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL);

        switch (orientation) {
            case ExifInterface.ORIENTATION_ROTATE_90:
                return rotateImage(img, 90);
            case ExifInterface.ORIENTATION_ROTATE_180:
                return rotateImage(img, 180);
            case ExifInterface.ORIENTATION_ROTATE_270:
                return rotateImage(img, 270);
            default:
                return img;
        }
    }

    private static Bitmap rotateImage(Bitmap img, int degree) {
        Matrix matrix = new Matrix();
        matrix.postRotate(degree);
        Bitmap rotatedImg = Bitmap.createBitmap(img, 0, 0, img.getWidth(), img.getHeight(), matrix, true);
        img.recycle();
        return rotatedImg;
    }
}
