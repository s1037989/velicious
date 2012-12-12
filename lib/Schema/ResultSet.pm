package Schema::ResultSet;

use base qw/DBIx::Class::ResultSet::WithMetaData DBIx::Class::ResultSet::HashRef DBIx::Class::ResultSet/;
#use base qw/DBIx::Class::ResultSet/;
__PACKAGE__->load_components(qw{Helper::ResultSet::Shortcut});

1;
