control "aws-cluster-version-check" do
  title "Audit AWS EKS Cluster Configuration"
  desc "Validates that the target modcluster is operating on an acceptable orchestration engine version."
  impact 1.0

  describe aws_eks_cluster(cluster_name: 'modcluster') do
    its('version') { should cmp >= '1.35' }
  end
end