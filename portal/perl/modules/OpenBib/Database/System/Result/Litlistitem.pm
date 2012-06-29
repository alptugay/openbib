package OpenBib::Database::System::Result::Litlistitem;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';


=head1 NAME

OpenBib::Database::System::Result::Litlistitem

=cut

__PACKAGE__->table("litlistitem");

=head1 ACCESSORS

=head2 id

  data_type: 'bigint'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'litlistitem_id_seq'

=head2 litlistid

  data_type: 'bigint'
  is_foreign_key: 1
  is_nullable: 0

=head2 tstamp

  data_type: 'timestamp'
  is_nullable: 1

=head2 dbname

  data_type: 'varchar'
  is_nullable: 0
  size: 25

=head2 titleid

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 titleisbn

  data_type: 'char'
  default_value: (empty string)
  is_nullable: 0
  size: 14

=head2 titlecache

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "bigint",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "litlistitem_id_seq",
  },
  "litlistid",
  { data_type => "bigint", is_foreign_key => 1, is_nullable => 0 },
  "tstamp",
  { data_type => "timestamp", is_nullable => 1 },
  "dbname",
  { data_type => "varchar", is_nullable => 0, size => 25 },
  "titleid",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "titleisbn",
  { data_type => "char", default_value => "", is_nullable => 0, size => 14 },
  "titlecache",
  { data_type => "text", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 litlistid

Type: belongs_to

Related object: L<OpenBib::Database::System::Result::Litlist>

=cut

__PACKAGE__->belongs_to(
  "litlistid",
  "OpenBib::Database::System::Result::Litlist",
  { id => "litlistid" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07010 @ 2012-06-27 13:44:53
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:/0UEY+8X/KL1CZUCWgJzLA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
