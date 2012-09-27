name             "apps-database"
maintainer       "getaroom"
maintainer_email "devteam@roomvaluesteam.com"
license          "MIT"
description      "Configures databases for Apps"
long_description IO.read(File.join(File.dirname(__FILE__), "README.md"))
version          "1.0.0"

depends "apps"
depends "database"

supports "debian"
supports "ubuntu"

recipe "apps-database", "Configures databases for apps."
recipe "apps-database::master", "Setup databases and users from the apps data bag."
