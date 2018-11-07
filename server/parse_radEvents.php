<?php
include_once "parse_common.php";

$sKlubSlunicko = "Sluníčko";
$sTypAkce = "Typ akce";

$arrItems = array();
$dom = new DomDocument;
$dom->loadHTMLFile("http://www.praha12.cz/vismo/kalendar-akci.asp?pocet=100");
$xpath = new DomXPath($dom);
$nodes = $xpath->query("//div[@class='dok']//ul[@class='ui']//li");
foreach ($nodes as $i => $node) {
	$nodeTitle = firstItem($xpath->query("strong/a", $node));
	if ($nodeTitle != NULL) {
	    if ($nodeTitle->lastChild != NULL)
		    $title = $nodeTitle->lastChild->textContent;    // remove script
	    else
		    $title = $nodeTitle->nodeValue;

		if (substr($title, 0, strlen($sKlubSlunicko)) == $sKlubSlunicko)
			continue;

		$link = $nodeTitle->getAttribute("href");
		if (substr($link, 0, 4) != "http") {
			$link = "https://www.praha12.cz" . $link;
		}
		$aNewRecord = array("title" => $title);
		$aNewRecord["infoLink"] = $link;

		$sFilter = "praha12.cz";
		$nodeDate = firstItem($xpath->query("div[1]", $node));
		if ($nodeDate != NULL) {
			// strip address, is after comma
			$sDateFromTo = $nodeDate->nodeValue;
			$iCommaPos = strpos($sDateFromTo, ",");
			if ($iCommaPos !== FALSE) {
				$sAddress = trim(substr($sDateFromTo, $iCommaPos+1));
				$sDateFromTo = substr($sDateFromTo, 0, $iCommaPos);

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
				else if (strpos($sAddress, "biograf") !== FALSE)
					$sAddress = "Modřanský biograf @ U Kina 1, Praha 12";
				$aNewRecord["address"] = $sAddress;
			}
			// split time from - to
			$arrFromTo = explode("-", $sDateFromTo);
			$iArrFromToCount = count($arrFromTo);
			if ($iArrFromToCount > 0) {		// date & time from
				$sDateFrom = trim($arrFromTo[0]);
				//echo $sDateFrom, "\n";
				$arrFrom = explode(" ", $sDateFrom);
				$dateFrom = NULL;
				if (count($arrFrom) > 1) {	// time from (optional)
					$dateFrom = date_create_from_format("!j.n.Y G:i+", $sDateFrom);
				}
				else {
					$dateFrom = date_create_from_format("!j.n.Y+", $sDateFrom);
				}
				if ($dateFrom === NULL || $dateFrom === FALSE) {
					echo "Error date: " . $sDateFrom;
				}
				else
					$aNewRecord["date"] = date_format($dateFrom, "Y-m-d\TH:i");

				if ($iArrFromToCount > 1) {		// date & time to
					$sDateTo = trim($arrFromTo[1]);
					//echo $sDateTo, " -- TO\n";
					$arrTo = explode(" ", $sDateTo);
					$iArrToCount = count($arrTo);
					$dateTo = NULL;
					if ($iArrToCount > 1) {	// we have both date and time
						$dateTo = date_create_from_format("!j.n.Y G:i", $sDateTo);
					}
					else {
						// determine if date or time is given
						if (strstr($sDateTo, ":") === FALSE) {
							$dateTo = date_create_from_format("!j.n.Y", $sDateTo); // only date
						}
						else {
							$sFullTo = $arrFrom[0] . " " . $sDateTo;
							//echo $sFullTo, " -- FULL\n";
							$dateTo = date_create_from_format("!j.n.Y G:i", $sFullTo); // only time
						}
					}
					if ($dateTo == null)
						echo $nodeDate->nodeValue ."\n";
					$aNewRecord["dateTo"] = date_format($dateTo, "Y-m-d\TH:i");
				}
			}
		}

		$nodeText = firstItem($xpath->query("div[2]", $node));
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
echo "radEvents done, " . count($arrItems) . " items\n";
?>
