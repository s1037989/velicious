package Schema::Result::MyTests;
use strict;
use warnings;
use base qw/DBIx::Class::Core/;

__PACKAGE__->load_components(qw{Helper::Row::ToJSON});
__PACKAGE__->table_class('DBIx::Class::ResultSource::View');

# ->table, ->add_columns, etc.
__PACKAGE__->table('users');
__PACKAGE__->add_columns(qw/id email uuid create_dt age label sn dt pg pg_sort pn pn_sort y l s ok t n/);
__PACKAGE__->set_primary_key("id");

# do not attempt to deploy() this view
__PACKAGE__->result_source_instance->is_virtual(1);

__PACKAGE__->result_source_instance->view_definition(q[
  select
    tests.id,
    email,
    systems.uuid,
    create_dt,
    case when time_to_sec(timediff(now(),systems.dt)) < 300 then null when time_to_sec(timediff(now(),systems.dt)) < 86400 then 'WARN' else 'ALERT' end age,
    label,
    sn,
    pg,
    pg_sort,
    pn,
    pn_sort,
    tests.dt,
    s,
    ok,
    timediff(now(), t) t,
    n,
    y,
    l
  from systems
  join user_subscriptions_vw us on systems.uuid=us.uuid or us.uuid is null
  left join tests on systems.uuid=tests.uuid
  where tests.dt = systems.dt
]);

1;
