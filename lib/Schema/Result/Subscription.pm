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

=head2 user_id

  data_type: 'integer'
  is_nullable: 1

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
  "uuid",
  { data_type => "char", is_nullable => 1, size => 36 },
);
__PACKAGE__->set_primary_key("id");


# Created by DBIx::Class::Schema::Loader v0.07010 @ 2012-11-01 08:50:02
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:4w1+VbpF/srusKMIxmtuFQ

__PACKAGE__->load_components(qw{Helper::Row::ToJSON});

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
