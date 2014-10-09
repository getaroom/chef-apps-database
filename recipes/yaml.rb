#
# Cookbook Name:: apps-database
# Recipe:: yaml
#
# Copyright 2012, getaroom
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#

encrypted_apps = data_bag("apps_encrypted")

search :apps do |base_app|
  encrypted_app = encrypted_apps.include?(base_app['id']) ? Chef::EncryptedDataBagItem.load("apps_encrypted", base_app['id']) : {}
  app = Chef::Mixin::DeepMerge.merge(base_app.to_hash, encrypted_app.to_hash)

  if (app['server_roles'] & node.run_list.roles).any?
    if app.fetch("ingredients", {}).any? { |role, ingredients| node.run_list.roles.include?(role) && ingredients.include?("database.yml") }
      host_cache = {}
      config = {}

      app.fetch("databases", {}).select { |environment, db| environment.include? node['framework_environment'] }.each do |environment, db|
        mysql_master_role = db.fetch("mysql_master_role", app.fetch("mysql_master_role", []))
        roles_clause = mysql_master_role.map { |role| "role:#{role}" }.join(" OR ")

        host = db['host'] || host_cache[roles_clause] ||= begin
          nodes = search(:node, "(#{roles_clause}) AND chef_environment:#{node.chef_environment}")
          nodes << node if (mysql_master_role & node.run_list.roles).any?
          nodes.uniq! # node not indexed on first chef run, except by chef metal

          nodes.sort_by { |node| [node.fetch('mysql', {}).fetch('server', {})['priority'].to_i, node.name] }.reverse.map do |mysql_node|
            mysql_node.attribute?("cloud") ? mysql_node['cloud']['local_ipv4'] : mysql_node['ipaddress']
          end.uniq.first
        end

        slave_in_zone = search(:node, "roles:#{base_app['id']}_mysql_slave AND chef_environment:#{node.chef_environment} AND ec2_placement_availability_zone:#{node['ec2']['placement_availability_zone']}").first
        if slave_in_zone
          slave_address = slave_in_zone.attribute?("cloud") ? slave_in_zone['cloud']['local_ipv4'] : slave_in_zone['ipaddress']
        else
          slave_address = host
        end

        config[environment] = db.to_hash.reject { |key, value| %w(host mysql_master_role).include? key }.merge("host" => host)
        config[environment].merge!("read_slave_host" => slave_address)
      end

      file "#{app['deploy_to']}/shared/config/database.yml" do
        owner app['owner']
        group app['group']
        mode "660"
        content config.to_yaml
      end
    end
  end
end
