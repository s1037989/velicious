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
  "sn",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "conf",
  { data_type => "text", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("uuid");


# Created by DBIx::Class::Schema::Loader v0.07010 @ 2012-10-26 14:16:14
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:1gWE8y4+IkUsQFI8SJhBSg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
