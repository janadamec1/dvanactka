<?php
include_once "parse_common.php";

function downloadKontakt(&$arrItems, $linkKontakt, $sOdbor, $sCatName) {
	$domKontakt = new DomDocument;
	$domKontakt->loadHTMLFile($linkKontakt);
	$xpathKontakt = new DomXPath($domKontakt);
	$nodeName = firstItem($xpathKontakt->query("//div[@id='stred']/div/h2[@class='cvi notranslate']"));
	if ($nodeName !== NULL) {
		$aNewRecord = array("title" => $nodeName->nodeValue);	// person name
		$aNewRecord["infoLink"] = $linkKontakt;
		$aNewRecord["filter"] = $sOdbor;
		if (strlen($sCatName) > 0)
			$aNewRecord["category"] = $sCatName;
		
		$nodeParent = firstItem($xpathKontakt->query("//div[@id='kvlevo']"));
		if ($nodeParent !== NULL) {
			$nodeText = firstItem($xpathKontakt->query("div[@class='zobrazeno']", $nodeParent));
			if ($nodeText !== NULL) {
				$aNewRecord["text"] = $nodeText->nodeValue;		// what he does
			}
			$nodeAddress = firstItem($xpathKontakt->query("div[@class='popis']/text()", $nodeParent));
			if ($nodeAddress !== NULL) {
				$sAddress = trim($nodeAddress->nodeValue, " [");
				$aNewRecord["address"] = $sAddress;
			}
			$nodesTel = $xpathKontakt->query("dl/dd", $nodeParent);
			foreach ($nodesTel as $i => $nodeTel) {
				$sItem = $nodeTel->nodeValue;
				$iColon = strpos($sItem, ':');
				if ($iColon !== FALSE) {
					$sLabel = substr($sItem, 0, $iColon);
					$sValue = substr($sItem, $iColon+2);
					if ($sLabel == "pevná linka")
						$aNewRecord["phone"] = $sValue;
					else if ($sLabel == "mobilní")
						$aNewRecord["phone_mobile"] = $sValue;
					else if ($sLabel == "oficiální")
						$aNewRecord["email"] = $sValue;
				}
			}
		}
		array_push($arrItems, $aNewRecord);
	}
}

function downloadOdbor(&$arrItems, $title, $link) {
	$domOdbor = new DomDocument;
	$domOdbor->loadHTMLFile($link);
	$xpathOdbor = new DomXPath($domOdbor);
	$nodesUtvary = $xpathOdbor->query("//div[@class='utvary']/ul/li");
	foreach ($nodesUtvary as $i => $nodeUtvar) {
		$sCatName = "";
		$sKontaktQuery = "strong/a";
		$sLiClass = $nodeUtvar->getAttribute("class");
		if ($sLiClass !== "o") {
			$sKontaktQuery = "ul/li[@class='o']/strong/a";
			$nodeCategoryName = firstItem($xpathOdbor->query("strong", $nodeUtvar));
			if ($nodeCategoryName !== NULL) {
				$sCatName = $nodeCategoryName->nodeValue;	// vedouci, nazev oddeleni, ...
			}
		}
			
		$nodesKontakty = $xpathOdbor->query($sKontaktQuery, $nodeUtvar);
		foreach ($nodesKontakty as $j => $nodeKontakt) {
			$linkKontakt = $nodeKontakt->getAttribute("href");
			if (substr($linkKontakt, 0, 4) != "http") {
				$linkKontakt = "http://www.praha12.cz" . $linkKontakt;
			}
			downloadKontakt($arrItems, $linkKontakt, $title, $sCatName);
		}
	}
}

$arrItems = array();
$dom = new DomDocument;
$dom->loadHTMLFile("http://www.praha12.cz/osp/p1=2021");
$xpath = new DomXPath($dom);
$nodes = $xpath->query("//div[@id='menu']/ul[@class='menu']/li[@class='akt']/ul/li");
foreach ($nodes as $i => $node) {
	$nodeTitle = firstItem($xpath->query("a", $node));
	if ($nodeTitle != NULL) {
		$title = trim($nodeTitle->nodeValue);
		$link = $nodeTitle->getAttribute("href");
		if (substr($link, 0, 4) != "http") {
			$link = "http://www.praha12.cz" . $link;
		}

		downloadOdbor($arrItems, $title, $link);
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
