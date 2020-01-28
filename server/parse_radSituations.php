<?php
include_once "parse_common.php";

function downloadSituation(&$aNewRecord, $linkSit) {
  //echo "\ndownloading " . $linkSit;
  $domSit = new DomDocument;
  $domSit->loadHTMLFile($linkSit);
  $xpathSit = new DomXPath($domSit);
	$nodeSitText = firstItem($xpathSit->query("//div[@class='text-to-speech']/dl"));
  if ($nodeSitText != NULL) {
    //echo " - found";
		$sHtml = $domSit->saveHTML($nodeSitText);
		if ($sHtml !== FALSE) {
      //echo " - saved";
      $aNewRecord["text"] = $sHtml;
		}
	}
}

$arrItems = array();
$dom = new DomDocument;
$dom->loadHTMLFile("https://www.praha12.cz/vismo/dokumenty2.asp?id=67295"); // jak zaridit / zivotni situace
$xpath = new DomXPath($dom);
$nodes = $xpath->query("//div[@class='editor text-to-speech']/div");
foreach ($nodes as $i => $node) {
	$nodeTitle = firstItem($xpath->query("b", $node));
	if ($nodeTitle != NULL) {
	  if ($nodeTitle->lastChild != NULL)
		  $title = $nodeTitle->lastChild->textContent;    // remove script
	  else
		  $title = $nodeTitle->nodeValue;

    $nodesSit = $xpath->query("ul/li/a", $node);
    foreach ($nodesSit as $iS => $nodeSit) {

      $titleSit = $nodeSit->nodeValue;

      $link = $nodeSit->getAttribute("href");
      if (substr($link, 0, 4) != "http") {
        $link = "https://www.praha12.cz" . $link;
      }

      $aNewRecord = array("title" => $titleSit);
      $aNewRecord["infoLink"] = $link;
      $aNewRecord["filter"] = $title;

			downloadSituation($aNewRecord, $link);

	    array_push($arrItems, $aNewRecord);
	    //break;
    }
  }
}
if (count($arrItems) > 0) {
	$arr = array("items" => $arrItems);
	$encoded = json_encode($arr, JSON_UNESCAPED_UNICODE);
	$filename = "dyn_radSituations.json";
	file_put_contents($filename, $encoded, LOCK_EX);
	chmod($filename, 0644);
	echo $encoded;
}
echo "radSituations done, " . count($arrItems) . " items\n";
?>
