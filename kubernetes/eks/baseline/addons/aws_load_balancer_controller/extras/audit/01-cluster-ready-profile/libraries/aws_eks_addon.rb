require "aws-sdk-eks"

# inspec-aws doesn't ship an aws_eks_addon resource, so this profile defines
# its own to check for the eks-pod-identity-agent addon (see
# verify_pod_identity_addon() in ../../../../install_aws_lbc.sh).
#
# This is NOT built on inspec-aws's AwsResourceBase: each profile/dependency
# gets its own require-loader AND its own library eval context, and Ruby
# scopes classes defined via instance_eval to that context's singleton
# class. So AwsResourceBase, defined inside inspec-aws's own eval context,
# is genuinely unreachable here (raises NameError, not just a require
# problem) -- confirmed by running this against a live target. Inspec.resource(1)
# is a real gem-level constant, not profile-scoped, so it's safe to use
# directly, along with the aws-sdk-eks gem inspec-aws already depends on.
class AwsEksAddon < Inspec.resource(1)
  name "aws_eks_addon"
  desc "Verifies an EKS addon is installed on a cluster."

  example "
    describe aws_eks_addon(cluster_name: 'my-cluster', addon_name: 'eks-pod-identity-agent') do
      it { should exist }
    end
  "

  attr_reader :addon_name, :status

  def initialize(opts = {})
    @addon_name = opts.fetch(:addon_name)
    cluster_name = opts.fetch(:cluster_name)

    begin
      resp = Aws::EKS::Client.new.describe_addon(
        cluster_name: cluster_name,
        addon_name: @addon_name
      ).addon
      @status = resp.status
    rescue Aws::EKS::Errors::ResourceNotFoundException
      @status = nil
    rescue Aws::Errors::ServiceError => e
      Inspec::Log.warn "aws_eks_addon: #{e.message}"
      @status = nil
    end
  end

  def exists?
    !@status.nil?
  end

  def resource_id
    @addon_name
  end

  def to_s
    "EKS Addon #{@addon_name}"
  end
end
