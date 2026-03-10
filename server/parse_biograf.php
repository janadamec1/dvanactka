<?php
include_once "parse_common.php";
include_once "api_keys.php";

$sAddress = "Modřanský biograf\nU Kina 1\n143 00 Praha 12 - Modřany";

$arrItems = array();

// Call the Entradio GraphQL API
$today = new DateTime();
$query = json_encode([
	'query' => 'query ExampleQuery($filter: EventsFilter) { events(filter: $filter) { items { startsAt endsAt ecommerceEventURL names { cs } id showId show { genresTranslated { cs } } } } }',
	'variables' => [
		'filter' => [
			'fromStartsAt' => $today->format('Y-m-d\TH:i:s.000\Z'),
			'showOnWebsiteAndApi' => true
		]
	]
]);

$apiHeaders = array(
	'Content-Type: application/json',
	'Authorization: Bearer ' . BIOGRAF_KEY
);

$response = fetchWebsiteWithHeaders(
	'https://api.entradio.cz/graphql',
	'cache_biograf.json',
	3600,
	'POST',
	$query,
	$apiHeaders
);

if (!$response) {
	echo "Error: Could not load API\n";
	exit(1);
}

$data = json_decode($response, true);
$events = $data['data']['events']['items'] ?? [];

foreach ($events as $event) {
	// Extract movie name from names.cs
	$title = $event['names']['cs'] ?? null;
	if (!$title) continue;

	// Extract infoLink from event id
	$infoLink = isset($event['showId']) ? 'https://www.modranskybiograf.cz/akce/' . $event['showId'] : null;

	// Extract ticket link
	$buyLink = $event['ecommerceEventURL'] ?? null;

	// Parse startsAt: "2026-02-27T19:00:00.000Z"
	$startsAt = $event['startsAt'] ?? null;
	if (!$startsAt) continue;

	$date = DateTime::createFromFormat('Y-m-d\TH:i:s.v\Z', $startsAt, new DateTimeZone('UTC'));
	if ($date === false) {
		$date = DateTime::createFromFormat('Y-m-d\TH:i:s\Z', $startsAt, new DateTimeZone('UTC'));
	}
	if ($date === false) continue;
	$date->setTimezone(new DateTimeZone('Europe/Prague'));

	// Extract and concatenate genres from show.genresTranslated
	$genres = array();
	if (isset($event['show']['genresTranslated']) && is_array($event['show']['genresTranslated'])) {
		foreach ($event['show']['genresTranslated'] as $genre) {
			if (isset($genre['cs'])) {
				$genres[] = $genre['cs'];
			}
		}
	}
	$showInfo = !empty($genres) ? implode(', ', $genres) : null;

	$aNewRecord = array('title' => $title);
	$aNewRecord['infoLink'] = $infoLink;
	$aNewRecord['address'] = $sAddress;
	$aNewRecord['date'] = $date->format('Y-m-d\TH:i');
	if ($buyLink) {
		$aNewRecord['buyLink'] = $buyLink;
	}
	if ($showInfo) {
		$aNewRecord["text"] = $showInfo;
	}
	array_push($arrItems, $aNewRecord);
}

if (count($arrItems) > 0) {
	$arr = array("items" => $arrItems);
	$encoded = json_encode($arr, JSON_UNESCAPED_UNICODE);
	$filename = "dyn_biograf.json";
	file_put_contents($filename, $encoded, LOCK_EX);
	chmod($filename, 0644);
	echo $encoded;
}
echo "Biograf done, " . count($arrItems) . " items\n";
?>
