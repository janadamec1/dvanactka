<?php

function firstItem($arrNodes) {
	if ($arrNodes === NULL || $arrNodes === FALSE) return NULL;
	return $arrNodes->item(0);
}

/* Set HTTP response header to plain text for debugging output */
header("Content-type: text/plain; charset=utf-8");
/* Use internal libxml errors -- turn on in production, off for debugging */
libxml_use_internal_errors(true);

$query = "https://www.kdejeprace.cz/api/search?fulltext=&max-vzdalenost=3&jazyky-omez=0&jazyky=cs.2&zmeneno-po=&zmeneno-po-cas=&zs=49.99041501874329&zd=14.43557783961296&key=qNO79NkpBr&limit=50";

$arrItems = array();

// TODO: for each page
$bDoNextPage = true;
$page = 0;
while ($bDoNextPage) {
	$bDoNextPage = false;
	$encoded = file_get_contents($query."&str=".$page);
	$json = json_decode($encoded, true);
	
	if ($json === FALSE || $json === NULL || !array_key_exists("offers", $json)) 
		break;
	
	$jsonItems = $json["offers"];
	foreach ($jsonItems as $i => $item) {
		if (array_key_exists("title", $item)) {
			$title = $item["title"];
			$aNewRecord = array("title" => $title);
			
			$text = "";
			if (array_key_exists("detailURI", $item))
				$aNewRecord["infoLink"] = $item["detailURI"];
			if (array_key_exists("firm", $item))
				$text .= $item["firm"];
			if (array_key_exists("preview", $item)) {
				if (strlen($text) > 0) $text .= "\n";
				$sPreview = $item["preview"];
				$text .= str_replace(": Místo výkonu", "\nMísto výkonu", $sPreview);
			}
			if (array_key_exists("location", $item)) {
				$location = $item["location"];
				if (array_key_exists("lat", $location) && array_key_exists("lon", $location)) {
					$aNewRecord["locationLat"] = number_format($location["lat"], 8, '.', '');
					$aNewRecord["locationLong"] = number_format($location["lon"], 8, '.', '');
				}
			}

			if (strlen($text) > 0) $text .= "...\n\n";
			$text .= "zdroj: KdeJePrace.cz";
			$aNewRecord["text"] = $text;
			array_push($arrItems, $aNewRecord);
		}
	}
	if (count($jsonItems) == 50) {
		$page += 1;
		$bDoNextPage = true;
	}
}


if (count($arrItems) > 0) {
	$arr = array("items" => $arrItems);
	$encoded = json_encode($arr, JSON_UNESCAPED_UNICODE);
	$filename = "dyn_kdejeprace.json";
	file_put_contents($filename, $encoded, LOCK_EX);
	chmod($filename, 0644);
	echo $encoded;
}
echo "done, " . count($arrItems) . " items";
?>
