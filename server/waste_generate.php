<?php

function &findVokLocation(&$alias, &$ds) {	// return reference
	$aliasCompressed = str_replace(" ", "", $alias);
	
	$keys = array_keys($ds);
	$size = count($ds);
	for ($i = 0; $i < $size; $i++) {		// iterate like this, foreach can make copy
		$key = $keys[$i];
		$rec = &$ds[$key];					// reference!
		if (array_key_exists("text", $rec)) {
			$sTextCompressed = str_replace(" ", "", $rec["text"]);
			if (strpos($sTextCompressed, $aliasCompressed) !== FALSE) {
				return $rec;
			}
		}
	}
	return NULL;
}

function processWasteDataFile(&$csv, $type, &$ds) {
	$iTimeStartCol = 2;
	$iTimeEndCol = 3;
	$iLocCol = 4;
	$iTypeCol = -1;
	if ($type === "bio") {
		$iTimeStartCol = 1;
		$iTimeEndCol = 2;
		$iLocCol = 3;
		$iTypeCol = 5;
	}
	$nProcessedCount = 0;
	foreach ($csv as $line) {
		$lineItems = explode(";", $line);
		if (count($lineItems) < 5)
			continue;
		$rec = &findVokLocation($lineItems[$iLocCol], $ds);	// take reference
		if ($rec != NULL) {
			$bWeekend = FALSE;
			if ($lineItems[$iTimeStartCol] === "0:00" && $lineItems[$iTimeEndCol] === "0:00") {
				// exception, duration is entire weekend
				$lineItems[$iTimeStartCol] = "15:00";
				$lineItems[$iTimeEndCol] = "8:00"; // TODO: add 3 days (weekend)
				$bWeekend = TRUE;
			}
			$sDateFrom = $lineItems[0] . " " . $lineItems[$iTimeStartCol];
			$sDateTo = $lineItems[0] . " " . $lineItems[$iTimeEndCol];
			$dateFrom = date_create_from_format("!j.n.Y G:i", $sDateFrom);
			$dateTo = date_create_from_format("!j.n.Y G:i", $sDateTo);
			if ($dateFrom === FALSE || $dateTo === FALSE)
				continue;
			if ($bWeekend) {
				$dateTo = date_add($dateTo, new DateInterval('P3D'));
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
$contentsBio = file_get_contents("vok_bio.csv");
$vok_bio_lines = explode("\n", $contentsBio);
if ($vok_bio_lines === FALSE || $vok_bio_lines === NULL || count($vok_bio_lines) == 0) {
	echo "failed to load vok_bio.csv";
	exit;
}
$contentsVok = file_get_contents("vok_vok.csv");
$vok_vok_lines = explode("\n", $contentsVok);
if ($vok_vok_lines === FALSE || $vok_vok_lines === NULL || count($vok_vok_lines) == 0) {
	echo "failed to load vok_vok.csv";
	exit;
}
if (processWasteDataFile($vok_vok_lines, "obj. odpad", $arrItems) === FALSE) {
	echo "error processing vok_vok";
	exit;
}
if (processWasteDataFile($vok_bio_lines, "bio", $arrItems) === FALSE) {
	echo "error processing vok_bio";
	exit;
}

$keys = array_keys($arrItems);
$size = count($arrItems);
for ($i = 0; $i < $size; $i++) {	// iterate like this, foreach can make copy
    $key = $keys[$i];
    $rec = &$arrItems[$key];		// reference!
    
	if (array_key_exists("category", $rec) && $rec["category"] === "waste") {
		$rec["infoLink"] = "https://www.praha12.cz/odpady/ds-1138/";
	}
	if (array_key_exists("events", $rec)) {
		$rec["events"] = implode("|", $rec["events"]);
	}
}

var_dump($arrItems);

$filename = "dyn_waste.json";
$encoded = json_encode($arr, JSON_UNESCAPED_UNICODE);
file_put_contents($filename, $encoded, LOCK_EX);
chmod($filename, 0644);

?>
