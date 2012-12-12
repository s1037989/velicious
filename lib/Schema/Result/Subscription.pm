package Schema::Result::Subscription;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'Schema::Result';

__PACKAGE__->load_components("InflateColumn::DateTime", "Helper::Row::ToJSON");

=head1 NAME

Schema::Result::Subscription

=cut

__PACKAGE__->table("subscriptions");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 user_id

  data_type: 'integer'
  is_nullable: 1

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
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "user_id",
  { data_type => "integer", is_nullable => 1 },
  "label",
  { data_type => "varchar", is_nullable => 1, size => 32 },
  "uuid",
  { data_type => "char", is_nullable => 1, size => 36 },
);
__PACKAGE__->set_primary_key("id");


# Created by DBIx::Class::Schema::Loader v0.07010 @ 2012-12-10 18:02:04
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:aQTUVRLYvnjIBY0z6SDUPA

__PACKAGE__->load_components(qw{Helper::Row::ToJSON});
__PACKAGE__->belongs_to(user => 'Schema::Result::User', 'user_id');
__PACKAGE__->belongs_to(system => 'Schema::Result::System', 'uuid');

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
