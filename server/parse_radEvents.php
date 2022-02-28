<?php
include_once "parse_common.php";

$sKlubSlunicko = "Sluníčko";
$sTypAkce = "Typ akce";

$response_xml_data = file_get_contents("https://www.praha12.cz/rss2/?12");
//print_r($response_xml_data);

$arrItems = array();
$dom = new DomDocument;
$dom->loadXML($response_xml_data);
$xpath = new DomXPath($dom);
$nodes = $xpath->query("//event");
foreach ($nodes as $i => $node) {
	$nodeTitle = firstItem($xpath->query("name", $node));
	if ($nodeTitle != NULL) {
		$title = $nodeTitle->nodeValue;

		//echo $title, "\n";

		if (substr($title, 0, strlen($sKlubSlunicko)) == $sKlubSlunicko)
			continue;

		$link = "";
		$nodeLink = firstItem($xpath->query("url", $node));
		if ($nodeLink != NULL) {
			$link = $nodeLink->nodeValue;
		}

		$aNewRecord = array("title" => $title);
		$aNewRecord["infoLink"] = $link;

		$nodeDate = firstItem($xpath->query("dates/date", $node));
		if ($nodeDate != NULL) {
			$nodeDateStart = firstItem($xpath->query("start_date", $nodeDate));
			if ($nodeDateStart != NULL) {
				$sDateFrom = $nodeDateStart->nodeValue;

				$sDateFromTime = "00:00";
				$nodeDateStartTime = firstItem($xpath->query("start_time", $nodeDate));
				if ($nodeDateStartTime != NULL) {
					$sDateFromTime = $nodeDateStartTime->nodeValue;
			
				}
				$sDateTo = $sDateFrom;
				$nodeDateEnd = firstItem($xpath->query("end_date", $nodeDate));
				if ($nodeDateEnd != NULL) {
					$sDateTo = $nodeDateEnd->nodeValue;
			
				}
				$sDateToTime = "00:00";
				$nodeDateEndTime = firstItem($xpath->query("end_time", $nodeDate));
				if ($nodeDateEndTime != NULL) {
					$sDateToTime = $nodeDateEndTime->nodeValue;
			
				}

				$aNewRecord["date"] = $sDateFrom."T".$sDateFromTime;
				$aNewRecord["dateTo"] = $sDateTo."T".$sDateToTime;
			}
			
		}
		

		$sFilter = "praha12.cz";
		$nodePlace = firstItem($xpath->query("places/place/other", $node));
		if ($nodePlace != NULL) {
			$sAddress = $nodePlace->nodeValue;

			if (strpos($sAddress, "Pertoldova") !== FALSE) {
				$sAddress = "KC \"12\" @ Pertoldova 10, Praha 12";
				$sFilter = "KC \"12\" pobočka Pertoldova";
			}
			else if (strpos($sAddress, "Jordana Jovkova") !== FALSE) {
				$sAddress = "KC \"12\" @ Jordana Jovkova 20, Praha 12";
				$sFilter = "KC \"12\" pobočka Jordana Jovkova";
			}
			else if (strpos($sAddress, "KC Novodv") !== FALSE) {
				$sAddress = "KC Novodvorská @ Novodvorská 151, Praha 4";
				$sFilter = "KC Novodvorská";
			}
			else if (strpos($sAddress, "Husova knihovna") !== FALSE) {
				$sAddress = "Husova knihovna @ Komořanská 12, Praha 12";
				$sFilter = "Husova knihovna";
			}
			else if (strpos($sAddress, "MC Balónek") !== FALSE) {
				$sAddress = "MC Balónek @ Ke Kamýku 2, Praha 12";
				$sFilter = "MC Balónek";
			}
			else if (strpos($sAddress, "Viniční domek") !== FALSE) {
				$sAddress = "Viniční domek @ Chuchelská 1, Praha 12";
			}
			else if (strpos($sAddress, "PRIOR") !== FALSE) {
				$sAddress = "PRIOR @ Sofijské náměstí 6, Praha 12";
			}
			else if (strpos($sAddress, "Poliklinika Mod") !== FALSE) {
				$sAddress = "Poliklinika Modřany @ Soukalova 3355, Praha 12";
			}
			else if (strpos($sAddress, "biograf") !== FALSE)
				$sAddress = "Modřanský biograf @ U Kina 1, Praha 12";
			$aNewRecord["address"] = $sAddress;
		}

		$nodeText = firstItem($xpath->query("description", $node));
		if ($nodeText != NULL) {
			$text = $nodeText->nodeValue;
			if (substr($text, 0, strlen($sTypAkce)) != $sTypAkce) {
				$aNewRecord["text"] = $text;

				if (strpos($text, "jara@kc12.cz") !== FALSE) {
					$aNewRecord["email"] = "jara@kc12.cz";
					$aNewRecord["phone"] = "778 482 787";
				}
			}
		}
		$aNewRecord["filter"] = $sFilter;
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
	$filename = "items_radEvents.json";
	file_put_contents($filename, $encoded, LOCK_EX);
	chmod($filename, 0644);
	//echo $encoded;
}
echo "radEvents_od done, " . count($arrItems) . " items\n";
?>
