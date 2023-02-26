<?php
include_once "parse_common.php";

$arrItems = array();
$dom = new DomDocument;
//$dom->loadHTMLFile("https://www.ddmm.cz/akce");
$html = file_get_contents("https://www.ddmm.cz/akce");
$html = mb_convert_encoding($html,'HTML-ENTITIES','UTF-8');
$dom->loadHTML($html);

$xpath = new DomXPath($dom);
$nodes = $xpath->query("//div[@class='card-body border-top-5 px-3 border-custom-6']");
foreach ($nodes as $i => $node) {
	$nodeTitle = firstItem($xpath->query("h3/a", $node));
	if ($nodeTitle != NULL) {
		$title = $nodeTitle->nodeValue;
		//echo "found " . $title . "\n";

		$link = $nodeTitle->getAttribute("href");
		if (substr($link, 0, 4) != "http") {
			$link = "https://www.ddmm.cz/" . $link;
		}
		$aNewRecord = array("title" => $title);
		$aNewRecord["infoLink"] = $link;

		$nodePlace = firstItem($xpath->query("ul/li[2]/p", $node));
		if ($nodePlace != NULL) {
			$sItemText = $nodePlace->nodeValue;
			//echo "found place " . $sItemText . "\n";
			if ($sItemText == "DDM Herrmannova")
				$sItemText = "DDM Modřany @ Hermannova 24, Praha 12";
			else if ($sItemText == "DDM Urbánkova")
				$sItemText = "DDM Modřany @ Urbánkova 4, Praha 12";
			else if ($sItemText == "Mimo stálé objekty")
				$sItemText = "DDM Modřany - " . $sItemText;
			$aNewRecord["address"] = $sItemText;
		}

		$nodeDate = firstItem($xpath->query("ul/li[3]/p", $node));
		if ($nodeDate != NULL) {
			// split time from - to
			$sDateFromTo = $nodeDate->nodeValue;
			//echo "found date " . $sDateFromTo . "\n";
			$arrFromTo = explode("-", $sDateFromTo);
			if (count($arrFromTo) > 1) {
				$dateFrom = date_create_from_format("!j.n.Y+", trim($arrFromTo[0]));
				$dateTo = date_create_from_format("!j.n.Y+", trim($arrFromTo[1]));
				
				if ($dateFrom != null)
					$aNewRecord["date"] = date_format($dateFrom, "Y-m-d\TH:i");
				if ($dateTo != null && $dateTo != $dateFrom)
					$aNewRecord["dateTo"] = date_format($dateTo, "Y-m-d\TH:i");
			}
		}

		$aNewRecord["filter"] = "DDM Modřany";
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
	$filename = "items_ddmMonetEvents.json";
	file_put_contents($filename, $encoded, LOCK_EX);
	chmod($filename, 0644);
	echo $encoded;
}
echo "ddmm done, " . count($arrItems) . " items\n";
?>
