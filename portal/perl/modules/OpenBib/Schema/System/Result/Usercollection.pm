use utf8;
package OpenBib::Schema::System::Result::Usercollection;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

OpenBib::Schema::System::Result::Usercollection

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<usercollection>

=cut

__PACKAGE__->table("usercollection");

=head1 ACCESSORS

=head2 id

  data_type: 'bigint'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'collection_id_seq'

=head2 userid

  data_type: 'bigint'
  is_foreign_key: 1
  is_nullable: 0

=head2 dbname

  data_type: 'text'
  is_nullable: 1

=head2 titleid

  data_type: 'text'
  is_nullable: 1

=head2 titlecache

  data_type: 'text'
  is_nullable: 1

=head2 comment

  data_type: 'text'
  default_value: (empty string)
  is_nullable: 1

=head2 tstamp

  data_type: 'timestamp'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "bigint",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "collection_id_seq",
  },
  "userid",
  { data_type => "bigint", is_foreign_key => 1, is_nullable => 0 },
  "dbname",
  { data_type => "text", is_nullable => 1 },
  "titleid",
  { data_type => "text", is_nullable => 1 },
  "titlecache",
  { data_type => "text", is_nullable => 1 },
  "comment",
  { data_type => "text", default_value => "", is_nullable => 1 },
  "tstamp",
  { data_type => "timestamp", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 userid

Type: belongs_to

Related object: L<OpenBib::Schema::System::Result::Userinfo>

=cut

__PACKAGE__->belongs_to(
  "userid",
  "OpenBib::Schema::System::Result::Userinfo",
  { id => "userid" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07025 @ 2012-11-26 11:48:09
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:IylpjKGdDo4/Yp1gO79bwQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
