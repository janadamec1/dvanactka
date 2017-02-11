<?php
include_once "parse_common.php";

$arrItems = array();
$dom = new DomDocument;
$dom->loadHTMLFile("http://www.splz.cz/akce");
$xpath = new DomXPath($dom);
$nodes = $xpath->query("//div[@class='in']");
foreach ($nodes as $i => $node) {
	$nodeTitle = firstItem($xpath->query("h1", $node));
	if ($nodeTitle != NULL) {
		$title = $nodeTitle->nodeValue;
		
		$aNewRecord = array("title" => $title);
		$aNewRecord["infoLink"] = "http://www.splz.cz/akce";

		$nodeDate = firstItem($xpath->query("span", $node));
		if ($nodeDate != NULL) {
			$dateFrom = date_create_from_format("!j.n.Y+", $nodeDate->nodeValue);
			$aNewRecord["date"] = date_format($dateFrom, "Y-m-d\TH:i");
		}
		
		$nodeText = firstItem($xpath->query("div[@class='text']", $node));
		if ($nodeText != NULL) {
			$text = trim(substr($nodeText->nodeValue, 0, 300));	// first 300 letters
			$text = str_replace("\r\n\r\n", "\r\n", $text);		// remove double newlines
			$text = str_replace("\r\n\r\n", "\r\n", $text);		// remove triple newlines
			$aNewRecord["text"] = $text . "...";
			
			$nodeLink = firstItem($xpath->query("div[@class='vice']/a", $nodeText));
			if ($nodeLink != NULL) {
				$link = $nodeLink->getAttribute("href");
				$aNewRecord["infoLink"] = "http://www.splz.cz" . $link;
			}
		}

		$aNewRecord["filter"] = "Spolek pro lepší život v Praze";
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
	$filename = "items_spolekSplz.json";
	file_put_contents($filename, $encoded, LOCK_EX);
	chmod($filename, 0644);
	//echo $encoded;
}
echo "SPLZ done, " . count($arrItems) . " items\n";
?>
