require "aws_backend"

# inspec-aws doesn't ship an aws_eks_addon resource, so this profile defines
# its own to check for the eks-pod-identity-agent addon (see
# verify_pod_identity_addon() in ../../../../install_aws_lbc.sh).
class AwsEksAddon < AwsResourceBase
  name "aws_eks_addon"
  desc "Verifies an EKS addon is installed on a cluster."

  example "
    describe aws_eks_addon(cluster_name: 'my-cluster', addon_name: 'eks-pod-identity-agent') do
      it { should exist }
    end
  "

  attr_reader :addon_name, :status

  def initialize(opts = {})
    super(opts)
    validate_parameters(required: [:cluster_name, :addon_name])

    @addon_name = opts[:addon_name]
    catch_aws_errors do
      resp = @aws.eks_client.describe_addon(
        cluster_name: opts[:cluster_name],
        addon_name: opts[:addon_name]
      ).addon
      @status = resp.status
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
