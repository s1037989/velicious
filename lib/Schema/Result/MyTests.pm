package Schema::Result::MyTests;
use strict;
use warnings;
use base qw/DBIx::Class::Core/;

__PACKAGE__->load_components(qw{Helper::Row::ToJSON});
__PACKAGE__->table_class('DBIx::Class::ResultSource::View');

# ->table, ->add_columns, etc.
__PACKAGE__->table('users');
__PACKAGE__->add_columns(qw/test_id email uuid create_dt age dg sn dt pg pn y l s ok n/);
__PACKAGE__->set_primary_key("test_id");

# do not attempt to deploy() this view
__PACKAGE__->result_source_instance->is_virtual(1);

__PACKAGE__->result_source_instance->view_definition(q[
select tests.test_id,email,systems.uuid,create_dt,case when time_to_sec(timediff(now(),systems.dt)) < 300 then null when time_to_sec(timediff(now(),systems.dt)) < 86400 then 'WARN' else 'ALERT' end age,dg,sn,pg,pn,vals.dt,s,truncate((select count(*) from vals where vals.test_id=tests.test_id and s="OK")/(select count(*) from vals where vals.test_id=tests.test_id)*100,2) ok,n,y,l from systems join user_subscriptions_vw us on systems.uuid=us.uuid or us.uuid is null left join tests on systems.uuid=tests.uuid left join vals on tests.test_id=vals.test_id and tests.last_dt=vals.dt
]);

__PACKAGE__->has_many(vals => 'Schema::Result::Val', 'test_id');

sub t {
	my $self = shift;
	if ( my $s = $self->search_related('vals')->search({'s'=>{'!='=>$self->s}}, {select=>[\'timediff(now(),dt)'], as=>['t'], order_by=>'dt desc',rows=>1}) ) {
		if ( $s = $s->next ) {
			return $s->get_column('t');
		} else {
			return '';
		}
	} else {
		return '';
	}
}

sub TO_JSON {
	my $self = shift;

	return {
		t => $self->t,
		%{$self->next::method},
	}
}

1;
