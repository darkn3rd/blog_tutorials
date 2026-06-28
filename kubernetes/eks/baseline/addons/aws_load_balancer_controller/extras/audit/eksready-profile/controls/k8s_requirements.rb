control "k8s-namespace-check" do
  title "Audit Kubernetes Cluster Core namespaces"
  desc "Ensures the essential default namespace is structurally present inside the API pool."
  impact 1.0

  describe k8s_namespaces do
    its('names') { should include 'default' }
  end
end
