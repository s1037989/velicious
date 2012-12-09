package Schema::Result::MyTests;
use strict;
use warnings;
use base qw/DBIx::Class::Core/;

__PACKAGE__->load_components(qw{Helper::Row::ToJSON});
__PACKAGE__->table_class('DBIx::Class::ResultSource::View');

# ->table, ->add_columns, etc.
__PACKAGE__->table('users');
__PACKAGE__->add_columns(qw/email uuid create_dt age dg sn dt pg pn y l s n/);

# do not attempt to deploy() this view
__PACKAGE__->result_source_instance->is_virtual(1);

__PACKAGE__->result_source_instance->view_definition(q[
select tests.test_id,email,systems.uuid,create_dt,case when time_to_sec(timediff(now(),systems.dt)) < 300 then null when time_to_sec(timediff(now(),systems.dt)) < 86400 then 'WARN' else 'ALERT' end age,dg,sn,pg,pn,vals.dt,s,n,y,l from systems join user_subscriptions_vw us on systems.uuid=us.uuid or us.uuid is null left join tests on systems.uuid=tests.uuid left join vals on tests.test_id=vals.test_id and tests.last_dt=vals.dt
]);

1;
