<?php
include_once "parse_common.php";

$arrItems = array();

// Fetch HTML with caching and proper headers
$html = fetchWebsiteWithHeaders("https://proximasociale.cz/aktuality/", "cache_proxima.html", 3600);

if (!$html) {
	echo "Error: Could not load website\n";
	exit(1);
}

$html = mb_convert_encoding($html,'HTML-ENTITIES','UTF-8');
$dom = new DomDocument;
@$dom->loadHTML($html);
$xpath = new DomXPath($dom);

// Articles with class "bde-loop-item ee-post"
$nodes = $xpath->query("//article[contains(@class, 'bde-loop-item') and contains(@class, 'ee-post')]");

foreach ($nodes as $i => $node) {
	echo "Processing node " . ($i + 1) . " of " . $nodes->length . "\n";
	// Try new structure first (h1 for title)
	$nodeTitle = firstItem($xpath->query(".//h1[contains(@class, 'bde-heading')]", $node));
	
	if ($nodeTitle != NULL) {
		echo "Found title node: " . $nodeTitle->nodeValue . "\n";
		$title = trim($nodeTitle->nodeValue);
		$aNewRecord = array("title" => $title);

		// Try new structure for date (div with bde-text class, usually first one)
		$nodeDate = firstItem($xpath->query(".//div[contains(@class, 'bde-text')][1]", $node));
		
		// Fallback to old structure
		if ($nodeDate == NULL) {
			$nodeDate = firstItem($xpath->query("div/div[@class='date']", $node));
		}
		
		if ($nodeDate != NULL) {
			echo "Found date node: " . $nodeDate->nodeValue . "\n";
			$dateText = trim($nodeDate->nodeValue);
			// Remove non-breaking spaces and normalize
			$dateText = str_replace("\xc2\xa0", " ", $dateText);
			$dateText = preg_replace('/\s+/', ' ', $dateText);
			
			$arrParts = explode(" ", $dateText);
			if (count($arrParts) >= 3) {
				$date = new DateTime();
				$date->setDate($arrParts[2], $arrParts[1], trim($arrParts[0], "."));
				$date->setTime(0, 0);
				$aNewRecord["date"] = date_format($date, "Y-m-d\TH:i");
			}
		}

		// Try new structure for link (a with bde-container-link or in button)
		$nodeLink = firstItem($xpath->query(".//a[contains(@class, 'bde-container-link')]", $node));
		
		if ($nodeLink != NULL) {
			$link = $nodeLink->getAttribute("href");
			echo "Found link: " . $link . "\n";
			// Only add domain if it's a relative URL
			if (substr($link, 0, 4) != "http") {
				$aNewRecord["infoLink"] = "https://www.proximasociale.cz" . $link;
			} else {
				$aNewRecord["infoLink"] = $link;
			}
		}

		// Try new structure for text (second div with bde-text class, containing p tag)
		$nodeText = firstItem($xpath->query(".//div[contains(@class, 'bde-text')][position()>1]//p", $node));
		
		// Alternative: just get the text content from the div
		if ($nodeText == NULL) {
			$nodeText = firstItem($xpath->query(".//div[contains(@class, 'bde-text')][2]", $node));
		}
		
		if ($nodeText != NULL) {
			$text = trim($nodeText->nodeValue);
			// Remove excessive whitespace
			$text = preg_replace('/\s+/', ' ', $text);
			$aNewRecord["text"] = $text;
			echo "Found text node: " . $text . "\n";
		}

		// Try new structure for illustration (img with bde-image2 class)
		$nodeIllustration = firstItem($xpath->query(".//img[contains(@class, 'bde-image2')]", $node));
		
		if ($nodeIllustration != NULL) {
		  echo "Found illustration node: " . $nodeIllustration->nodeValue . "\n";
		  $linkImg = $nodeIllustration->getAttribute("src");
		  if ($linkImg != "") {
			if (substr($linkImg, 0, 4) != "http") {
			  $linkImg = "https://www.proximasociale.cz" . $linkImg;
			}
			echo "Found illustration link: " . $linkImg . "\n";
			$aNewRecord["illustrationImgLink"] = $linkImg;
		  }
		}

		$aNewRecord["filter"] = "Proxima Sociale";
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
	$filename = "items_spolekProxima.json";
	file_put_contents($filename, $encoded, LOCK_EX);
	chmod($filename, 0644);
	echo $encoded;
}
echo "Proxima done, " . count($arrItems) . " items\n";
?>
