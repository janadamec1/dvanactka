<?php
header("Content-type: text/plain; charset=utf-8");
/* Use internal libxml errors -- turn on in production, off for debugging */
libxml_use_internal_errors(true);

$arrItems = array();
$dom = new DomDocument;
$dom->load("http://dvanactka.info/feed/");	// XML
$xpath = new DomXPath($dom);
$nodes = $xpath->query("//item");
foreach ($nodes as $i => $node) {
	$nodeTitle = $xpath->query("title", $node)->item(0);
	if ($nodeTitle != NULL) {
		$title = $nodeTitle->nodeValue;
		$aNewRecord = array("title" => $title);
	
		$nodeDate = $xpath->query("pubDate", $node)->item(0);
		if ($nodeDate != NULL) {
			$date = date_create_from_format(DateTime::RSS, $nodeDate->nodeValue);
			$aNewRecord["date"] = date_format($date, "Y-m-d\TH:i");
		}

		$nodeLink = $xpath->query("link", $node)->item(0);
		if ($nodeLink != NULL) {
			$link = $nodeLink->nodeValue;
			$aNewRecord["infoLink"] = $link;
		}
			
		$nodeText = $xpath->query("description", $node)->item(0);
		if ($nodeText != NULL) {
			$text = $nodeText->nodeValue;
			$aNewRecord["text"] = $text;
		}
		
		$nodeAuthor = $xpath->query("dc:creator", $node)->item(0);
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
echo "done.";
?>
