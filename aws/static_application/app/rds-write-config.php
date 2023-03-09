<!DOCTYPE html>
<html>
<head>
  <title>Amazon Web Services</title>
  <meta http-equiv="refresh" content="2,URL=/index.php" />
  <link href="css/bootstrap.min.css" rel="stylesheet">
  <link href="css/style.css" rel="stylesheet">
</head>

  <body>
    <div class="container">

      <div class="row">
      <div class="col-md-12">
      <?php include('menu.php'); ?>

      <div class="jumbotron">

      <?php
        $ep = $_POST['endpoint'];
      	$ep = str_replace(":3306", "", $ep);
      	$db = $_POST['database'];
        $un = $_POST['username'];
        $pw = $_POST['password'];

        $mysql_command = "mysql -u $un -p$pw -h $ep $db < sql/addressbook.sql";

        $connect = mysql_connect($ep, $un, $pw);
        if(!$connect) {

          echo "<br /><p>Unable to Establish Connection:<i>" . mysql_error() .  "</i></p>";

        } else {

          $dbconnect = mysql_select_db($db);
          if(!$dbconnect) {

            echo "<br /><p>Unable to Connect to DB:<i>" . mysql_error() .  "</i></p>";

          } else {

            echo "<br /><p>Executing Command: $mysql_command</p>";
            echo exec($mysql_command);

            echo "<br /><p>Writing config out to rds.conf.php </p>";

            $rds_conf_file = 'rds.conf.php';
            $handle = fopen($rds_conf_file, 'w') or die('Cannot open file:  '.$rds_conf_file);
            $data = "<?php \$RDS_URL='" . $ep . "'; \$RDS_DB='" . $db . "'; \$RDS_user='" . $un . "'; \$RDS_pwd='" . $pw . "'; ?>";
            fwrite($handle, $data);
            fclose($handle);
          }

        }
        mysql_close($connect);

        echo "<br /><br /><p><i>Redirecting to index.php in 2 seconds (or click <a href=index.php>here</a>)</i></p>";


      ?>

    </div>
    </div>
  </div>
  </div>

    <script src="js/jquery.min.js"></script>
    <script src="js/bootstrap.min.js"></script>
    <script src="js/scripts.js"></script>
  </body>
</html>
