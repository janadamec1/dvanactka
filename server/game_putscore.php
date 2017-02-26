<?php
header("Content-type: text/plain; charset=utf-8");

$sId = $_GET["id"];
$sScore = $_GET["s"];
$sCrc = $_GET["c"];

if ($sId === NULL || $sId === FALSE || strlen($sId) == 0) exit;
if ($sScore === NULL || $sScore === FALSE || strlen($sScore) == 0) exit;
if ($sCrc === NULL || $sCrc === FALSE || strlen($sCrc) == 0) exit;

// verify crc
$nCalcCrc = 0;
$nIdLen = strlen($sId);
for ($i = 0; $i < $nIdLen; $i++)
	$nCalcCrc += ord($sId[$i]);
$nScoreLen = strlen($sScore);
for ($i = 0; $i < $nScoreLen; $i++)
	$nCalcCrc += ord($sScore[$i]);
//echo $nCrc . "\n";
if ($nCalcCrc != $sCrc) {
	echo "CRC failed";
	exit;
}

$sDate = date_format(new DateTime, "Y-m-d");
$sNewLine = $sId . "|" . $sScore . "|" . $sDate . "\n";

$filename = "game_leaders.txt";

$handle = fopen($filename, "r+");
if (!$handle) {
	// create new file with this  
	file_put_contents($filename, $sNewLine, LOCK_EX);
	chmod($filename, 0644);
	exit;
}

flock($handle, LOCK_EX);	// blocks until the lock is obtained
$bUserIdFound = FALSE;
$sOutput = $sNewLine;
while (($sLine = fgets($handle)) !== false) {
	if (!$bUserIdFound) {
		$arrItems = explode("|", $sLine);
		if (count($arrItems) > 2 && $arrItems[0] === $sId)
		{
			$bUserIdFound = TRUE;
			continue;
		}
	}
	$sOutput .= $sLine;
}
fseek($handle, 0, SEEK_SET);
ftruncate($handle, strlen($sOutput));
fwrite($handle, $sOutput);
fclose($handle);

echo $sOutput;
?>