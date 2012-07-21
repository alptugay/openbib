package OpenBib::Schema::Catalog::Result::Person;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';


=head1 NAME

OpenBib::Schema::Catalog::Result::Person

=cut

__PACKAGE__->table("person");

=head1 ACCESSORS

=head2 id

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 tstamp_create

  data_type: 'timestamp'
  is_nullable: 1

=head2 tstamp_update

  data_type: 'timestamp'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "tstamp_create",
  { data_type => "timestamp", is_nullable => 1 },
  "tstamp_update",
  { data_type => "timestamp", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 person_fields

Type: has_many

Related object: L<OpenBib::Schema::Catalog::Result::PersonField>

=cut

__PACKAGE__->has_many(
  "person_fields",
  "OpenBib::Schema::Catalog::Result::PersonField",
  { "foreign.personid" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 title_people

Type: has_many

Related object: L<OpenBib::Schema::Catalog::Result::TitlePerson>

=cut

__PACKAGE__->has_many(
  "title_people",
  "OpenBib::Schema::Catalog::Result::TitlePerson",
  { "foreign.personid" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07000 @ 2012-07-21 12:51:30
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:IVc3Mbo8FIvymSxDShdC6w


# You can replace this text with custom content, and it will be preserved on regeneration
1;
