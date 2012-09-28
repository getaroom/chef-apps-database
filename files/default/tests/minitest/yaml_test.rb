describe_recipe "apps-database::yaml" do
  include MiniTest::Chef::Assertions
  include MiniTest::Chef::Context
  include MiniTest::Chef::Resources

  describe "database.yml for an app hosted on this server using a relational database" do
    let(:app_user) { user "www" }
    let(:app_group) { group "www" }
    let(:yml) { file "/srv/www/shared/config/database.yml" }
    let(:stat) { File.stat(yml.path) }

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
