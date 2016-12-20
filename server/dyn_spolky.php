<?php
header("Content-type: text/plain; charset=utf-8");
echo "{\"items\":[\n";
include "items_spolekProxima.json";
include "items_spolekKomo.json";
echo "\n]}";
?>
