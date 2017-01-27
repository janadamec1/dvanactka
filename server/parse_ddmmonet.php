<?php

function firstItem($arrNodes) {
	if ($arrNodes === NULL || $arrNodes === FALSE) return NULL;
	return $arrNodes->item(0);
}

function downloadEventDetail(&$rec) {
	$domDetail = new DomDocument;
	$domDetail->loadHTMLFile($rec["infoLink"]);
	$xpathDetail = new DomXPath($domDetail);
	$nodesDetail = $xpathDetail->query("//div[@id='akce_detail']/div/table/tr");
	foreach ($nodesDetail as $id => $nodeRadek) {
		$nodesTds = $xpathDetail->query("td", $nodeRadek);
		if ($nodesTds !== NULL && $nodesTds !== FALSE && $nodesTds->length == 2) {
			$sItemName = $nodesTds->item(0)->nodeValue;
			$sItemText = $nodesTds->item(1)->nodeValue;
			if ($sItemName === "Termín konání") {
				// parse date like 14.05.2017 08:00 - 18:00
				
				// following code copied from parse_radEvents.php
				$arrFromTo = explode("-", $sItemText);
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
						$rec["date"] = date_format($dateFrom, "Y-m-d\TH:i");
				
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
						$rec["dateTo"] = date_format($dateTo, "Y-m-d\TH:i");
					}
				}
			}
			if ($sItemName === "Místo konání") {
				if ($sItemText == "DDM Herrmannova")
					$sItemText = "DDM Monet @ Hermannova 24, Praha 12";
				else if ($sItemText == "DDM Urbánkova")
					$sItemText = "DDM Monet @ Urbánkova 4, Praha 12";
				else if ($sItemText == "Mimo stálé objekty")
					$sItemText = "DDM Monet - " . $sItemText;
				$rec["address"] = $sItemText;
			}
		}
	}
}

/* Set HTTP response header to plain text for debugging output */
header("Content-type: text/plain; charset=utf-8");
/* Use internal libxml errors -- turn on in production, off for debugging */
libxml_use_internal_errors(true);

$arrItems = array();
$dom = new DomDocument;
$dom->loadHTMLFile("http://www.ddmmonet.cz/akce-a-udalosti");
$xpath = new DomXPath($dom);
$nodes = $xpath->query("//div[@id='akce_seznam']/div[@class='box']");
foreach ($nodes as $i => $node) {
	$nodeTitle = firstItem($xpath->query("h2", $node));
	if ($nodeTitle != NULL) {
		$title = trim($nodeTitle->nodeValue);
		if (strpos($title, "ZŠ prof. Švejcara") !== FALSE)
			continue;
			
		$aNewRecord = array("title" => $title);
		
		$nodeDate = firstItem($xpath->query("p/span", $node));
		if ($nodeDate != NULL) {
			$date = date_create_from_format("!d.m.Y", $nodeDate->nodeValue);
			if ($date !== FALSE)
				$aNewRecord["date"] = date_format($date, "Y-m-d\TH:i");
			
			$nodeText = firstItem($xpath->query("..", $nodeDate));
			if ($nodeText != NULL) {
				$aNewRecord["text"] = trim(str_replace($nodeDate->nodeValue, "", $nodeText->nodeValue));	// remove date
			}
		}

		$nodeLink = firstItem($xpath->query("div/a", $node));
		if ($nodeLink != NULL) {
			$link = $nodeLink->getAttribute("href");
			$aNewRecord["infoLink"] = "http://www.ddmmonet.cz/" . $link;
		}
			
		$aNewRecord["filter"] = "DDM Monet";
		if (array_key_exists("date", $aNewRecord) && array_key_exists("infoLink", $aNewRecord)) {
			
			// download proper dates and location
			downloadEventDetail($aNewRecord);
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
	$filename = "items_ddmMonetEvents.json";
	file_put_contents($filename, $encoded, LOCK_EX);
	chmod($filename, 0644);
	//echo $encoded;
}
echo "done.";
?>
