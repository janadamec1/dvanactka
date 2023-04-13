<?php
// this waste_generate script version downloads the data from opendata.praha.eu and automatically merges it into our other data

const g_sVokLokCsv = "https://storage.golemio.cz/lkod/praha-12/8e6e0983-e512-480a-8069-987ff16c02c2/opendata-harmonogram-odpady-lokace-mc-praha-12.csv";
const g_sVokBioCsv = "https://storage.golemio.cz/lkod/praha-12/8e6e0983-e512-480a-8069-987ff16c02c2/opendata-harmonogram-odpady-bioodpad-mc-praha-12.csv";
const g_sVokVokCsv = "https://storage.golemio.cz/lkod/praha-12/8e6e0983-e512-480a-8069-987ff16c02c2/opendata-harmonogram-odpady-vok-mc-praha-12.csv";

function findVokLocation(&$alias, &$ds) {	// returns key to found record in $ds
	$keys = array_keys($ds);
	$size = count($ds);

	// first find exact match in title (new records have same name as in our vokplaces.json)
	for ($i = 0; $i < $size; $i++) {		// iterate like this, foreach can make copy
		$key = $keys[$i];
		$rec = &$ds[$key];
		if ($rec["category"] === "waste" && $alias === $rec["title"])
			return $key;
	}

	$aliasCompressed = str_replace(" ", "", $alias);

	for ($i = 0; $i < $size; $i++) {		// iterate like this, foreach can make copy
		$key = $keys[$i];
		$rec = &$ds[$key];
		if (array_key_exists("text", $rec)) {
			$sTextCompressed = str_replace(" ", "", $rec["text"]);
			if (strpos($sTextCompressed, $aliasCompressed) !== FALSE) {
				return $key;
			}
		}
	}
	return -1;  //not found
}

function findAddLocationFromOpenData(&$alias, &$csvLokace, &$ds) {
    foreach ($csvLokace as $lineLok) {
		$lineItems = str_getcsv($lineLok);
		if (count($lineItems) < 3)
			continue;
		if ($alias === $lineItems[0]) {

            $aNewRecord = array("title" => $alias);
            $aNewRecord["text"] = $lineItems[0];
            $aNewRecord["locationLong"] = $lineItems[1];
            $aNewRecord["locationLat"] = $lineItems[2];
            $aNewRecord["filter"] = "Velkoobjemové kontejnery";
            $aNewRecord["category"] = "waste";
            $iNewCnt = array_push($ds, $aNewRecord);
		    return $iNewCnt-1;
		}
    }
    return -1;  //not found
}

function processWasteDataFile(&$csv, $type, &$csvLokace, &$ds) {
	$iTypeCol = -1;
	if ($type === "bio") {
		$iTypeCol = 5;
	}
	$nProcessedCount = 0;
	foreach ($csv as $line) {
		$lineItems = str_getcsv($line);
		if (count($lineItems) < 5)
			continue;
		$recIdx = findVokLocation($lineItems[0], $ds);	// take reference
		if ($recIdx === -1) {
    		echo "File " . $type . " cannot find location " . $lineItems[0] ." in vokplaces.json, trying opendata\n";
    		$recIdx = findAddLocationFromOpenData($lineItems[0], $csvLokace, $ds);	// take reference
		}
		if ($recIdx === -1) {
    		echo "File " . $type . " cannot find location " . $lineItems[0] ." even in opendata\n";
		}
		else
		{
		    $rec = &$ds[$recIdx];
			// exception midnight for dateTo
			if ($lineItems[4] == "24:00:00")
				$lineItems[4] = "23:59:00";
		
			$sDateFrom = $lineItems[1] . " " . $lineItems[2];
			$sDateTo = $lineItems[3] . " " . $lineItems[4];
			$dateFrom = date_create_from_format("!Y-m-d G:i:s", $sDateFrom);
			$dateTo = date_create_from_format("!Y-m-d G:i:s", $sDateTo);
			if ($dateFrom === FALSE) {
    			echo "File " . $type . " cannot parse dateFrom " . $sDateFrom ."\n";
				continue;
			}
			if ($dateTo === FALSE) {
    			echo "File " . $type . " cannot parse dateTo " . $sDateTo ."\n";
				continue;
			}

			$sRecType = $type;
			if ($iTypeCol >= 0 && $iTypeCol < count($lineItems))
				$sRecType = $lineItems[$iTypeCol];

			$sItem = $sRecType . ";" . date_format($dateFrom, "Y-m-d\TH:i") . ";" . date_format($dateTo, "Y-m-d\TH:i");
			// add new record to rec
			if (array_key_exists("events", $rec))
				array_push($rec["events"], $sItem);
			else {
				$arrEvents = array();
				array_push($arrEvents, $sItem);
				$rec["events"] = $arrEvents;
			}
			$nProcessedCount += 1;
		}
	}
	echo "File " . $type . " processed " . $nProcessedCount ."\n";
	return ($nProcessedCount > 0);
}

header("Content-type: text/plain; charset=utf-8");

// read base data
$encoded = file_get_contents("vokplaces.json");
$arr = json_decode($encoded, true);
if ($arr === FALSE || $arr === NULL) {
	echo "failed to load vokplaces.json";
	exit;
}

$arrItems = &$arr["items"];	// reference

// read timetables and put them into the base data
$contentsBio = file_get_contents(g_sVokBioCsv);
$vok_bio_lines = explode("\n", str_replace("\r\n", "\n", $contentsBio));
if ($vok_bio_lines === FALSE || $vok_bio_lines === NULL || count($vok_bio_lines) == 0) {
	echo "failed to load " . basename(g_sVokBioCsv);
	exit;
}
$contentsVok = file_get_contents(g_sVokVokCsv);
$vok_vok_lines = explode("\n", str_replace("\r\n", "\n", $contentsVok));
if ($vok_vok_lines === FALSE || $vok_vok_lines === NULL || count($vok_vok_lines) == 0) {
	echo "failed to load " . basename(g_sVokVokCsv);
	exit;
}
$contentsLokace = file_get_contents(g_sVokLokCsv);
$vok_lokace_lines = explode("\n", str_replace("\r\n", "\n", $contentsLokace));
if ($vok_lokace_lines === FALSE || $vok_lokace_lines === NULL || count($vok_lokace_lines) == 0) {
	echo "failed to load " . basename(g_sVokLokCsv);
	exit;
}
if (processWasteDataFile($vok_vok_lines, "obj. odpad", $vok_lokace_lines, $arrItems) === FALSE) {
	echo "error processing vok_vok_od";
	exit;
}
if (processWasteDataFile($vok_bio_lines, "bio", $vok_lokace_lines, $arrItems) === FALSE) {
	echo "error processing vok_bio_od";
	exit;
}

$keys = array_keys($arrItems);
$size = count($arrItems);
for ($i = 0; $i < $size; $i++) {	// iterate like this, foreach can make copy
    $key = $keys[$i];
    $rec = &$arrItems[$key];		// reference!

	if (array_key_exists("category", $rec) && $rec["category"] === "waste") {
		$rec["infoLink"] = "https://www.praha12.cz/odpady/ds-1138/";

		if (array_key_exists("events", $rec)) {
			$rec["events"] = implode("|", $rec["events"]);

		}
		// check if there are any events for VOK / if not, delete this record
		if (array_key_exists("filter", $rec) && $rec["filter"] === "Velkoobjemové kontejnery"
		 && (!array_key_exists("events", $rec) || $rec["events"] === "" )) {
		 	$rec["title"] = "";  // clearing the title ships this record in the app
		}
	}
}

// append items from separated waste
$encoded = file_get_contents("waste_loc_separated.json");
$arrSepItems = json_decode($encoded, true);
if ($arrSepItems === FALSE || $arrSepItems === NULL) {
	echo "failed to load waste_loc_separated.json";
	exit;
}
$keysSep = array_keys($arrSepItems);
$sizeSep = count($arrSepItems);
for ($i = 0; $i < $sizeSep; $i++) {
    $keySep = $keysSep[$i];
    $recSep = &$arrSepItems[$keySep];
    array_push($arrItems, $recSep);
}

// write to output
var_dump($arrItems);

$filename = "dyn_waste.json";
$encoded = json_encode($arr, JSON_UNESCAPED_UNICODE);
file_put_contents($filename, $encoded, LOCK_EX);
chmod($filename, 0644);

?>
