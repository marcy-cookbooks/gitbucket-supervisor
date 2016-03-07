#
# Cookbook Name:: gitbucket-supervisor
# Recipe:: default
#
# Copyright (c) 2016 The Authors, All Rights Reserved.

include_recipe 'java'
include_recipe 'supervisor'

user node['gitbucket']['user'] do
  home "/home/#{node['gitbucket']['user']}"
end

group node['gitbucket']['group'] do
  members [node['gitbucket']['group']]
end

cmd = "/usr/bin/java -jar /usr/local/gitbucket.war"
cmd << " --port #{node['gitbucket']['port']}" unless node['gitbucket']['port'].nil?
cmd << " --prefix=#{node['gitbucket']['prefix']}" unless node['gitbucket']['prefix'].nil?
cmd << " --host=#{node['gitbucket']['host']}" unless node['gitbucket']['host'].nil?
cmd << " --gitbucket.home=#{node['gitbucket']['home']}" unless node['gitbucket']['home'].nil?

node['gitbucket']['java_opts'].each do |k, v|
  cmd << " #{k} #{v}"
end

supervisor_service 'gitbucket' do
  command cmd
  user node['gitbucket']['user']
  environment node['gitbucket']['environment']
end

directory "/usr/local/src/gitbucket" do
  owner node['gitbucket']['user']
  group node['gitbucket']['group']
  action :create
end

execute "gitbucket-deploy" do
  command <<-EOH
  cp -p /usr/local/src/gitbucket/gitbucket.#{node['gitbucket']['version']}.war /usr/local/gitbucket.war
  EOH
  action :nothing
  notifies :restart, "supervisor_service[gitbucket]"
end

remote_file "/usr/local/src/gitbucket/gitbucket.#{node['gitbucket']['version']}.war" do
  source "https://github.com/takezoe/gitbucket/releases/download/#{node['gitbucket']['version']}/gitbucket.war"
  owner node['gitbucket']['user']
  group node['gitbucket']['group']
  action :create_if_missing
  notifies :run, "execute[gitbucket-deploy]"
end

schema = node['gitbucket']['ssl'] ? 'https' : 'http'

host = node['gitbucket']['host']
if host.nil?
  if node.has_key?('ec2')
    host = node['ec2']['public_ipv4']
  else
    host = node['ipaddress']
  end
end
base_url = "#{schema}://#{host}#{node['gitbucket']['prefix']}"
conf_dir = node['gitbucket']['home'].nil? ? "/home/#{node['gitbucket']['user']}/.gitbucket" : node['gitbucket']['home']

directory conf_dir do
  owner node['gitbucket']['user']
  group node['gitbucket']['group']
  action :create_if_missing
end

file "#{conf_dir}/gitbucket.conf" do
  owner node['gitbucket']['user']
  group node['gitbucket']['group']
  notifies :restart, "supervisor_service[gitbucket]"
  action :create_if_missing
  content <<-EOF
base_url=#{base_url}
EOF
end
