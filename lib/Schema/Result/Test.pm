package Schema::Result::Test;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime");

=head1 NAME

Schema::Result::Test

=cut

__PACKAGE__->table("tests");

=head1 ACCESSORS

=head2 test_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 uuid

  data_type: 'char'
  is_nullable: 0
  size: 36

=head2 pg

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 pn

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 last_dt

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=head2 y

  data_type: 'text'
  is_nullable: 1

=head2 l

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "test_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "uuid",
  { data_type => "char", is_nullable => 0, size => 36 },
  "pg",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "pn",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "last_dt",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "y",
  { data_type => "text", is_nullable => 1 },
  "l",
  { data_type => "text", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("test_id");


# Created by DBIx::Class::Schema::Loader v0.07010 @ 2012-10-31 07:49:51
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:l8L8EBf8tnBOZOSwydpggQ

__PACKAGE__->load_components(qw{Helper::Row::ToJSON});

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
