node "node01.local" {
  class { 'hello_web': }
}

node "node02.local" {
  class { 'hello_web': }
}
