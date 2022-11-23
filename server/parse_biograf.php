<?php
include_once "parse_common.php";

$sAddress = "Modřanský biograf\nU Kina 1\n143 00 Praha 12 - Modřany";

$arrItems = array();
$dom = new DomDocument;
$dom->loadHTMLFile("https://www.informuji.cz/kina/program-kina-modransky-biograf.html?id=97&na=tyden");
//echo $dom->saveHTML();
	
$xpath = new DomXPath($dom);
$nodes = $xpath->query("//div[@id='film']/div");
foreach ($nodes as $i => $node) {
	$nodeTitle = firstItem($xpath->query("div[@class='movieName']/h2", $node));
	if ($nodeTitle != NULL) {
		$title = $nodeTitle->nodeValue;

		//echo "title: " . $title . "\n";

		$link = "http://www.modranskybiograf.cz";  // sadly cannot get the actual link to this website
		
		$nodesDates = $xpath->query("div[@class='movieTimes']/table/tr/td[@class='time']", $node);
		foreach ($nodesDates as $id => $nodeDate) {
			$nodeDateText = firstItem($xpath->query("strong/em", $nodeDate));

			if ($nodeDateText == NULL) continue;

			//echo "date: " . $nodeDateText->nodeValue . "\n";
			
			$nodesTimes = $xpath->query("span", $nodeDate);
			foreach ($nodesTimes as $it => $nodeTime) {
				
				//echo "dateTime: " . $nodeDateText->nodeValue . " at " . $nodeTime->nodeValue . "\n";
				
				$sDateTime = $nodeDateText->nodeValue . date("Y") . " ". $nodeTime->nodeValue;
				$date = date_create_from_format("!j.n.Y G:i", $sDateTime);
				if ($date !== FALSE) {
					if ($date->format("n") < date("n")) {  // when adding year manually, we may have to go to next year
						$date = date_add($date, new DateInterval('P1Y'));
					}
					
					$aNewRecord = array("title" => $title);
					$aNewRecord["infoLink"] = $link;

					$aNewRecord["address"] = $sAddress;
					$aNewRecord["date"] = date_format($date, "Y-m-d\TH:i");
					
					//$aNewRecord["buyLink"] = $nodeTime->getAttribute("href");
					
					array_push($arrItems, $aNewRecord);
				}
			}
		}
    }
}
if (count($arrItems) > 0) {
	$arr = array("items" => $arrItems);
	$encoded = json_encode($arr, JSON_UNESCAPED_UNICODE);
	$filename = "dyn_biograf.json";
	file_put_contents($filename, $encoded, LOCK_EX);
	chmod($filename, 0644);
	echo $encoded;
}
echo "Biograf done, " . count($arrItems) . " items\n";
?>
