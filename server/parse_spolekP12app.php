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
//$nodes = $xpath->query("//vevent/properties"); //somehow XPath does not work
$nodes = $dom->getElementsByTagName('properties');
foreach ($nodes as $i => $node) {
	//$nodeTitle = firstItem($xpath->query("summary", $node));
	$nodeTitle = firstItem($node->getElementsByTagName('summary'));
	if ($nodeTitle != NULL) {
		$title = $nodeTitle->textContent;
		$aNewRecord = array("title" => $title);

		//$nodeText = firstItem($xpath->query("description", $node));
		$nodeText = firstItem($node->getElementsByTagName('description'));
		if ($nodeText != NULL)
			$aNewRecord["text"] = $nodeText->textContent;

		//$nodeDate = firstItem($xpath->query("dtstart", $node));
		$nodeDate = firstItem($node->getElementsByTagName('dtstart'));
		if ($nodeDate != NULL) {
  		$nodeDateDT = firstItem($nodeDate->getElementsByTagName('date-time'));
      if ($nodeDateDT != NULL)
        $sDateText = $nodeDateDT->nodeValue;
      else
        $sDateText = $nodeDate->textContent;
      if (strpos($sDateText, "T") !== FALSE)
        $date = date_create_from_format("Y-m-d\TH:i:s", $sDateText);
      else
        $date = date_create_from_format("!Y-m-d", $sDateText);
      if ($date === FALSE)
        echo "Error parsing dtstart " . $sDateText . "\n";
      else
        $aNewRecord["date"] = date_format($date, "Y-m-d\TH:i");
		}
		//$nodeDateTo = firstItem($xpath->query("dtend", $node));
		$nodeDateTo = firstItem($node->getElementsByTagName('dtend'));
		if ($nodeDateTo != NULL) {
  		$nodeDateToDT = firstItem($nodeDateTo->getElementsByTagName('date-time'));
      if ($nodeDateToDT != NULL)
        $sDateText = $nodeDateToDT->nodeValue;
      else
        $sDateText = $nodeDateTo->textContent;
      if (strpos($sDateText, "T") !== FALSE)
        $date = date_create_from_format("Y-m-d\TH:i:s", $sDateText);
      else
        $date = date_create_from_format("!Y-m-d", $sDateText);
      if ($date === FALSE)
        echo "Error parsing dtend " . $sDateText . "\n";
      else
        $aNewRecord["dateTo"] = date_format($date, "Y-m-d\TH:i");
		}

		//$nodeAddress = firstItem($xpath->query("location", $node));
		$nodeAddress = firstItem($node->getElementsByTagName('location'));
		if ($nodeAddress != NULL)
			$aNewRecord["address"] = $nodeAddress->textContent;

		//$nodeGeo = firstItem($xpath->query("geo", $node));
		$nodeGeo = firstItem($node->getElementsByTagName('geo'));
		if ($nodeGeo != NULL) {
		  //$nodeLat = firstItem($xpath->query("latitude", $nodeGeo));
		  //$nodeLong = firstItem($xpath->query("longitude", $nodeGeo));
  		$nodeLat = firstItem($nodeGeo->getElementsByTagName('latitude'));
  		$nodeLong = firstItem($nodeGeo->getElementsByTagName('longitude'));
			if ($nodeLat != NULL && $nodeLong != NULL) {
				$aNewRecord["locationLat"] = $nodeLat->nodeValue;
				$aNewRecord["locationLong"] = $nodeLong->nodeValue;
			}
		}

		$sFilter = "Dvanáctka.info";
		//$nodeContact = firstItem($xpath->query("contact", $node));
		$nodeContact = firstItem($node->getElementsByTagName('contact'));
		if ($nodeContact != NULL) {
		  //echo $nodeContact->textContent. "\n";
			$arrContact = explode(";", $nodeContact->textContent);
			foreach ($arrContact as $j => $item) {
				$contact = trim($item);
				if (strlen($contact) == 0) continue;
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
