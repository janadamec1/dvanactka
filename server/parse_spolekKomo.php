<?php
/* Set HTTP response header to plain text for debugging output */
header("Content-type: text/plain");
/* Use internal libxml errors -- turn on in production, off for debugging */
libxml_use_internal_errors(true);

$arrItems = array();
$dom = new DomDocument;
$dom->loadHTMLFile("http://www.spolekprokomorany.cz/aktuality/");
$xpath = new DomXPath($dom);
$nodes = $xpath->query("//div[@class='blog-item-content']");
foreach ($nodes as $i => $node) {
	$nodeHead = $xpath->query("div[@class='blog-item-head']", $node)->item(0);
	if ($nodeHead != NULL) {
		$nodeTitle = $xpath->query("h2", $nodeHead)->item(0);
		if ($nodeTitle != NULL) {
			$title = trim($nodeTitle->nodeValue);
			$aNewRecord = array("title" => $title);
		
			$nodeDate = $xpath->query("div[@class='blog-item-date']", $nodeHead)->item(0);
			if ($nodeDate != NULL) {
				$date = date_create_from_format("!j.n.Y", trim($nodeDate->nodeValue));
				$aNewRecord["date"] = date_format($date, "Y-m-d\TH:i");
			}
	
			$nodeLink = $xpath->query("a", $nodeTitle)->item(0);
			if ($nodeLink != NULL) {
				$link = $nodeLink->getAttribute("href");
				$aNewRecord["infoLink"] = "http://www.spolekprokomorany.cz" . $link;
			}
				
			$nodeText = $xpath->query("div/div/div[@class='perex-content']", $node)->item(0);
			if ($nodeText != NULL) {
				$text = trim($nodeText->nodeValue);
				$aNewRecord["text"] = $text;
			}
			$aNewRecord["filter"] = "Spolek pro Komořany";
			if (array_key_exists("date", $aNewRecord))
				array_push($arrItems, $aNewRecord);
	    }
    }
}

$arr = array("items" => $arrItems);
$encoded = json_encode($arr, JSON_UNESCAPED_UNICODE);
$filename = "dyn_spolekKomo.json";
file_put_contents($filename, $encoded, LOCK_EX);
chmod($filename, 0644);
echo $encoded;
echo "done.";
?>
