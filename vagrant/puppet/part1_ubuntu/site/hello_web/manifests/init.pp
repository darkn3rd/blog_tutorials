class hello_web (
  $package_name = 'apache2',
  $service_name = 'apache2',
  $doc_root = '/var/www/html'
) {

  package { $package_name:
    ensure => present,
  }

  service { $service_name:
    ensure => running,
    enable => true,
  }

  file { "$doc_root/index.html":
    source => "puppet:///modules/hello_web/index.html",
  }
}
