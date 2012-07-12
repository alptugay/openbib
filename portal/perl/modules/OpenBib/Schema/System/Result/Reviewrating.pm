package OpenBib::Schema::System::Result::Reviewrating;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';


=head1 NAME

OpenBib::Schema::System::Result::Reviewrating

=cut

__PACKAGE__->table("reviewrating");

=head1 ACCESSORS

=head2 id

  data_type: 'bigint'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'reviewrating_id_seq'

=head2 userid

  data_type: 'bigint'
  is_foreign_key: 1
  is_nullable: 0

=head2 reviewid

  data_type: 'bigint'
  is_foreign_key: 1
  is_nullable: 0

=head2 tstamp

  data_type: 'timestamp'
  is_nullable: 1

=head2 rating

  data_type: 'smallint'
  default_value: '0::smallint'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "bigint",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "reviewrating_id_seq",
  },
  "userid",
  { data_type => "bigint", is_foreign_key => 1, is_nullable => 0 },
  "reviewid",
  { data_type => "bigint", is_foreign_key => 1, is_nullable => 0 },
  "tstamp",
  { data_type => "timestamp", is_nullable => 1 },
  "rating",
  {
    data_type     => "smallint",
    default_value => "0::smallint",
    is_nullable   => 0,
  },
);
__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 reviewid

Type: belongs_to

Related object: L<OpenBib::Schema::System::Result::Review>

=cut

__PACKAGE__->belongs_to(
  "reviewid",
  "OpenBib::Schema::System::Result::Review",
  { id => "reviewid" },
  { on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 userid

Type: belongs_to

Related object: L<OpenBib::Schema::System::Result::Userinfo>

=cut

__PACKAGE__->belongs_to(
  "userid",
  "OpenBib::Schema::System::Result::Userinfo",
  { id => "userid" },
  { on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07000 @ 2012-07-12 11:30:12
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:7bj419FTFSivxkSiZ8rO1Q


# You can replace this text with custom content, and it will be preserved on regeneration
1;
