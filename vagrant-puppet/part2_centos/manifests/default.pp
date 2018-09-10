node default {
  class { 'hello_web':
    package_name => 'httpd',
    service_name => 'httpd',
    doc_root => '/var/www/html',
  }
}
