require "aws_backend"

# inspec-aws doesn't cover EKS Pod Identity associations. This looks up the
# association for a namespace/ServiceAccount pair the way eksctl and
# create_lbc_pod_identity_association_awscli() in
# ../../../../install_aws_lbc.sh both do.
class AwsEksPodIdentityAssociation < AwsResourceBase
  name "aws_eks_pod_identity_association"
  desc "Looks up an EKS Pod Identity association for a namespace/ServiceAccount."

  example "
    describe aws_eks_pod_identity_association(cluster_name: 'my-cluster', namespace: 'kube-system', service_account: 'aws-load-balancer-controller') do
      it { should exist }
    end
  "

  attr_reader :association_id, :role_arn

  def initialize(opts = {})
    super(opts)
    validate_parameters(required: [:cluster_name, :namespace, :service_account])

    catch_aws_errors do
      assoc = @aws.eks_client.list_pod_identity_associations(
        cluster_name: opts[:cluster_name],
        namespace: opts[:namespace],
        service_account: opts[:service_account]
      ).associations.first
      next unless assoc

      @association_id = assoc.association_id
      detail = @aws.eks_client.describe_pod_identity_association(
        cluster_name: opts[:cluster_name],
        association_id: assoc.association_id
      ).association
      @role_arn = detail.role_arn
    end
  end

  def exists?
    !@association_id.nil?
  end

  def resource_id
    @association_id || ""
  end

  def to_s
    "EKS Pod Identity Association #{@association_id}"
  end
end
