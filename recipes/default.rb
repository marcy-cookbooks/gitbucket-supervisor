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
cmd << " --port #{node['gitbucket']['port']}" if node['gitbucket']['port']
cmd << "--prefix=#{node['gitbucket']['prefix']}" if node['gitbucket']['prefix']
cmd << "--gitbucket.home=#{node['gitbucket']['home']}" if node['gitbucket']['home']

node['gitbucket']['java_opts'].each do |k, v|
  cmd << " #{k} #{v}"
end

supervisor_service 'gitbucket' do
  command cmd
  user node['gitbucket']['user']
  environment node['gitbucket']['environment']
end

directory "/usr/local/src/gitbucket" do
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
  owner "tomcat"
  group "tomcat"
  action :create_if_missing
  notifies :run, "execute[gitbucket-deploy]"
end
