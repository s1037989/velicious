package Schema::Result::Detail;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime");

=head1 NAME

Schema::Result::Detail

=cut

__PACKAGE__->table("details");

=head1 ACCESSORS

=head2 test_id

  data_type: 'integer'
  is_nullable: 0

=head2 y

  data_type: 'text'
  is_nullable: 1

=head2 l

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "test_id",
  { data_type => "integer", is_nullable => 0 },
  "y",
  { data_type => "text", is_nullable => 1 },
  "l",
  { data_type => "text", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("test_id");


# Created by DBIx::Class::Schema::Loader v0.07010 @ 2012-10-30 16:37:21
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Ki4rx+OaYYIPJ9krtgKXTQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
