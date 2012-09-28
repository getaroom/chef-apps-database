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

search :apps do |base_app|
  encrypted_app = Chef::EncryptedDataBagItem.load("apps_encrypted", base_app['id']) rescue {}
  app = Chef::Mixin::DeepMerge.merge(base_app.to_hash, encrypted_app.to_hash)

  if (app['server_roles'] & node.run_list.roles).any?
    if app.fetch("ingredients", {}).any? { |role, ingredients| node.run_list.roles.include?(role) && ingredients.include?("database.yml") }
      roles_clause = app['mysql_master_role'].map { |role| "role:#{role}" }.join(" OR ")

      nodes = search(:node, "(#{roles_clause}) AND chef_environment:#{node.chef_environment}")
      nodes << node if (app['mysql_master_role'] & node.run_list.roles).any? # node not indexed on first chef run

      host = nodes.sort_by { |node| node.name }.reverse.map do |mysql_node|
        mysql_node.attribute?("cloud") ? mysql_node['cloud']['local_ipv4'] : mysql_node['ipaddress']
      end.uniq.first

      template "#{app['deploy_to']}/shared/config/database.yml" do
        owner app['owner']
        group app['group']
        mode "660"
        variables({
          :databases => app.fetch("databases", {}).select { |environment, db| environment.include? node['framework_environment'] },
          :host => host,
        })
      end
    end
  end
end
