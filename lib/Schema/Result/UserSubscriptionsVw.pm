package Schema::Result::UserSubscriptionsVw;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'Schema::Result';

__PACKAGE__->load_components("InflateColumn::DateTime", "Helper::Row::ToJSON");

=head1 NAME

Schema::Result::UserSubscriptionsVw

=cut

__PACKAGE__->table("user_subscriptions_vw");

=head1 ACCESSORS

=head2 user_id

  data_type: 'integer'
  default_value: 0
  is_nullable: 1

=head2 email

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 label

  data_type: 'varchar'
  is_nullable: 1
  size: 32

=head2 uuid

  data_type: 'char'
  is_nullable: 1
  size: 36

=cut

__PACKAGE__->add_columns(
  "user_id",
  { data_type => "integer", default_value => 0, is_nullable => 1 },
  "email",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "label",
  { data_type => "varchar", is_nullable => 1, size => 32 },
  "uuid",
  { data_type => "char", is_nullable => 1, size => 36 },
);


# Created by DBIx::Class::Schema::Loader v0.07010 @ 2012-12-10 22:00:42
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:sUFQwF5iF9LK+4xPI6uaJg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
