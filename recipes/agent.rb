#
# Cookbook Name:: logstash
# Recipe:: agent
#
#
include_recipe "logstash::default"

# check if running chef-solo
if Chef::Config[:solo]
  logstash_server_ip = node['logstash']['agent']['server_ipaddress']
else
  logstash_server_results = search(:node, "role:#{node['logstash']['agent']['server_role']} AND chef_environment:#{node.chef_environment}")
  unless logstash_server_results.empty?
    logstash_server_ip = logstash_server_results[0]['ipaddress']
  end
end
  
directory "#{node['logstash']['basedir']}/agent" do
  action :create
  mode "0755"
  owner node['logstash']['user']
  group node['logstash']['group']
end

%w{bin etc lib tmp log}.each do |ldir|
  directory "#{node['logstash']['basedir']}/agent/#{ldir}" do
    action :create
    mode "0755"
    owner node['logstash']['user']
    group node['logstash']['group']
  end

  link "/var/lib/logstash/#{ldir}" do
    to "#{node['logstash']['basedir']}/agent/#{ldir}"
  end
end

directory "#{node['logstash']['basedir']}/agent/etc/conf.d" do
  action :create
  mode "0755"
  owner node['logstash']['user']
  group node['logstash']['group']
end

directory "#{node['logstash']['basedir']}/agent/etc/patterns" do
  action :create
  mode "0755"
  owner node['logstash']['user']
  group node['logstash']['group']
end

if node['logstash']['agent']['install_method'] == "jar"
  remote_file "#{node['logstash']['basedir']}/agent/lib/logstash-#{node['logstash']['agent']['version']}.jar" do
    owner "root"
    group "root"
    mode "0755"
    source node['logstash']['agent']['source_url']
    checksum  node['logstash']['agent']['checksum']
  end
  link "#{node['logstash']['basedir']}/agent/lib/logstash.jar" do
    to "#{node['logstash']['basedir']}/agent/lib/logstash-#{node['logstash']['agent']['version']}.jar"
    notifies :restart, "service[logstash_agent]"
  end
else
  include_recipe "logstash::source"

  link "#{node['logstash']['basedir']}/agent/lib/logstash.jar" do
    to "#{node['logstash']['basedir']}/source/build/logstash-#{node['logstash']['source']['sha']}-monolithic.jar"
    notifies :restart, "service[logstash_agent]"
  end
end

template "#{node['logstash']['basedir']}/agent/etc/logstash.conf" do
  source node['logstash']['agent']['base_config']
  owner node['logstash']['user']
  group node['logstash']['group']
  mode "0644"
  variables(:logstash_server_ip => logstash_server_ip)
  notifies :restart, "service[logstash_agent]"
end

runit_service "logstash_agent"
