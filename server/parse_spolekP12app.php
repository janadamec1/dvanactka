<?php
include_once "parse_common.php";

$arrItems = array();
$dom = new DomDocument;
$dom->load("http://dvanactka.info/feed/");	// XML
$xpath = new DomXPath($dom);
$nodes = $xpath->query("//item");
foreach ($nodes as $i => $node) {
	$nodeTitle = firstItem($xpath->query("title", $node));
	if ($nodeTitle != NULL) {
		$title = $nodeTitle->nodeValue;
		$aNewRecord = array("title" => $title);
	
		$nodeDate = firstItem($xpath->query("pubDate", $node));
		if ($nodeDate != NULL) {
			$date = date_create_from_format(DateTime::RSS, $nodeDate->nodeValue);
			$aNewRecord["date"] = date_format($date, "Y-m-d\TH:i");
		}

		$nodeLink = firstItem($xpath->query("link", $node));
		if ($nodeLink != NULL) {
			$link = $nodeLink->nodeValue;
			$aNewRecord["infoLink"] = $link;
		}
			
		$nodeText = firstItem($xpath->query("description", $node));
		if ($nodeText != NULL) {
			$text = $nodeText->nodeValue;
			$aNewRecord["text"] = $text;
		}
		
		$nodeAuthor = firstItem($xpath->query("dc:creator", $node));
		if ($nodeAuthor != NULL) {
			$author = $nodeAuthor->nodeValue;
			$aNewRecord["filter"] = $author;
		}
		else
			$aNewRecord["filter"] = "Dvanáctka.info";
		if (array_key_exists("date", $aNewRecord))
			array_push($arrItems, $aNewRecord);
	}
}
if (count($arrItems) > 0) {
	/*
	$arr = array("items" => $arrItems);
	$encoded = json_encode($arr, JSON_UNESCAPED_UNICODE);
	*/
	$encoded = "";
	foreach ($arrItems as $i => $item) {
		$encoded .= json_encode($item, JSON_UNESCAPED_UNICODE);
		$encoded .= ",\n";
	}
	
	$filename = "items_spolekP12app.json";
	file_put_contents($filename, $encoded, LOCK_EX);
	chmod($filename, 0644);
	//echo $encoded;
}
echo "RSS done, " . count($arrItems) . " items\n";

//-------------------------------------------

$arrItems = array();
$dom = new DomDocument;
$dom->load("http://dvanactka.info/?plugin=all-in-one-event-calendar&controller=ai1ec_exporter_controller&action=export_events&xml=true");	// XML
$xpath = new DomXPath($dom);
$nodes = $xpath->query("//vevent");
foreach ($nodes as $i => $node) {
	$nodeTitle = firstItem($xpath->query("summary", $node));
	if ($nodeTitle != NULL) {
		$title = $nodeTitle->nodeValue;
		$aNewRecord = array("title" => $title);
		
		$nodeText = firstItem($xpath->query("description", $node));
		if ($nodeText != NULL)
			$aNewRecord["text"] = $nodeText->nodeValue;

		$nodeDate = firstItem($xpath->query("dtstart", $node));
		if ($nodeDate != NULL) {
			$sDateText = $nodeDate->nodeValue;
			if (strpos($sDateText, "T") !== FALSE)
				$date = date_create_from_format("Ymd\THis", $sDateText);
			else
				$date = date_create_from_format("!Ymd", $sDateText);
			$aNewRecord["date"] = date_format($date, "Y-m-d\TH:i");
		}
		$nodeDateTo = firstItem($xpath->query("dtend", $node));
		if ($nodeDateTo != NULL) {
			$sDateText = $nodeDateTo->nodeValue;
			if (strpos($sDateText, "T") !== FALSE)
				$date = date_create_from_format("Ymd\THis", $sDateText);
			else
				$date = date_create_from_format("!Ymd", $sDateText);
			$aNewRecord["dateTo"] = date_format($date, "Y-m-d\TH:i");
		}
		
		$nodeAddress = firstItem($xpath->query("location", $node));
		if ($nodeAddress != NULL)
			$aNewRecord["address"] = $nodeAddress->nodeValue;

		$nodeGeo = firstItem($xpath->query("geo", $node));
		if ($nodeGeo != NULL) {
			$arrGeo = explode(";", $nodeGeo->nodeValue);
			if (count($arrGeo) > 1) {
				$aNewRecord["locationLat"] = $arrGeo[0];
				$aNewRecord["locationLong"] = $arrGeo[1];
			}
		}
		
		$sFilter = "Dvanáctka.info";
		$nodeContact = firstItem($xpath->query("contact", $node));
		if ($nodeContact != NULL) {
			$arrContact = explode(";", $nodeContact->nodeValue);
			foreach ($arrContact as $j => $item) {
				$contact = trim($item);
				if (strpos($contact, "@") !== FALSE)
					$aNewRecord["email"] = $contact;
				else if (substr_compare($contact, "http", 0, 4) === 0)
					$aNewRecord["infoLink"] = $contact;
				else if (is_numeric(str_replace(" ", "", $contact)))
					$aNewRecord["phone"] = $contact;
				else if ($j === 0)
					$sFilter = $contact;
			}
		}
		$aNewRecord["filter"] = $sFilter;

		if (array_key_exists("date", $aNewRecord))
			array_push($arrItems, $aNewRecord);
	}
}

if (count($arrItems) > 0) {
	$encoded = "";
	foreach ($arrItems as $i => $item) {
		$encoded .= json_encode($item, JSON_UNESCAPED_UNICODE);
		$encoded .= ",\n";
	}
	
	$filename = "items_P12app_calendar.json";
	file_put_contents($filename, $encoded, LOCK_EX);
	chmod($filename, 0644);
	//echo $encoded;
}
echo "Events done, " . count($arrItems) . " items\n";
?>
