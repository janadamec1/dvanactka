<?php
function firstItem($arrNodes) {
	if ($arrNodes === NULL || $arrNodes === FALSE) return NULL;
	return $arrNodes->item(0);
}

header("Content-type: text/plain; charset=utf-8");
/* Use internal libxml errors -- turn on in production, off for debugging */
libxml_use_internal_errors(true);
?>
