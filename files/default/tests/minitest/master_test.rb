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
      it "production database exists using mysql adapter" do
        assert mysql_database_exists?("www_production"), "www_production database database does not exist"
      end

      it "another production database exists using mysql2 adapter" do
        assert mysql_database_exists?("www_production_also"), "www_production_also database does not exist"
      end

      it "secret production database exists" do
        assert mysql_database_exists?("www_prod_secret"), "www_prod_secret database does not exist"
      end

      it "production host-based database does not exist" do
        refute mysql_database_exists?("www_prod_host"), "www_prod_host database exists"
      end

      it "production database using postgresql adapter does not exist as a mysql database" do
        refute mysql_database_exists?("www_prod_pg"), "www_prod_pg mysql database exists"
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

      it "secret production user exists for localhost" do
        assert mysql_user_exists?("www_prod_secret", "localhost"), "www_prod_secret user does not exist for localhost"
      end

      it "secret production user exists for all hosts" do
        assert mysql_user_exists?("www_prod_secret", "%"), "www_prod_secret user does not exist for %"
      end

      it "secret production user exists for the node fqdn" do
        assert mysql_user_exists?("www_prod_secret", node['fqdn']), "www_prod_secret user does not exist for #{node['fqdn']}"
      end

      it "secret production user for localhost has access to the secret production database" do
        assert_mysql_granted_all?("www_prod_secret", "localhost", "www_prod_secret")
      end

      it "secret production user for all hosts has access to the secret production database" do
        assert_mysql_granted_all?("www_prod_secret", "%", "www_prod_secret")
      end

      it "secret production user for the node fqdn has access to the secret production database" do
        assert_mysql_granted_all?("www_prod_secret", node['fqdn'], "www_prod_secret")
      end

      it "user for a host-based database does not exist for localhost" do
        refute mysql_user_exists?("www_prod_host", "localhost"), "www_prod_host user exists for localhost"
      end

      it "user for a host-based database does not exist for all hosts" do
        refute mysql_user_exists?("www_prod_host", "%"), "www_prod_host user exists for %"
      end

      it "user for a host-based database does not exist for the node fqdn" do
        refute mysql_user_exists?("www_prod_host", node['fqdn']), "www_prod_host user exists for #{node['fqdn']}"
      end

      it "postgresql adapter mysql user does not exist for localhost" do
        refute mysql_user_exists?("www_prod_pg", "localhost"), "www_prod_pg mysql user exists for localhost"
      end

      it "postgresql adapter mysql user does not exist for all hosts" do
        refute mysql_user_exists?("www_prod_pg", "%"), "www_prod_pg mysql user exists for %"
      end

      it "postgresql adapter mysql user does not exist for the node fqdn" do
        refute mysql_user_exists?("www_prod_pg", node['fqdn']), "www_prod_pg mysql user exists for #{node['fqdn']}"
      end

      it "staging user does not exist for localhost" do
        refute mysql_user_exists?("www_staging", "localhost"), "www_staging user exists for localhost"
      end

      it "staging user does not exist for all hosts" do
        refute mysql_user_exists?("www_staging", "%"), "www_staging user exists for %"
      end

      it "staging user does not exist for the node fqdn" do
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
