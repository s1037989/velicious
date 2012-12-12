package Schema::Result::History;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'Schema::Result';

__PACKAGE__->load_components("InflateColumn::DateTime", "Helper::Row::ToJSON");

=head1 NAME

Schema::Result::History

=cut

__PACKAGE__->table("history");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 uuid

  data_type: 'char'
  is_nullable: 1
  size: 36

=head2 pg

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 pn

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 dt

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=head2 s

  data_type: 'varchar'
  is_nullable: 1
  size: 32

=head2 n

  data_type: 'varchar'
  is_nullable: 1
  size: 32

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "uuid",
  { data_type => "char", is_nullable => 1, size => 36 },
  "pg",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "pn",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "dt",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "s",
  { data_type => "varchar", is_nullable => 1, size => 32 },
  "n",
  { data_type => "varchar", is_nullable => 1, size => 32 },
);
__PACKAGE__->set_primary_key("id");


# Created by DBIx::Class::Schema::Loader v0.07010 @ 2012-12-10 17:44:06
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:eSKR6GYE9Vo3AzNatpeSxQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
