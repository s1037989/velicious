package Schema::Result::Val;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime");

=head1 NAME

Schema::Result::Val

=cut

__PACKAGE__->table("vals");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 test_id

  data_type: 'integer'
  is_nullable: 0

=head2 dt

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 0

=head2 s

  data_type: 'varchar'
  default_value: 'INFO'
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
  "test_id",
  { data_type => "integer", is_nullable => 0 },
  "dt",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 0,
  },
  "s",
  {
    data_type => "varchar",
    default_value => "INFO",
    is_nullable => 1,
    size => 32,
  },
  "n",
  { data_type => "varchar", is_nullable => 1, size => 32 },
);
__PACKAGE__->set_primary_key("id");


# Created by DBIx::Class::Schema::Loader v0.07010 @ 2012-10-30 16:25:40
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:pSWRnUS10oWw3mtgfzXsUQ

__PACKAGE__->load_components(qw{Helper::Row::ToJSON});

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
