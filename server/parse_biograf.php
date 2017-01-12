<?php

function firstItem($arrNodes) {
	if ($arrNodes === NULL || $arrNodes === FALSE) return NULL;
	return $arrNodes->item(0);
}

/* Set HTTP response header to plain text for debugging output */
header("Content-type: text/plain");
/* Use internal libxml errors -- turn on in production, off for debugging */
libxml_use_internal_errors(true);

$sAddress = "Modřanský biograf\nU Kina 1\n143 00 Praha 12 - Modřany";

$arrItems = array();
$dom = new DomDocument;
$dom->loadHTMLFile("http://www.modranskybiograf.cz/klient-349/kino-114/");
$xpath = new DomXPath($dom);
$nodes = $xpath->query("//div[@class='calendar-left-table-tr']/a[@class='cal-event-item shortName']");
foreach ($nodes as $i => $node) {
	$nodeTitle = firstItem($xpath->query("h2", $node));
	if ($nodeTitle != NULL) {
		$title = $nodeTitle->nodeValue;
		if ($title == "KINO NEHRAJE")
			continue;
		
		$link = $node->getAttribute("href");
		if (substr($link, 0, 4) != "http") {
			$link = "http://www.modranskybiograf.cz" . $link;
		}
		$aNewRecord = array("title" => $title);
		$aNewRecord["infoLink"] = $link;
		
		$aNewRecord["text"] = implode(" | ", explode("\n", $node->getAttribute("title")));
		$aNewRecord["address"] = $sAddress;
		
		$nodeBuyLink = firstItem($xpath->query("..//a[@class='cal-event-item-buy-span']", $node));
		if ($nodeBuyLink != NULL) {
			$aNewRecord["buyLink"] = $nodeBuyLink->getAttribute("href");
		}

		$nodeDate = firstItem($xpath->query("div[@class='ap_date']", $node));
		$nodeTime = firstItem($xpath->query("div[@class='ap_time']", $node));
		if ($nodeDate != NULL && $nodeTime != NULL) {
		    $sDateTime = $nodeDate->nodeValue . date("Y") . " ". $nodeTime->nodeValue;
			$date = date_create_from_format("!j.n.Y G:i", $sDateTime);
			if ($date !== FALSE) {
				if ($date->format("n") < date("n")) {
					$date = date_add($date, new DateInterval('P1Y'));
				}
				$aNewRecord["date"] = date_format($date, "Y-m-d\TH:i");
		    }
		}
		
		if (array_key_exists("date", $aNewRecord))
	    	array_push($arrItems, $aNewRecord);
    }
}
if (count($arrItems) > 0) {
	$arr = array("items" => $arrItems);
	$encoded = json_encode($arr, JSON_UNESCAPED_UNICODE);
	$filename = "dyn_biograf.json";
	file_put_contents($filename, $encoded, LOCK_EX);
	chmod($filename, 0644);
}
//echo $encoded;
echo "done.";
?>
