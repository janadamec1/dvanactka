<?php

header("Content-type: text/plain; charset=utf-8");

function fillStationContainers(&$rec, $iStationId) {
	$stationContFile = file_get_contents("http://giswa2.mag.mepnet.cz/arcgis/rest/services/APP_KSNKO/sep_odpad/MapServer/1/query?where=STATIONID%3D+".$iStationId."&outFields=TRASHTYPENAME%2C+CONTAINERS%2C+CLEANINGFREQUENCYNAME%2C+SHAPE%2C+CONTAINERTYPE&returnGeometry=false&f=json");
	//$stationContFile = file_get_contents("waste_sep_station943_test.json");

	$arrConts = json_decode($stationContFile, true);
	if ($arrConts === FALSE || $arrConts === NULL) {
		echo "failed to load station json $iStationId";
		return;
	}
	$arrContsItems = &$arrConts["features"];	// reference

	$keysCont = array_keys($arrContsItems);
	$sizeCont = count($arrContsItems);
	for ($i = 0; $i < $sizeCont; $i++) {	// iterate like this, foreach can make copy
		$keyCont = $keysCont[$i];
		$recCont = &$arrContsItems[$keyCont];		// reference!
	
		$recContAttr = &$recCont["attributes"];
		
		$rec["text"] .= "\n".$recContAttr["TRASHTYPENAME"]." (".$recContAttr["CLEANINGFREQUENCYNAME"].")";
	}
}


$arrItems = array();

// read list of locations in Praha 12
$stationsFile = file_get_contents("http://giswa2.mag.mepnet.cz/arcgis/rest/services/APP_KSNKO/sep_odpad/MapServer/0/query?where=CITYDISTRICT%3D%27Praha+12%27&outFields=CITYDISTRICT%2C+STATIONNAME%2C+STATIONNUMBER%2C+ID&returnGeometry=true&outSR=4326&f=json");
//$stationsFile = file_get_contents("waste_sep_stations_test.json");

// read base data
$arrStations = json_decode($stationsFile, true);
if ($arrStations === FALSE || $arrStations === NULL) {
	echo "failed to load waste_sep_stations.json";
	exit;
}

$arrStationItems = &$arrStations["features"];	// reference

$keys = array_keys($arrStationItems);
$size = count($arrStationItems);
for ($i = 0; $i < $size; $i++) {	// iterate like this, foreach can make copy
    $key = $keys[$i];
    $rec = &$arrStationItems[$key];		// reference!
    
    $recAttr = &$rec["attributes"];
	$aNewRecord = array("title" => $recAttr["STATIONNAME"]);
	$aNewRecord["text"] = "Číslo stanoviště: " . $recAttr["STATIONNUMBER"];
	$iStationId = $recAttr["ID"];
	$aNewRecord["category"] = "wasteSeparated";
	$aNewRecord["filter"] = "Tříděný odpad";
    $recGeom = &$rec["geometry"];
	$aNewRecord["locationLat"] = (string)$recGeom["y"];
	$aNewRecord["locationLong"] = (string)$recGeom["x"];

	// read containers
	//if ($iStationId == 943) {
		fillStationContainers($aNewRecord, $iStationId);
	//}

	if (array_key_exists("events", $rec)) {
		$rec["events"] = implode("|", $rec["events"]);
	}

	array_push($arrItems, $aNewRecord);
}

var_dump($arrItems);

$filename = "waste_loc_separated.json";
$encoded = json_encode($arrItems, JSON_UNESCAPED_UNICODE);
file_put_contents($filename, $encoded, LOCK_EX);
chmod($filename, 0644);

?>
