<?php
header("Content-type: text/plain; charset=utf-8");
echo "{\"items\":[\n";
include "items_radEvents.json";
include "items_P12app_calendar.json";
include "items_ddmMonetEvents.json";
echo "\n]}";
?>
