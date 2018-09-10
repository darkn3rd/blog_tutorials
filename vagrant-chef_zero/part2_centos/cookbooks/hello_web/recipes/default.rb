apt_update 'Update the apt cache daily' do
  frequency 86_400
  action :periodic
end

package node['hello_web']['package']

cookbook_file "#{node['hello_web']['docroot']}/index.html" do
  source 'index.html'
  action :create
end

service node['hello_web']['service'] do
  supports status: true, restart: true, reload: true
  action %i(enable start)
end
