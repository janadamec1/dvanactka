<?php
function firstItem($arrNodes) {
	if ($arrNodes === NULL || $arrNodes === FALSE) return NULL;
	return $arrNodes->item(0);
}

// Helper function to fetch website with proper headers
function fetchWebsiteWithHeaders($url, $cacheFile, $cacheMaxAge = 3600) {
	$html = null;
	
	// Check if cache file exists and is fresh
	if (file_exists($cacheFile)) {
		$cacheAge = time() - filemtime($cacheFile);
		if ($cacheAge < $cacheMaxAge) {
			echo "Using cached HTML (age: {$cacheAge}s)\n";
			$html = file_get_contents($cacheFile);
			return $html;
		} else {
			echo "Cache expired (age: {$cacheAge}s, max: {$cacheMaxAge}s)\n";
		}
	}
	
	// Try to fetch fresh content
	echo "Attempting to fetch fresh HTML from website...\n";
	
	// Try cURL first (better for avoiding 403)
	if (extension_loaded('curl')) {
		$ch = curl_init();
		curl_setopt($ch, CURLOPT_URL, $url);
		curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
		curl_setopt($ch, CURLOPT_TIMEOUT, 30);
		curl_setopt($ch, CURLOPT_FOLLOWLOCATION, 1);
		curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, 0);
		curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, 0);
		curl_setopt($ch, CURLOPT_MAXREDIRS, 5);
		
		// Add User-Agent and headers to appear as a real browser
		curl_setopt($ch, CURLOPT_USERAGENT, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
		
		$headers = array(
			'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
			'Accept-Language: cs-CZ,cs;q=0.9,en;q=0.8',
			'Accept-Encoding: gzip, deflate, br',
			'Connection: keep-alive',
			'Upgrade-Insecure-Requests: 1',
			'Cache-Control: max-age=0'
		);
		curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
		curl_setopt($ch, CURLOPT_ENCODING, ''); // Enable automatic decompression
		
		$html = curl_exec($ch);
		$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
		$error = curl_error($ch);
		curl_close($ch);
		
		if ($error) {
			echo "cURL Error: $error\n";
		} else if ($httpCode !== 200) {
			echo "HTTP Error: $httpCode when fetching $url\n";
		} else if ($html) {
			// Save to cache
			file_put_contents($cacheFile, $html, LOCK_EX);
			echo "Fetched fresh content and cached it\n";
			return $html;
		}
	}
	
	// Fallback to file_get_contents with context
	if (!$html) {
		$context = stream_context_create([
			'http' => [
				'method' => 'GET',
				'header' => "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36\r\n" .
						   "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8\r\n" .
						   "Accept-Language: cs-CZ,cs;q=0.9\r\n",
				'timeout' => 30
			],
			'ssl' => [
				'verify_peer' => false,
				'verify_peer_name' => false,
			]
		]);
		$html = @file_get_contents($url, false, $context);
		
		if ($html) {
			file_put_contents($cacheFile, $html, LOCK_EX);
			echo "Fetched fresh content and cached it\n";
			return $html;
		}
	}
	
	// If all fails, check if we have old cache
	if (!$html && file_exists($cacheFile)) {
		echo "Using old cache as fallback\n";
		$html = file_get_contents($cacheFile);
	}
	
	return $html;
}

header("Content-type: text/plain; charset=utf-8");
/* Use internal libxml errors -- turn on in production, off for debugging */
libxml_use_internal_errors(true);
?>
