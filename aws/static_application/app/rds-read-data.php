<h2>Address Book</h2><p>
<?php
  //This is a simple address book example for testing with RDS

  include('rds.conf.php');

  // Set address book variables
  isset($_REQUEST['mode']) ? $mode=$_REQUEST['mode'] : $mode="";
  isset($_REQUEST['id']) ? $id=$_REQUEST['id'] : $id="";
  isset($_REQUEST['lastname']) ? $lastname=$_REQUEST['lastname'] : $lastname="";
  isset($_REQUEST['firstname']) ? $firstname=$_REQUEST['firstname'] : $firstname="";
  isset($_REQUEST['phone']) ? $phone=$_REQUEST['phone'] : $phone="";
  isset($_REQUEST['email']) ? $email=$_REQUEST['email'] : $email="";

  // Connect to the RDS database
  mysql_connect($RDS_URL, $RDS_user, $RDS_pwd) or die(mysql_error());

  mysql_select_db($RDS_DB) or die(mysql_error());

if ( $mode=="add")
 {
 Print '<h2>Add Contact</h2>
 <p>
 <form action=';
 echo $_SERVER['PHP_SELF'];
 Print '
 method=post>
 <table>
 <tr><td>Last Name:</td><td><input type="text" name="lastname" /></td></tr>
 <tr><td>First Name:</td><td><input type="text" name="firstname" /></td></tr>
 <tr><td>Phone:</td><td><input type="text" name="phone" /></td></tr>
 <tr><td>Email:</td><td><input type="text" name="email" /></td></tr>
 <tr><td colspan="2" align="center"><input type="submit" /></td></tr>
 <input type=hidden name=mode value=added>
 </table>
 </form> <p>';
 }

 if ( $mode=="added")
 {
 mysql_query ("INSERT INTO address (lastname, firstname, phone, email) VALUES ('$lastname', '$firstname', '$phone', '$email')");
 }

if ( $mode=="edit")
 {
 Print '<h2>Edit Contact</h2>
 <p>
 <form action=';
 echo $_SERVER['PHP_SELF'];
 Print '
 method=post>
 <table>
 <tr><td>Last name:</td><td><input type="text" value="';
 Print $lastname;
 print '" name="lastname" /></td></tr>
 <tr><td>First name:</td><td><input type="text" value="';
 Print $firstname;
 print '" name="firstname" /></td></tr>
 <tr><td>Phone:</td><td><input type="text" value="';
 Print $phone;
 print '" name="phone" /></td></tr>
 <tr><td>Email:</td><td><input type="text" value="';
 Print $email;
 print '" name="email" /></td></tr>
 <tr><td colspan="3" align="center"><input type="submit" /></td></tr>
 <input type=hidden name=mode value=edited>
 <input type=hidden name=id value=';
 Print $id;
 print '>
 </table>
 </form> <p>';
 }

 if ( $mode=="edited")
 {
 mysql_query ("UPDATE address SET lastname = '$lastname', firstname = '$firstname', phone = '$phone', email = '$email' WHERE id = $id");
 Print "Data Updated!<p>";
 }

if ( $mode=="remove")
 {
 mysql_query ("DELETE FROM address where id=$id");
 Print "Entry has been removed <p>";
 }

 $data = mysql_query("SELECT * FROM address ORDER BY lastname ASC")
 or die(mysql_error());
 Print "<table border cellpadding=3>";
 Print "<tr><th width=100>Last name</th> " .
   "<th width=100>First name</th> " .
   "<th width=100>Phone</th> " .
   "<th width=200>Email</th> " .
   "<th width=100 colspan=3>Admin</th></tr>";
 Print "<td colspan=6 align=right> " .
   "<a href=" .$_SERVER['PHP_SELF']. "?mode=add>Add Contact</a></td>";
 while($info = mysql_fetch_array( $data ))
 {
 Print "<tr><td>".$info['lastname'] . "</td> ";
 Print "<td>".$info['firstname'] . "</td> ";
 Print "<td>".$info['phone'] . "</td> ";
 Print "<td> <a href=mailto:".$info['email'] . ">" .$info['email'] . "</a></td>";
 Print "<td><a href=" .$_SERVER['PHP_SELF']. "?id=" . $info['id'] ."&lastname=" . $info['lastname'] . "&firstname=" . $info['firstname'] . "&phone=" . $info['phone'] ."&email=" . $info['email'] . "&mode=edit>Edit</a></td>";
 Print "<td><a href=" .$_SERVER['PHP_SELF']. "?id=" . $info['id'] ."&mode=remove>Remove</a></td></tr>";
 }
 Print "</table>";
?>
