<?php

function firstItem($arrNodes) {
	if ($arrNodes === NULL || $arrNodes === FALSE) return NULL;
	return $arrNodes->item(0);
}

/* Set HTTP response header to plain text for debugging output */
header("Content-type: text/plain");
/* Use internal libxml errors -- turn on in production, off for debugging */
libxml_use_internal_errors(true);

$sKlubSlunicko = "Klub Slun";
$sTypAkce = "Typ akce";

$arrItems = array();
$dom = new DomDocument;
$dom->loadHTMLFile("http://www.praha12.cz/vismo/kalendar-akci.asp?pocet=100");
$xpath = new DomXPath($dom);
$nodes = $xpath->query("//div[@class='dok']//ul[@class='ui']//li");
foreach ($nodes as $i => $node) {
	$nodeTitle = firstItem($xpath->query("strong/a", $node));
	if ($nodeTitle != NULL) {
		$title = $nodeTitle->nodeValue;
		
		if (substr($title, 0, strlen($sKlubSlunicko)) == $sKlubSlunicko)
			continue;
		
		$link = $nodeTitle->getAttribute("href");
		if (substr($link, 0, 4) != "http") {
			$link = "https://www.praha12.cz" . $link;
		}
		$aNewRecord = array("title" => $title);
		$aNewRecord["infoLink"] = $link;
		
		$nodeDate = firstItem($xpath->query("div[1]", $node));
		if ($nodeDate != NULL) {
			// strip address, is after comma
			$sDateFromTo = $nodeDate->nodeValue;
			$iCommaPos = strpos($sDateFromTo, ",");
			if ($iCommaPos !== FALSE) {
				$aNewRecord["address"] = trim(substr($sDateFromTo, $iCommaPos+1));
				$sDateFromTo = substr($sDateFromTo, 0, $iCommaPos);
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
						$dateFrom = date_create_from_format("!j.n.Y G:i", $sDateTo);
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
		$aNewRecord["filter"] = "praha12.cz";
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
echo "done.";
?>
