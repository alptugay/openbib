package OpenBib::Schema::System;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Schema';

$SIG{INT} = sub {
    __PACKAGE__->storage->dbh->disconnect;
};

__PACKAGE__->load_namespaces;


# Created by DBIx::Class::Schema::Loader v0.07010 @ 2015-05-11 15:52:34
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:SDPK684bgecRBCjAXwP8mA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
