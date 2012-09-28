#
# Cookbook Name:: apps-database
# Recipe:: master
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

  app.fetch("databases", {}).each_pair do |environment, db|
    if environment.include?(node['framework_environment'])
      if db.fetch("adapter", "").include?("mysql") && (app.fetch("mysql_master_role", []) & node.run_list.roles).any?
        connection_details = {
          :host => "localhost",
          :username => "root",
          :password => node['mysql']['server_root_password'],
        }

        mysql_database db['database'] do
          connection connection_details
        end

        ["%", "localhost", node['fqdn']].each do |mysql_host|
          mysql_database_user db['username'] do
            connection connection_details
            password db['password']
            host mysql_host
            database_name db['database']
            action :grant
          end
        end
      end
    end
  end
end
