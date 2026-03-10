<?php
function firstItem($arrNodes) {
	if ($arrNodes === NULL || $arrNodes === FALSE) return NULL;
	return $arrNodes->item(0);
}

// Helper function to fetch a URL with proper headers and optional caching.
// For regular GET scraping: fetchWebsiteWithHeaders($url, $cacheFile, $cacheMaxAge)
// For POST API calls:       fetchWebsiteWithHeaders($url, $cacheFile, $cacheMaxAge, 'POST', $jsonBody, $apiHeaders)
// $extraHeaders: when provided, replaces the default browser headers entirely.
// $postData:     when provided, sent as the POST body (string).
function fetchWebsiteWithHeaders($url, $cacheFile, $cacheMaxAge = 3600, $method = 'GET', $postData = null, $extraHeaders = array()) {
	$result = null;
	
	// Check if cache file exists and is fresh
	if (file_exists($cacheFile)) {
		$cacheAge = time() - filemtime($cacheFile);
		if ($cacheAge < $cacheMaxAge) {
			echo "Using cached response (age: {$cacheAge}s)\n";
			return file_get_contents($cacheFile);
		} else {
			echo "Cache expired (age: {$cacheAge}s, max: {$cacheMaxAge}s)\n";
		}
	}
	
	echo "Fetching: $url\n";
	
	if (!extension_loaded('curl')) {
		echo "Error: cURL extension not loaded\n";
		return null;
	}
	
	$ch = curl_init();
	curl_setopt($ch, CURLOPT_URL, $url);
	curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
	curl_setopt($ch, CURLOPT_TIMEOUT, 30);
	curl_setopt($ch, CURLOPT_FOLLOWLOCATION, 1);
	curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, 0);
	curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, 0);
	curl_setopt($ch, CURLOPT_MAXREDIRS, 5);
	
	if ($method === 'POST') {
		curl_setopt($ch, CURLOPT_POST, 1);
		if ($postData !== null) {
			curl_setopt($ch, CURLOPT_POSTFIELDS, $postData);
		}
	}
	
	if (!empty($extraHeaders)) {
		// API call: use the provided headers as-is
		curl_setopt($ch, CURLOPT_HTTPHEADER, $extraHeaders);
	} else {
		// Regular scraping: send browser-like headers to avoid 403/429
		curl_setopt($ch, CURLOPT_USERAGENT, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
		curl_setopt($ch, CURLOPT_HTTPHEADER, array(
			'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
			'Accept-Language: cs-CZ,cs;q=0.9,en;q=0.8',
			'Accept-Encoding: gzip, deflate, br',
			'Connection: keep-alive',
			'Upgrade-Insecure-Requests: 1',
			'Cache-Control: max-age=0'
		));
		curl_setopt($ch, CURLOPT_ENCODING, '');
	}
	
	$result = curl_exec($ch);
	$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
	$error = curl_error($ch);
	curl_close($ch);
	
	if ($error) {
		echo "cURL Error: $error\n";
		$result = null;
	} else if ($httpCode !== 200) {
		echo "HTTP Error: $httpCode when fetching $url\n";
		$result = null;
	}
	
	if ($result) {
		file_put_contents($cacheFile, $result, LOCK_EX);
		echo "Fetched and cached\n";
		return $result;
	}
	
	// If fetch failed, fall back to old cache if available
	if (file_exists($cacheFile)) {
		echo "Using stale cache as fallback\n";
		return file_get_contents($cacheFile);
	}
	
	return null;
}

header("Content-type: text/plain; charset=utf-8");
/* Use internal libxml errors -- turn on in production, off for debugging */
libxml_use_internal_errors(true);
?>
