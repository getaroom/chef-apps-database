describe_recipe "apps-database::yaml" do
  include MiniTest::Chef::Assertions
  include MiniTest::Chef::Context
  include MiniTest::Chef::Resources

  describe "database.yml for an app hosted on this server using a relational database" do
    let(:app_user) { user "www" }
    let(:app_group) { group "www" }
    let(:yml) { file "/srv/www/shared/config/database.yml" }
    let(:stat) { File.stat(yml.path) }

    let :host do
      nodes = Chef::Search::Query.new.search(:node, "role:mysql_master").first
      nodes.sort_by(&:name).reverse.map { |node| node['cloud']['local_ipv4'] }.uniq.first
    end

    it "exists" do
      yml.must_exist
    end

    it "is owned by the app user" do
      assert_equal app_user.uid, stat.uid
      assert_equal app_group.gid, stat.gid
    end

    it "is mode 660" do
      assert_equal "660".oct, (stat.mode & 007777)
    end

    it "does not serialize any special types" do
      yml.wont_include "!"
    end

    it "contains information about the production databases" do
      expected_yaml = {
        "production" => {
          "adapter" => "mysql",
          "database" => "www_production",
          "username" => "www_production",
          "password" => "password",
          "host" => host,
          "reconnect" => true,
        },
        "another_production_database" => {
          "adapter" => "mysql2",
          "database" => "www_production_also",
          "username" => "www_production",
          "password" => "password",
          "host" => host,
          "reconnect" => true,
        },
        "production_secret" => {
          "adapter" => "mysql",
          "database" => "www_prod_secret",
          "username" => "www_prod_secret",
          "password" => "secret",
          "host" => host,
          "reconnect" => true,
        },
        "production_host" => {
          "adapter" => "mysql",
          "database" => "www_prod_host",
          "username" => "www_prod_host",
          "password" => "www_prod_host",
          "host" => "127.0.0.1",
        },
        "production_pg" => {
          "adapter" => "postgresql",
          "database" => "www_prod_pg",
          "username" => "www_prod_pg",
          "host" => "127.0.0.1",
          "password" => "password",
        },
      }

      actual_yaml = YAML.load_file(yml.path)
      assert_equal expected_yaml, actual_yaml
    end
  end

  describe "an application not hosted on this server" do
    it "does not create a database.yml file" do
      file("/srv/princess/shared/config/database.yml").wont_exist
    end
  end

  describe "an application hosted on this server but not using a relational database" do
    it "does not create a database.yml file" do
      file("/srv/toad/shared/config/database.yml").wont_exist
    end
  end
end
