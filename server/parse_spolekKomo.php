<?php
include_once "parse_common.php";

$arrItems = array();
$dom = new DomDocument;
//$dom->loadHTMLFile("http://www.spolekprokomorany.cz/aktuality/");
$html = file_get_contents("https://www.spolekprokomorany.cz/aktuality/");
$html = mb_convert_encoding($html,'HTML-ENTITIES','UTF-8');
$dom->loadHTML($html);
$xpath = new DomXPath($dom);
$nodes = $xpath->query("//article/div[@class='item-wrapper']");
foreach ($nodes as $i => $node) {
	$nodeHead = firstItem($xpath->query("div[@class='item-content']/div[@class='item-head']", $node));
	if ($nodeHead != NULL) {
		$nodeTitle = $xpath->query("h2", $nodeHead)->item(0);
		if ($nodeTitle != NULL) {
			$title = trim($nodeTitle->nodeValue);
			$aNewRecord = array("title" => $title);

			$nodeDate = firstItem($xpath->query("div[@class='item-date']", $nodeHead));
			if ($nodeDate != NULL) {
				$date = date_create_from_format("!j.n.Y", trim($nodeDate->nodeValue));
				$aNewRecord["date"] = date_format($date, "Y-m-d\TH:i");
			}

			$nodeLink = firstItem($xpath->query("a", $nodeTitle));
			if ($nodeLink != NULL) {
				$link = $nodeLink->getAttribute("href");
				$aNewRecord["infoLink"] = "https://www.spolekprokomorany.cz" . $link;
			}

      $nodeIllustration = firstItem($xpath->query("div[@class='item-media']/a/div/img", $node));
      if ($nodeIllustration != NULL) {
        $linkImg = $nodeIllustration->getAttribute("src");
        if ($linkImg != "") {
          if (substr($linkImg, 0, 4) != "http") {
            $linkImg = "https://www.spolekprokomorany.cz" . $linkImg;
          }
          $aNewRecord["illustrationImgLink"] = $linkImg;
        }
      }

			$nodeText = firstItem($xpath->query("div[@class='item-content']/div[@class='item-perex']/div/div[@class='perex-content']", $node));
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

	$filename = "items_spolekKomo.json";
	file_put_contents($filename, $encoded, LOCK_EX);
	chmod($filename, 0644);
	//echo $encoded;
}
echo "Komo done, " . count($arrItems) . " items\n";
?>
