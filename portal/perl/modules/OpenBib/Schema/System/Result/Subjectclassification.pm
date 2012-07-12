package OpenBib::Schema::System::Result::Subjectclassification;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';


=head1 NAME

OpenBib::Schema::System::Result::Subjectclassification

=cut

__PACKAGE__->table("subjectclassification");

=head1 ACCESSORS

=head2 subjectid

  data_type: 'bigint'
  is_foreign_key: 1
  is_nullable: 0

=head2 classification

  data_type: 'varchar'
  is_nullable: 0
  size: 20

=head2 type

  data_type: 'varchar'
  is_nullable: 0
  size: 5

=cut

__PACKAGE__->add_columns(
  "subjectid",
  { data_type => "bigint", is_foreign_key => 1, is_nullable => 0 },
  "classification",
  { data_type => "varchar", is_nullable => 0, size => 20 },
  "type",
  { data_type => "varchar", is_nullable => 0, size => 5 },
);

=head1 RELATIONS

=head2 subjectid

Type: belongs_to

Related object: L<OpenBib::Schema::System::Result::Subject>

=cut

__PACKAGE__->belongs_to(
  "subjectid",
  "OpenBib::Schema::System::Result::Subject",
  { id => "subjectid" },
  { on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07000 @ 2012-07-12 11:30:12
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:mpQXOBXyQNqlFrKvOw+bTw


# You can replace this text with custom content, and it will be preserved on regeneration
1;
