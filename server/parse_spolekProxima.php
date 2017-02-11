<?php
include_once "parse_common.php";

$arrMonths = array("0", "ledna", "února", "března", "dubna", "května", "června", "července", "srpna", "září", "října", "listopadu", "prosince");

$arrItems = array();
$dom = new DomDocument;
//$dom->loadHTMLFile("http://www.proximasociale.cz/proxima-sociale/aktuality/");
$html = file_get_contents("http://www.proximasociale.cz/proxima-sociale/aktuality/");
$html = mb_convert_encoding($html,'HTML-ENTITIES','UTF-8');
$dom->loadHTML($html);
$xpath = new DomXPath($dom);
$nodes = $xpath->query("//div[@class='item clearfix']");
foreach ($nodes as $i => $node) {
	$nodeTitle = firstItem($xpath->query("h2", $node));
	if ($nodeTitle != NULL) {
		$title = trim($nodeTitle->nodeValue);
		$aNewRecord = array("title" => $title);
		
		$nodeDate = firstItem($xpath->query("div/div[@class='date']", $node));
		if ($nodeDate != NULL) {
			$arrParts = explode(" ", trim($nodeDate->nodeValue));
			if (count($arrParts) >= 3) {
				$month = array_search($arrParts[1], $arrMonths);
				if ($month !== FALSE) {
					$date = new DateTime();
					$date->setDate($arrParts[2], $month, trim($arrParts[0], "."));
					$date->setTime(0, 0);
					$aNewRecord["date"] = date_format($date, "Y-m-d\TH:i");
				}
			}
		}

		$nodeLink = firstItem($xpath->query("a", $nodeTitle));
		if ($nodeLink != NULL) {
			$link = $nodeLink->getAttribute("href");
			$aNewRecord["infoLink"] = "http://www.proximasociale.cz" . $link;
		}
			
		$nodeText = firstItem($xpath->query("div/p", $node));
		if ($nodeText != NULL) {
			$text = trim($nodeText->nodeValue);
			$aNewRecord["text"] = $text;
		}
		$aNewRecord["filter"] = "Proxima Sociale";
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
	$filename = "items_spolekProxima.json";
	file_put_contents($filename, $encoded, LOCK_EX);
	chmod($filename, 0644);
	//echo $encoded;
}
echo "Proxima done, " . count($arrItems) . " items\n";
?>
