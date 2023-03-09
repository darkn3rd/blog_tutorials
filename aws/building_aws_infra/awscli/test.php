#!/usr/bin/php -q
<?php
$ep = "USER_NAME_GOES_HERE-db.ctftmipdgbet.ca-central-1.rds.amazonaws.com";
$ep = str_replace(":3306", "", $ep);
$db = "webdb";
$un = "admin";
$pw = "sekret99";

$mysql_command = "mysql -u $un -p$pw -h $ep $db < sql/addressbook.sql";

$connect = mysql_connect($ep, $un, $pw);

if(!$connect) {
  echo "Unable to Establish Connection: " . mysql_error() .  ".";
}

?>