package Schema::Result::Test;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'Schema::Result';

__PACKAGE__->load_components("InflateColumn::DateTime", "Helper::Row::ToJSON");

=head1 NAME

Schema::Result::Test

=cut

__PACKAGE__->table("tests");

=head1 ACCESSORS

=head2 id

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

=head2 pg_sort

  data_type: 'integer'
  is_nullable: 1

=head2 pn

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 pn_sort

  data_type: 'integer'
  is_nullable: 1

=head2 dt

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=head2 s

  data_type: 'varchar'
  is_nullable: 1
  size: 32

=head2 ok

  data_type: 'varchar'
  is_nullable: 1
  size: 6

=head2 t

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=head2 n

  data_type: 'varchar'
  is_nullable: 1
  size: 32

=head2 y

  data_type: 'text'
  is_nullable: 1

=head2 l

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "uuid",
  { data_type => "char", is_nullable => 0, size => 36 },
  "pg",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "pg_sort",
  { data_type => "integer", is_nullable => 1 },
  "pn",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "pn_sort",
  { data_type => "integer", is_nullable => 1 },
  "dt",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "s",
  { data_type => "varchar", is_nullable => 1, size => 32 },
  "ok",
  { data_type => "varchar", is_nullable => 1, size => 6 },
  "t",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "n",
  { data_type => "varchar", is_nullable => 1, size => 32 },
  "y",
  { data_type => "text", is_nullable => 1 },
  "l",
  { data_type => "text", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");


# Created by DBIx::Class::Schema::Loader v0.07010 @ 2012-12-14 05:02:41
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:gfV3QjkDFrdxJCyHIqHf4g

__PACKAGE__->load_components(qw{Helper::Row::ToJSON});
__PACKAGE__->belongs_to(system => 'Schema::Result::System', 'uuid');

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
