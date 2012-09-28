describe_recipe "apps-database::master" do
  include MiniTest::Chef::Assertions
  include MiniTest::Chef::Context
  include MiniTest::Chef::Resources

  MiniTest::Chef::Resources.register_resource :mysql_database, :connection

  describe "production mysql server" do
    def mysql_database(database_name)
      resource = Chef::Resource::MysqlDatabase.new(database_name)
      root_password = node['mysql']['server_root_password']
      resource.connection({ :host => "localhost", :username => "root", :password => root_password })
      provider = Chef::Provider::Database::Mysql.new(resource, nil).tap(&:load_current_resource)
      yield provider
    ensure
      provider.send(:close)
    end

    def mysql_database_exists?(database_name)
      mysql_database(database_name) { |db| db.send(:exists?) }
    end

    def mysql_user_exists?(username, host)
      resource = Chef::Resource::MysqlDatabaseUser.new(username)
      root_password = node['mysql']['server_root_password']
      resource.connection({ :host => "localhost", :username => "root", :password => root_password })
      resource.host host
      provider = Chef::Provider::Database::MysqlUser.new(resource, nil)
      provider.tap(&:load_current_resource).send(:exists?)
    ensure
      provider.send(:close)
    end

    def assert_mysql_granted_all?(username, host, database_name)
      mysql_database(database_name) do |provider|
        row = provider.send(:db).query("select * from mysql.db where User = '#{username}' and Host = '#{host}' and Db = '#{database_name}'").fetch_hash
        assert row, "#{username}@#{host} has not been granted any privileges for #{database_name}"
        missing_priv = row.reject { |field, value| !field.include?("_priv") || field == "Grant_priv" || value == "Y" }
        assert missing_priv.empty?, "#{username}@#{host} missing the following privileges for #{database_name}: #{missing_priv.keys.sort.join(", ")}"
      end
    end

    describe "app which is served by this database master" do
      it "production database exists" do
        assert mysql_database_exists?("www_production"), "www_production database database does not exist"
      end

      it "another production database exists" do
        assert mysql_database_exists?("www_production_also"), "www_production_also database does not exist"
      end

      it "staging database does not exist" do
        refute mysql_database_exists?("www_staging"), "www_staging database exists"
      end

      it "production user exists for localhost" do
        assert mysql_user_exists?("www_production", "localhost"), "www_production user does not exist for localhost"
      end

      it "production user exists for all hosts" do
        assert mysql_user_exists?("www_production", "%"), "www_production user does not exist for %"
      end

      it "production user exists for the node fqdn" do
        assert mysql_user_exists?("www_production", node['fqdn']), "www_production user does not exist for #{node['fqdn']}"
      end

      it "production user for localhost has access to the production database" do
        assert_mysql_granted_all?("www_production", "localhost", "www_production")
      end

      it "production user for all hosts has access to the production database" do
        assert_mysql_granted_all?("www_production", "%", "www_production")
      end

      it "production user for the node fqdn has access to the production database" do
        assert_mysql_granted_all?("www_production", node['fqdn'], "www_production")
      end

      it "production user for localhost has access to another production database" do
        assert_mysql_granted_all?("www_production", "localhost", "www_production_also")
      end

      it "production user for all hosts has access to another production database" do
        assert_mysql_granted_all?("www_production", "%", "www_production_also")
      end

      it "production user for the node fqdn has access to another production database" do
        assert_mysql_granted_all?("www_production", node['fqdn'], "www_production_also")
      end

      it "staging user does not exist for localhost" do
        refute mysql_user_exists?("www_staging", "localhost"), "www_staging user exists"
      end

      it "staging user does not exist for localhost" do
        refute mysql_user_exists?("www_staging", node['fqdn']), "www_staging user exists for #{node['fqdn']}"
      end
    end

    describe "app which is served by a different database master" do
      it "production database does not exist" do
        refute mysql_database_exists?("princess_production"), "princess_production exists"
      end
    end
  end
end
