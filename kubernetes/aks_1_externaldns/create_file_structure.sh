mkdir -p \
  ~/azure_externaldns/{terraform,examples/{dgraph,hello}} && \
  cd ~/azure_externaldns

touch \
  env.sh chart-values.{yaml,yaml.shtmpl} helmfile.yaml \
  examples/dgraph/{chart-values.{yaml,yaml.shtmpl},helmfile.yaml} \
  examples/hello/hello_k8s.yaml.shtmpl \
  terraform/{simple_azure_dns.tf,terraform.tfvars}
  
