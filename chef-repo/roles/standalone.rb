name "standalone"
description "Standalone Server"

run_list(
  "recipe[minitest-handler]",
  "recipe[mysql::server]",
  "recipe[apps-database::master]",
)

override_attributes({
  "minitest" => {
    "tests" => "apps-database/*_test.rb",
  },
  "mysql" => {
    "server_debian_password" => "password",
    "server_repl_password"   => "password",
    "server_root_password"   => "password",
  },
})
