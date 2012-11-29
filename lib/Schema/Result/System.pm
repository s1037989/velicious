package Schema::Result::System;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime");

=head1 NAME

Schema::Result::System

=cut

__PACKAGE__->table("systems");

=head1 ACCESSORS

=head2 uuid

  data_type: 'char'
  is_nullable: 0
  size: 36

=head2 create_dt

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=head2 dt

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

=head2 dg

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 sn

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 conf

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "uuid",
  { data_type => "char", is_nullable => 0, size => 36 },
  "create_dt",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "dt",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    default_value => \"current_timestamp",
    is_nullable => 0,
  },
  "dg",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "sn",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "conf",
  { data_type => "text", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("uuid");


# Created by DBIx::Class::Schema::Loader v0.07010 @ 2012-11-01 08:25:10
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:fuupUF2mV6ajU5W49F1Niw

__PACKAGE__->load_components(qw{Helper::Row::ToJSON});

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
