#!/bin/bash

/usr/bin/sqlite3 /var/lib/dbconfig-common/sqlite3/redmine/instances/default/redmine_default <<EOF
insert into settings (name, value) values ('plugin_redmine_pgcommunityauth', '---
 authsite_id: "4"
 cipher_key: yvBI3WwV6gfvqUCwm+2zxfG6nq9Tp/cbuumBHKH3f3A=
 default_url: /
 base_url: "http://pgweb.localhost:9000/"');
EOF
