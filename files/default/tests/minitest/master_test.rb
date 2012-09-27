describe_recipe "apps-database::master" do
  include MiniTest::Chef::Assertions
  include MiniTest::Chef::Context
  include MiniTest::Chef::Resources

  MiniTest::Chef::Resources.register_resource :mysql_database, :connection

  describe "production mysql server" do
    def mysql_database_exists?(database_name)
      resource = Chef::Resource::MysqlDatabase.new(database_name)
      password = node['mysql']['server_root_password']
      resource.connection({ :host => "localhost", :username => "root", :password => password })
      provider = Chef::Provider::Database::Mysql.new(resource, nil)
      provider.tap(&:load_current_resource).send(:exists?)
    end

    describe "app which is served by this database master" do
      it "production database exists" do
        assert mysql_database_exists?("www_production"), "www_production database does not exist"
      end

      it "another production database exists" do
        assert mysql_database_exists?("www_production_also"), "www_production_also does not exist"
      end

      it "staging database does not exist" do
        refute mysql_database_exists?("www_staging"), "www_staging exists"
      end
    end

    describe "app which is served by a different database master" do
      it "production database does not exist" do
        refute mysql_database_exists?("princess_production"), "princess_production exists"
      end
    end
  end
end
