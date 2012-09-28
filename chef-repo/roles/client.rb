name "client"
description "Database Client"

run_list(
  "recipe[minitest-handler]",
  "recipe[apps]",
  "recipe[apps-database::yaml]",
)

override_attributes({
  "minitest" => {
    "tests" => "apps-database/*_test.rb",
  },
})
