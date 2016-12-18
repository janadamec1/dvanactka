<?php
/* Set HTTP response header to plain text for debugging output */
header("Content-type: text/plain");
/* Use internal libxml errors -- turn on in production, off for debugging */
libxml_use_internal_errors(true);

$arrItems = array();
$dom = new DomDocument;
$dom->loadHTMLFile("http://www.praha12.cz");
$xpath = new DomXPath($dom);
$nodes = $xpath->query("//div[@class='titulDoc aktClanky']//li");
foreach ($nodes as $i => $node) {
	$nodeTitle = $xpath->query("strong//a", $node)->item(0);
	if ($nodeTitle != NULL) {
		$title = $nodeTitle->nodeValue;
		$link = $nodeTitle->getAttribute("href");
		if (substr($link, 0, 4) != "http") {
			$link = "https://www.praha12.cz" . $link;
		}
		$aNewRecord = array("title" => $title);
		$aNewRecord["infoLink"] = $link;
		
		$nodeDate = $xpath->query("span", $node)->item(0);
		if ($nodeDate != NULL) {
			$date = $nodeDate->nodeValue;
			$date = substr($date, 1, strlen($str)-1);
			$aNewRecord["date"] = $date;
		}
		
		$nodeText = $xpath->query("div[1]", $node)->item(0);
		if ($nodeDate != NULL) {
			$text = $nodeText->nodeValue;
			$aNewRecord["text"] = $text;
		}
    	//echo "Node($i): TITLE: ", $title, "; DATE: ", $date, "; LINK: ", $link, "; TEXT: ", $text, "\n";
		$aNewRecord["filter"] = "praha12.cz";
    	array_push($arrItems, $aNewRecord);
    }
}

$nodes = $xpath->query("//div[@class='titulDoc upoClanky']//li");
foreach ($nodes as $i => $node) {
	$nodeTitle = $xpath->query("strong//a", $node)->item(0);
	if ($nodeTitle != NULL) {
		$title = $nodeTitle->nodeValue;
		$link = $nodeTitle->getAttribute("href");
		if (substr($link, 0, 4) != "http") {
			$link = "https://www.praha12.cz" . $link;
		}
		$aNewRecord = array("title" => $title);
		$aNewRecord["infoLink"] = $link;
		
		$nodeDate = $xpath->query("span", $node)->item(0);
		if ($nodeDate != NULL) {
			$date = $nodeDate->nodeValue;
			$date = substr($date, 1, strlen($str)-1);
			$aNewRecord["date"] = $date;
		}
		
		$nodeText = $xpath->query("div[1]", $node)->item(0);
		if ($nodeDate != NULL) {
			$text = $nodeText->nodeValue;
			$aNewRecord["text"] = $text;
		}
    	//echo "Node($i): TITLE: ", $title, "; DATE: ", $date, "; LINK: ", $link, "; TEXT: ", $text, "\n";
		$aNewRecord["filter"] = "praha12.cz";
    	array_push($arrItems, $aNewRecord);
    }
}
$arr = array("items" => $arrItems);
$encoded = json_encode($arr, JSON_UNESCAPED_UNICODE);
$filename = "parse_rad.json";
file_put_contents($filename, $encoded, LOCK_EX);
chmod($filename, 0644);
echo "done."
?>
