<?php
include_once "parse_common.php";

function downloadEmployee(&$arrItems, $linkKontakt, $sOdbor, $sCatName) {
	$domKontakt = new DomDocument;
	$domKontakt->loadHTMLFile($linkKontakt);
	$xpathKontakt = new DomXPath($domKontakt);
	$nodeName = firstItem($xpathKontakt->query("//div[@id='stred']/div[@id='zahlavi']/h2"));
	if ($nodeName !== NULL) {
		$aNewRecord = array("title" => $nodeName->nodeValue);	// person name
		$aNewRecord["infoLink"] = $linkKontakt;
		$aNewRecord["filter"] = $sOdbor;
		if (strlen($sCatName) > 0)
			$aNewRecord["category"] = $sCatName;

		$nodeParent = firstItem($xpathKontakt->query("//div[@class='obsah']/div[@id='kvlevo']"));
		if ($nodeParent !== NULL) {
			$nodeText = firstItem($xpathKontakt->query("div[@class='zobrazeno text-to-speech']", $nodeParent));
			if ($nodeText !== NULL) {
				$aNewRecord["text"] = $nodeText->nodeValue;		// what he does
			}
			$nodeAddress = firstItem($xpathKontakt->query("div[@class='popis text-to-speech']/text()", $nodeParent));
			if ($nodeAddress !== NULL) {
				$sAddress = $nodeAddress->nodeValue;
				if (strpos($sAddress, " [") !== FALSE)  // contains "na mape"
  				$aNewRecord["address"] = trim($sAddress, " [");
			}
			/*  // not everybody has this address
			$nodeAddress = firstItem($xpathKontakt->query("dl[@class='neodsadit text-to-speech']/dd/div[2]", $nodeParent));
			if ($nodeAddress !== NULL) {
				$sAddress = trim($nodeAddress->nodeValue);
				$aNewRecord["address"] = $sAddress;
			}*/
			$nodesTel = $xpathKontakt->query("dl[@class='text-to-speech']/dd", $nodeParent);
			foreach ($nodesTel as $i => $nodeTel) {
				$sItem = $nodeTel->nodeValue;
				$iColon = strpos($sItem, ':');
				if ($iColon !== FALSE) {
					$sLabel = substr($sItem, 0, $iColon);
					$sValue = substr($sItem, $iColon+2);
					if ($sLabel == "pevná linka")
						$aNewRecord["phone"] = $sValue;
					else if ($sLabel == "mobilní")
						$aNewRecord["phoneMobile"] = $sValue;
					else if ($sLabel == "oficiální")
						$aNewRecord["email"] = $sValue;
				}
			}
		}
		array_push($arrItems, $aNewRecord);
	}
}

//------------------------------------------------------------------------
function downloadKontakty(&$arrItems, $linkKontakty, $sOdbor) {
	$domKontakty = new DomDocument;
	$domKontakty->loadHTMLFile($linkKontakty);
	$xpathOdborKont = new DomXPath($domKontakty);
	$nodesKategorie = $xpathOdborKont->query("//dl[@class='kontakty']//ul/li");
	foreach ($nodesKategorie as $i => $nodeUtvar) {
		$sCatName = "";
  	$nodeCatTitle = firstItem($xpathOdborKont->query("strong/a", $nodeUtvar));
    if ($nodeCatTitle !== NULL)
      $sCatName = trim($nodeCatTitle->nodeValue);

		$nodesKontakty = $xpathOdborKont->query("ul/li/strong/a", $nodeUtvar);
		foreach ($nodesKontakty as $j => $nodeKontakt) {
			$linkKontakt = $nodeKontakt->getAttribute("href");
			if (substr($linkKontakt, 0, 4) != "http") {
				$linkKontakt = "http://www.praha12.cz" . $linkKontakt;
			}
			downloadEmployee($arrItems, $linkKontakt, $sOdbor, $sCatName);
		}
	}
}

//------------------------------------------------------------------------
function downloadAgenda($linkAgenda, $sOdbor) {
  //echo "agenda download\n";
	$domAgenda = new DomDocument;
	$domAgenda->loadHTMLFile($linkAgenda);
	$xpathAgenda = new DomXPath($domAgenda);
	$nodeAgenda = firstItem($xpathAgenda->query("//div[@id='dokument']/div[@class='editor text-to-speech']"));
	if ($nodeAgenda != NULL) {
		$sHtml = $domAgenda->saveHTML($nodeAgenda);
		if ($sHtml !== FALSE) {
			return $sHtml;
		}
	}
	return "";
}

//------------------------------------------------------------------------
function downloadSituations(&$arrItems, $linkSituat, $sOdbor) {
	$domSituat = new DomDocument;
	$domSituat->loadHTMLFile($linkSituat);
	$xpathSituat = new DomXPath($domSituat);
	$nodesSituat = $xpathSituat->query("//div[@class='obsah']/div[@class='dok']/ul/li/strong/a");
	foreach ($nodesSituat as $i => $nodeSit) {
		$aNewRecord = array("title" => $nodeSit->nodeValue);
		$linkSit = $nodeSit->getAttribute("href");
		if (substr($linkSit, 0, 4) != "http") {
			$linkSit = "http://www.praha12.cz" . $linkSit;
		}
		$aNewRecord["infoLink"] = $linkSit;
		$aNewRecord["filter"] = $sOdbor;
		$aNewRecord["category"] = "Jak zařídit";
		array_push($arrItems, $aNewRecord);
	}
	// this odbor has sub-categories, go for them
	$nodesKategorie = $xpathSituat->query("//div[@class='obsah']/div[@class='kategorie souvisejiciodkazy']/ul/li/strong/a");
	foreach ($nodesKategorie as $i => $nodeKat) {
		$linkKat = $nodeKat->getAttribute("href");
		if (substr($linkKat, 0, 4) != "http") {
			$linkKat = "http://www.praha12.cz" . $linkKat;
		}
		downloadSituations($arrItems, $linkKat, $sOdbor);
	}
}

//------------------------------------------------------------------------
function downloadSituationsIntro(&$arrItems, $linkSituat, $sOdbor) {
	$domSituat = new DomDocument;
	$domSituat->loadHTMLFile($linkSituat);
	$xpathSituat = new DomXPath($domSituat);
	$nodesKategorie = $xpathSituat->query("//div[@class='obsah mapa-stranek-2016']/div[@class='odkazy souvisejici text-to-speech']/div/a");
	foreach ($nodesKategorie as $i => $nodeKat) {
		$linkKat = $nodeKat->getAttribute("href");
		if (substr($linkKat, 0, 4) != "http") {
			$linkKat = "http://www.praha12.cz" . $linkKat;
		}
		downloadSituations($arrItems, $linkKat, $sOdbor);
	}
}

//------------------------------------------------------------------------
function downloadOdbor(&$arrItems, $title, $link) {
	$domOdbor = new DomDocument;
	$domOdbor->loadHTMLFile($link);
	$xpathOdbor = new DomXPath($domOdbor);

	$sAddress = "";
	$linkKontakty = "";
	$linkSituations = "";

  //echo "odbor download\n";

  // find kategories
	$nodesOdkazy = $xpathOdbor->query("//div[@class='obsah mapa-stranek-2016']/div/ul[@class='ui']/li/strong/a");
	foreach ($nodesOdkazy as $i => $nodeOdkaz) {
		$linkOdkaz = $nodeOdkaz->getAttribute("href");
		if (substr($linkOdkaz, 0, 4) != "http") {
			$linkOdkaz = "http://www.praha12.cz" . $linkOdkaz;
    }
		$sKategorie = trim($nodeOdkaz->nodeValue);
		if ($sKategorie === "Kontakt" || $sKategorie === "Kontakty")
		  $linkKontakty = $linkOdkaz;
		else if ($sKategorie === "Náplň činnosti")
		  $sAgendaHtml = downloadAgenda($linkOdkaz, $title);
		else if ($sKategorie === "Životní situace")
		  $linkSituations = $linkOdkaz;
	}

	if (strlen($sAddress) > 0 || strlen($sAgendaHtml) > 0) {
		$aNewRecord = array("title" => $title);
		$aNewRecord["infoLink"] = $link;
		$aNewRecord["filter"] = $title;
		$aNewRecord["category"] = "O odboru";
		if (strlen($sAddress) > 0)
			$aNewRecord["address"] = $sAddress;
		if (strlen($sAgendaHtml) > 0)
			$aNewRecord["text"] = $sAgendaHtml;
		array_push($arrItems, $aNewRecord);
	}

	if (strlen($linkSituations) > 0) {
		downloadSituationsIntro($arrItems, $linkSituations, $title);
	}
	if (strlen($linkKontakty) > 0) {
		downloadKontakty($arrItems, $linkKontakty, $title);
	}
	else {
	  // vedeni metske casti ma lidi rovnou tady
    $nodesKontakty = $xpathOdbor->query("//dl[@class='kontakty']//ul/li/strong/a");
    foreach ($nodesKontakty as $i => $nodeKontakt) {
      $linkKontakt = $nodeKontakt->getAttribute("href");
      if (substr($linkKontakt, 0, 4) != "http") {
        $linkKontakt = "http://www.praha12.cz" . $linkKontakt;
      }
      downloadEmployee($arrItems, $linkKontakt, $title, "");
    }
	}
}

//------------------------------------------------------------------------
$arrItems = array();
$dom = new DomDocument;
$dom->loadHTMLFile("http://www.praha12.cz/odbory-umc-praha-12/ms-64333/p1=64333");
$xpath = new DomXPath($dom);
$nodes = $xpath->query("//div[@class='odkazy souvisejici text-to-speech souvisejiciodkazy']/ul[@class='ui']/li");
foreach ($nodes as $i => $node) {
	$nodeTitle = firstItem($xpath->query("strong/a", $node));
	if ($nodeTitle != NULL) {
		$title = trim($nodeTitle->nodeValue);
		$link = $nodeTitle->getAttribute("href");
		if (substr($link, 0, 4) != "http") {
			$link = "http://www.praha12.cz" . $link;
		}

    //echo "odbor " . $title . "\n";

		//if (substr($title, 0, 16) === "Odbor komunikace")
		//  downloadOdbor($arrItems, $title, $link);

		downloadOdbor($arrItems, $title, $link);

    //if (count($arrItems) > 0) break;
	}
}

if (count($arrItems) > 0) {
	$arr = array("items" => $arrItems);
	$encoded = json_encode($arr, JSON_UNESCAPED_UNICODE);
	$filename = "dyn_cityOffice.json";
	file_put_contents($filename, $encoded, LOCK_EX);
	chmod($filename, 0644);
	echo $encoded;
}
echo "done, " . count($arrItems) . " items";
?>
