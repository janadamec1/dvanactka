<?php
/* Set HTTP response header to plain text for debugging output */
header("Content-type: text/plain; charset=utf-8");
/* Use internal libxml errors -- turn on in production, off for debugging */
libxml_use_internal_errors(true);

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
	$nodeTitle = $xpath->query("h2", $node)->item(0);
	if ($nodeTitle != NULL) {
		$title = trim($nodeTitle->nodeValue);
		$aNewRecord = array("title" => $title);
		
		$nodeDate = $xpath->query("div/div[@class='date']", $node)->item(0);
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

		$nodeLink = $xpath->query("a", $nodeTitle)->item(0);
		if ($nodeLink != NULL) {
			$link = $nodeLink->getAttribute("href");
			$aNewRecord["infoLink"] = "http://www.proximasociale.cz" . $link;
		}
			
		$nodeText = $xpath->query("div/p", $node)->item(0);
		if ($nodeText != NULL) {
			$text = trim($nodeText->nodeValue);
			$aNewRecord["text"] = $text;
		}
		$aNewRecord["filter"] = "Proxima Sociale";
		if (array_key_exists("date", $aNewRecord))
			array_push($arrItems, $aNewRecord);
	}
}

$arr = array("items" => $arrItems);
$encoded = json_encode($arr, JSON_UNESCAPED_UNICODE);
$filename = "dyn_spolekProxima.json";
file_put_contents($filename, $encoded, LOCK_EX);
chmod($filename, 0644);
//echo $encoded;
echo "done.";
?>
