package Schema::Result::Subscription;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime");

=head1 NAME

Schema::Result::Subscription

=cut

__PACKAGE__->table("subscriptions");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 user

  data_type: 'integer'
  is_nullable: 1

=head2 uuid

  data_type: 'char'
  is_nullable: 1
  size: 36

=head2 sg

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 sn

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 pg

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 pn

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 s

  data_type: 'varchar'
  is_nullable: 1
  size: 32

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "user",
  { data_type => "integer", is_nullable => 1 },
  "uuid",
  { data_type => "char", is_nullable => 1, size => 36 },
  "sg",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "sn",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "pg",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "pn",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "s",
  { data_type => "varchar", is_nullable => 1, size => 32 },
);
__PACKAGE__->set_primary_key("id");


# Created by DBIx::Class::Schema::Loader v0.07010 @ 2012-10-26 14:16:14
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:GkZjMwXYwQBuwFcTt8wOVg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
