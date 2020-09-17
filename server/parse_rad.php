<?php
include_once "parse_common.php";

$arrItems = array();
$dom = new DomDocument;
$dom->loadHTMLFile("https://www.praha12.cz/dp/id_ktg=1154");
$xpath = new DomXPath($dom);
$nodes = $xpath->query("//div[@class='dok']/ul/li");
foreach ($nodes as $i => $node) {
	$nodeTitle = firstItem($xpath->query("strong/a", $node));
	if ($nodeTitle != NULL) {
	    if ($nodeTitle->lastChild != NULL)
		    $title = $nodeTitle->lastChild->textContent;    // remove script
	    else
		    $title = $nodeTitle->nodeValue;
		$link = $nodeTitle->getAttribute("href");
		if (substr($link, 0, 4) != "http") {
			$link = "https://www.praha12.cz" . $link;
		}
		$aNewRecord = array("title" => $title);
		$aNewRecord["infoLink"] = $link;

		$nodeDate = firstItem($xpath->query("span", $node));
		if ($nodeDate != NULL) {
			$date = date_create_from_format("(!j.n.Y)", $nodeDate->nodeValue);
			$aNewRecord["date"] = date_format($date, "Y-m-d\TH:i");
		}

		$nodeText = firstItem($xpath->query("div[1]", $node));
		if ($nodeText != NULL) {
			$text = $nodeText->nodeValue;
			$aNewRecord["text"] = $text;
		}

		$nodeIllustration = firstItem($xpath->query("object/noscript/img", $nodeTitle));
		if ($nodeIllustration != NULL) {
      $linkImg = $nodeIllustration->getAttribute("src");
      if ($linkImg != "") {
        if (substr($linkImg, 0, 4) != "http") {
          $linkImg = "https://www.praha12.cz" . $linkImg;
        }
        $aNewRecord["illustrationImgLink"] = $linkImg;
      }
		}

		$aNewRecord["filter"] = "MČ Praha 12";
		if (array_key_exists("date", $aNewRecord))
	    	array_push($arrItems, $aNewRecord);
    }
}

if (count($arrItems) > 0) {
	$arr = array("items" => $arrItems);
	$encoded = json_encode($arr, JSON_UNESCAPED_UNICODE);
	$filename = "dyn_radAktual.json";
	file_put_contents($filename, $encoded, LOCK_EX);
	chmod($filename, 0644);
	//echo $encoded;
}
echo "parse_rad done, " . count($arrItems) . " items\n";
?>
