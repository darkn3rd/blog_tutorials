# Hello Web Example (chef_zero)

This is a basic example that demonstrates how to use an internal Cookbook and Vagrant with the Chef Zero, and in-memory Chef Server.

Releated Article:
  * [Cooking with Chef on Vagrant](https://medium.com/@joachim8675309/cooking-with-chef-on-vagrant-fd5264569448)

## Directory Structure

You can create a similar directory structure with the following commands:

```bash
PROJ_HOME=.

# craete directory structure
mkdir -p \
  $PROJ_HOME/cookbooks/hello_web/{attributes,files/default,recipes} \
  $PROJ_HOME/{ubuntu2204,rocky9}/nodes

cd $PROJ_HOME

touch \
 ./cookbooks/hello_web/{attributes,recipes}/default.rb \
 ./cookbooks/hello_web/files/default/index.html \
 ./{ubuntu2204,rocky9}/Vagrantfile
```

This will create the following directory structure in `$PROJ_HOME`:

```
.
├── README.md
├── cookbooks
│   └── hello_web
│       ├── attributes
│       │   └── default.rb
│       ├── files
│       │   └── default
│       │       └── index.html
│       └── recipes
│           └── default.rb
├── rocky9
│   ├── Vagrantfile
│   └── nodes
└── ubuntu2204
    ├── Vagrantfile
    └── nodes
```

