<?php
include_once "parse_common.php";

error_reporting(E_ALL);
ini_set('display_errors', true);
ini_set('html_errors', false);

function downloadSituation(&$aNewRecord, $linkSit) {

  $arrDetailLevel = array(0,
    3, 3, 1, 1, 1,  /* 1 - 5 */
    1, 3, 1, 0, 0,  /* 6 - 10 */
    0, 0, 1, 1, 1,  /* 11 - 15 */
    1, 2, 3, 2, 2,  /* 16 - 20 */
    3, 3, 2, 2, 3,  /* 21 - 25 */
    3, 3, 1, 1, 3,  /* 25 - 30 */
    3, 3, 3, 0, 3
    );
  //var_dump($arrDetailLevel);

  //echo "\ndownloading " . $linkSit;
  $domSit = new DomDocument;
  $domSit->loadHTMLFile($linkSit);
  $xpathSit = new DomXPath($domSit);

  // replace all relative a.hrefs with absolute url
  foreach ($xpathSit->query("//a[starts-with(@href, '/')]") as $node) {
      $node->setAttribute("href", "https://www.praha12.cz" . $node->getAttribute("href"));
  }

	$nodeSitText = firstItem($xpathSit->query("//div[@class='text-to-speech']/dl"));
  if ($nodeSitText != NULL) {
    //echo " - found";
		$nodesDT = $xpathSit->query("dt", $nodeSitText);
		$nodesDD = $xpathSit->query("dd", $nodeSitText);
		if (count($nodesDT) == count($nodesDD)) {
      $arrQAs = array();
		  foreach ($nodesDT as $it => $nodeDT) {
		    $nodeDD = $nodesDD[$it];
        $aNewQA = array("q" => trim($nodeDT->nodeValue));
        //$aNewQA["a"] = $nodeDD->nodeValue;

        $sHtml = $domSit->saveHTML($nodeDD);
        if ($sHtml !== FALSE)
          $aNewQA["a"] = $sHtml;
        else
          $aNewQA["a"] = trim($nodeDD->nodeValue);

        // detail level
   			$arrParts = explode(".", trim($nodeDT->nodeValue));
  			if (count($arrParts) >= 2) {
          $iIdx = intval($arrParts[0]);
          $aNewQA["lvl"] = $arrDetailLevel[$iIdx];
          //echo "\n i ". $iIdx . " lvl " . $arrDetailLevel[$iIdx];
  			}

	      array_push($arrQAs, $aNewQA);
	    }
      $aNewRecord["qa"] = $arrQAs;
      return count($arrQAs);
		}
	}
	return 0;
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

			if (downloadSituation($aNewRecord, $link) > 0)
  	    array_push($arrItems, $aNewRecord);
	    //break;  // break after 1st situation
    }
	  //break;  // break after 1st category
  }
}
if (count($arrItems) > 0) {

	$arr = array("items" => $arrItems);
	$arr["qaLables"] = array("Stručné", "Základní", "Rozšířené", "Úplné");
	$encoded = json_encode($arr, JSON_UNESCAPED_UNICODE);
	$filename = "dyn_radSituations.json";
	file_put_contents($filename, $encoded, LOCK_EX);
	chmod($filename, 0644);
	echo $encoded;
}
echo "radSituations done, " . count($arrItems) . " items\n";
?>
