<form name="input" action="rds-write-config.php" method="post" class="form-horizontal">
  <div class="form-group">
    <label for="endpoint" class="col-sm-2 control-label">Endpoint</label>
    <div class="col-sm-10">
      <input type="text" class="form-control" name="endpoint">
    </div>
  </div>

  <div class="form-group">
    <label for="database" class="col-sm-2 control-label">Database</label>
    <div class="col-sm-10">
      <input type="text" class="form-control" name="database">
    </div>
  </div>

  <div class="form-group">
    <label for="username" class="col-sm-2 control-label">Username</label>
    <div class="col-sm-10">
      <input type="text" class="form-control" name="username">
    </div>
  </div>

  <div class="form-group">
    <label for="password" class="col-sm-2 control-label">Password</label>
    <div class="col-sm-10">
      <input type="password" class="form-control" name="password">
    </div>
  </div>

  <div class="form-group">
    <div class="col-sm-offset-2 col-sm-10">
      <input type="submit" value="Submit" class="btn btn-default"/>
    </div>
  </div>
</form>
