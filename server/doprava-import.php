<?php
include_once "parse_common.php";
//libxml_disable_entity_loader(false);

$post = file_get_contents('php://input');	// get POST contents
if (strlen($post) == 0) {
	echo "Empty POST data.";
	exit;
}

$dom = new DomDocument;
$dom->loadXML($post);
$xpath = new DomXPath($dom);
$nodeListMsg = $xpath->query("//MSG");
if ($nodeListMsg == FALSE) exit;
$nodeMsg = $nodeListMsg->item(0);
if ($nodeMsg->getAttribute("type") != "TI") exit;

$title = "";
$nodeTitle = firstItem($xpath->query("MLOC/TXPL", $nodeMsg));
if ($nodeTitle != NULL) {
	$title = $nodeTitle->nodeValue;
}
if (strlen($title) == 0) {
	$nodesStreet = $xpath->query("//STRE", $nodeMsg);
	if ($nodesStreet !== FALSE)
	{	
		foreach ($nodesStreet as $i => $node) {
			$sStreet = $node->getAttribute("StreetName");
			if (strlen($sStreet) > 0) {
				if (strlen($title) != 0)
					$title .= ", ";
				$title .= $sStreet;
			}
		}
	}
}
if (strlen($title) == 0) {
	$title = "TI";
}

$aNewRecord = array("title" => $title);

$msgId = $nodeMsg->getAttribute("id");		// message ID to store and update
$aNewRecord["msgId"] = $msgId;

$nodeText = firstItem($xpath->query("MTXT", $nodeMsg));
if ($nodeText != NULL) {
	$aNewRecord["text"] = $nodeText->nodeValue . "\n\nZdroj: JSDI - ŘSD ČR - www.dopravniinfo.cz";
}

$nodeDate = firstItem($xpath->query("MTIME/TSTA", $nodeMsg));
if ($nodeDate != NULL) {
	$date = date_create_from_format(DateTime::W3C, $nodeDate->nodeValue);
	$aNewRecord["date"] = date_format($date, "Y-m-d\TH:i");
}
$nodeDateTo = firstItem($xpath->query("MTIME/TSTO", $nodeMsg));
if ($nodeDateTo != NULL) {
	$date = date_create_from_format(DateTime::W3C, $nodeDateTo->nodeValue);
	$aNewRecord["dateTo"] = date_format($date, "Y-m-d\TH:i");
}
$nodeCoord = firstItem($xpath->query("MLOC/SNTL/COORD", $nodeMsg));
if ($nodeCoord != NULL) {
	$aNewRecord["locationLat"] = $nodeCoord->getAttribute("x");
	$aNewRecord["locationLong"] = $nodeCoord->getAttribute("y");
}
$nodeCategory = firstItem($xpath->query("MEVT/TMCE/EVI/TXUCL", $nodeMsg));
if ($nodeCategory != NULL) {
	$sCategory = $nodeCategory->nodeValue;
	if ($sCategory === "Nehody")
		$aNewRecord["category"] = "nehoda";
	else if ($sCategory === "Dopravní uzavírky a omezení")
		$aNewRecord["category"] = "uzavirka";
}
if (!array_key_exists("category", $aNewRecord))
		$aNewRecord["category"] = "uzavirka";

// OK, now store to our database
$filename = "dyn_doprava.json";
$encoded = file_get_contents($filename);
$arr = json_decode($encoded, true);
if ($arr === FALSE || $arr === NULL) {
	// write new file
	$arrItems = array();
	array_push($arrItems, $aNewRecord);
	$arr = array("items" => $arrItems);
	$encoded = json_encode($arr, JSON_UNESCAPED_UNICODE);
	file_put_contents($filename, $encoded, LOCK_EX);
	chmod($filename, 0644);
	exit;
}

// merge into an old file
$dateToday = new DateTime;

$arrOldItems = $arr["items"];
$arrItems = array();
$bUpdated = FALSE;
foreach ($arrOldItems as $i => $aRec) {
	if (array_key_exists("msgId", $aRec) && $aRec["msgId"]==$msgId)	{ // update
		array_push($arrItems, $aNewRecord);
		$bUpdated = TRUE;
	}
	else if (array_key_exists("dateTo", $aRec))
	{
		// copy old records only when dateTo is in the future
		$dateRecTo = date_create_from_format("Y-m-d\TH:i", $aRec["dateTo"]);
		if ($dateRecTo > $dateToday)
			array_push($arrItems, $aRec);
	}
}
if ($bUpdated == FALSE)
	array_push($arrItems, $aNewRecord);

$arr = array("items" => $arrItems);
$encoded = json_encode($arr, JSON_UNESCAPED_UNICODE);
file_put_contents($filename, $encoded, LOCK_EX);
chmod($filename, 0644);

?>
