require "aws-sdk-eks"

# inspec-aws doesn't cover EKS Pod Identity associations. This looks up the
# association for a namespace/ServiceAccount pair the way eksctl and
# create_lbc_pod_identity_association_awscli() in
# ../../../../install_aws_lbc.sh both do.
#
# This is NOT built on inspec-aws's AwsResourceBase: each profile/dependency
# gets its own require-loader AND its own library eval context, and Ruby
# scopes classes defined via instance_eval to that context's singleton
# class. So AwsResourceBase, defined inside inspec-aws's own eval context,
# is genuinely unreachable here (raises NameError, not just a require
# problem) -- confirmed by running this against a live target. Inspec.resource(1)
# is a real gem-level constant, not profile-scoped, so it's safe to use
# directly, along with the aws-sdk-eks gem inspec-aws already depends on.
class AwsEksPodIdentityAssociation < Inspec.resource(1)
  name "aws_eks_pod_identity_association"
  desc "Looks up an EKS Pod Identity association for a namespace/ServiceAccount."

  example "
    describe aws_eks_pod_identity_association(cluster_name: 'my-cluster', namespace: 'kube-system', service_account: 'aws-load-balancer-controller') do
      it { should exist }
    end
  "

  attr_reader :association_id, :role_arn

  def initialize(opts = {})
    cluster_name = opts.fetch(:cluster_name)
    namespace = opts.fetch(:namespace)
    service_account = opts.fetch(:service_account)

    client = Aws::EKS::Client.new
    begin
      assoc = client.list_pod_identity_associations(
        cluster_name: cluster_name,
        namespace: namespace,
        service_account: service_account
      ).associations.first

      if assoc
        @association_id = assoc.association_id
        detail = client.describe_pod_identity_association(
          cluster_name: cluster_name,
          association_id: assoc.association_id
        ).association
        @role_arn = detail.role_arn
      end
    rescue Aws::Errors::ServiceError => e
      Inspec::Log.warn "aws_eks_pod_identity_association: #{e.message}"
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
