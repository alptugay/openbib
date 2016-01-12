#!/usr/bin/perl

use warnings;
use strict;

use JSON::XS;

print STDERR "### inst438 Erweitere Titeldaten\n";

while (<>){
    my $title_ref = decode_json $_;

    push @{$title_ref->{'locations'}}, "DE-38-438";
    push @{$title_ref->{'locations'}}, "DE-38-ARCH";
    
    print encode_json $title_ref, "\n";
}
