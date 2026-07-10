# inspec-k8s has no dedicated CRD resource, and its generic k8sobject can't
# reach cluster-scoped resources at all: it hardcodes `opts[:namespace] ||=
# 'default'`, and k8s-ruby's ResourceClient raises "is not namespaced" the
# moment a non-namespaced resource (like CustomResourceDefinition) is
# queried with any namespace set. So this queries the k8s-ruby client
# directly instead of going through k8sobject.
class K8sCustomResourceDefinition < Inspec.resource(1)
  name "k8s_custom_resource_definition"
  desc "Verifies a Kubernetes CustomResourceDefinition exists."

  example "
    describe k8s_custom_resource_definition(name: 'gateways.gateway.networking.k8s.io') do
      it { should exist }
      its('group') { should cmp 'gateway.networking.k8s.io' }
    end
  "

  def initialize(opts = {})
    @crd_name = opts.fetch(:name)

    begin
      @crd = inspec.backend.client.api("apiextensions.k8s.io/v1")
        .resource("customresourcedefinitions")
        .get(@crd_name)
    rescue ::K8s::Error::NotFound
      @crd = nil
    end
  end

  def exists?
    !@crd.nil?
  end

  def group
    @crd&.spec&.group
  end

  def resource_id
    @crd_name
  end

  def to_s
    "Kubernetes CustomResourceDefinition #{@crd_name}"
  end
end
