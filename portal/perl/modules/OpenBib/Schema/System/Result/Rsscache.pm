use utf8;
package OpenBib::Schema::System::Result::Rsscache;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

OpenBib::Schema::System::Result::Rsscache

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<rsscache>

=cut

__PACKAGE__->table("rsscache");

=head1 ACCESSORS

=head2 rssinfoid

  data_type: 'bigint'
  is_foreign_key: 1
  is_nullable: 0

=head2 id

  data_type: 'text'
  is_nullable: 1

=head2 tstamp

  data_type: 'timestamp'
  is_nullable: 1

=head2 content

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "rssinfoid",
  { data_type => "bigint", is_foreign_key => 1, is_nullable => 0 },
  "id",
  { data_type => "text", is_nullable => 1 },
  "tstamp",
  { data_type => "timestamp", is_nullable => 1 },
  "content",
  { data_type => "text", is_nullable => 1 },
);

=head1 RELATIONS

=head2 rssinfoid

Type: belongs_to

Related object: L<OpenBib::Schema::System::Result::Rssinfo>

=cut

__PACKAGE__->belongs_to(
  "rssinfoid",
  "OpenBib::Schema::System::Result::Rssinfo",
  { id => "rssinfoid" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2017-02-03 15:42:03
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:kfd+8rco4SsK/AXYuWqMCw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
