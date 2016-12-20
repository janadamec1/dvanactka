<?php
/* Set HTTP response header to plain text for debugging output */
header("Content-type: text/plain");
/* Use internal libxml errors -- turn on in production, off for debugging */
libxml_use_internal_errors(true);

$html = file_get_contents("http://www.praha12.cz/vismo/mapa_deska.asp");
$html = str_replace("charset=windows-1250", "charset=utf-8", $html);

$arrItems = array();
$dom = new DomDocument;
//$dom->loadHTMLFile("http://www.praha12.cz/vismo/mapa_deska.asp");
$dom->loadHTML($html);
$xpath = new DomXPath($dom);
$nodes = $xpath->query("//div[@id='ud']/ul/li");
foreach ($nodes as $i => $node) {
	$nodeTitle = $xpath->query("strong/a", $node)->item(0);
	if ($nodeTitle != NULL) {
		$title = $nodeTitle->nodeValue;
		$link = $nodeTitle->getAttribute("href");
		if (substr($link, 0, 4) != "http") {
			$link = "https://www.praha12.cz" . $link;
		}
		$aNewRecord = array("title" => $title);
		$aNewRecord["infoLink"] = $link;
		
		$nodeDate = $xpath->query("span[1]", $node)->item(0);
		if ($nodeDate != NULL) {
			//echo $nodeDate->nodeValue, "\n";
			$arrParts = explode(" ", rtrim($nodeDate->nodeValue, ")"));
			$iFrom = array_search("od:", $arrParts);
			if ($iFrom !== FALSE) {
				$iCount = count($arrParts);
				if (array_key_exists($iFrom + 1, $arrParts)) {
					$date = date_create_from_format("!j.n.Y", $arrParts[$iFrom + 1]);
					$aNewRecord["date"] = date_format($date, "Y-m-d\TH:i");
				}
				if (array_key_exists($iFrom + 3, $arrParts)) {
					$date = date_create_from_format("!j.n.Y", $arrParts[$iFrom + 3]);
					$aNewRecord["dateTo"] = date_format($date, "Y-m-d\TH:i");
				}
			}
		}
		
		$nodeText = $xpath->query("div[@class='ktg']", $node)->item(0);
		if ($nodeText != NULL) {
			$text = $nodeText->nodeValue;
			$aNewRecord["filter"] = trim(substr(strrchr($text, ">"), 1));
		}
		if (array_key_exists("date", $aNewRecord))
	    	array_push($arrItems, $aNewRecord);
    }
}
if (count($arrItems) > 0) {
	$arr = array("items" => $arrItems);
	$encoded = json_encode($arr, JSON_UNESCAPED_UNICODE);
	$filename = "dyn_radDeska.json";
	file_put_contents($filename, $encoded, LOCK_EX);
	chmod($filename, 0644);
	//echo $encoded;
}
echo "done.";
?>
