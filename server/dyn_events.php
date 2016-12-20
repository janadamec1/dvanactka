<?php
header("Content-type: text/plain; charset=utf-8");
echo "{\"items\":[\n";
include "items_radEvents.json";
echo "\n]}";
?>
