describe_recipe "apps-database::master" do
  include MiniTest::Chef::Assertions
  include MiniTest::Chef::Context
  include MiniTest::Chef::Resources

  MiniTest::Chef::Resources.register_resource :mysql_database, :connection

  describe "production mysql server" do
    let(:connection) { { :host => "localhost", :username => "root", :password => node['mysql']['server_root_password'] } }

    describe "app which is served by this database master" do
      describe "staging database" do
        it "exists" do
          resource = Chef::Resource::MysqlDatabase.new("www_staging")
          resource.connection connection
          provider = Chef::Provider::Database::Mysql.new(resource, nil)
          refute provider.tap(&:load_current_resource).send(:exists?)
        end
      end
    end
  end
end
