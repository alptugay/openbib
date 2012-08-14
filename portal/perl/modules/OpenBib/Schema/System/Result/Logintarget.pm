package OpenBib::Schema::System::Result::Logintarget;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';


=head1 NAME

OpenBib::Schema::System::Result::Logintarget

=cut

__PACKAGE__->table("logintarget");

=head1 ACCESSORS

=head2 id

  data_type: 'bigint'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'logintarget_id_seq'

=head2 hostname

  data_type: 'text'
  is_nullable: 1

=head2 port

  data_type: 'text'
  is_nullable: 1

=head2 remoteuser

  data_type: 'text'
  is_nullable: 1

=head2 remotedb

  data_type: 'text'
  is_nullable: 1

=head2 description

  data_type: 'text'
  is_nullable: 1

=head2 type

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "bigint",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "logintarget_id_seq",
  },
  "hostname",
  { data_type => "text", is_nullable => 1 },
  "port",
  { data_type => "text", is_nullable => 1 },
  "remoteuser",
  { data_type => "text", is_nullable => 1 },
  "remotedb",
  { data_type => "text", is_nullable => 1 },
  "description",
  { data_type => "text", is_nullable => 1 },
  "type",
  { data_type => "text", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 user_sessions

Type: has_many

Related object: L<OpenBib::Schema::System::Result::UserSession>

=cut

__PACKAGE__->has_many(
  "user_sessions",
  "OpenBib::Schema::System::Result::UserSession",
  { "foreign.targetid" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07010 @ 2012-08-14 08:42:28
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Ri1IEZqMjlBqGlo50N2Q2A


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
