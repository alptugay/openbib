#!/usr/bin/perl

use warnings;
use strict;

use JSON::XS;

print STDERR "### inst450 Erweitere Titeldaten\n";

while (<>){
    my $title_ref = decode_json $_;

    push @{$title_ref->{'locations'}}, "DE-38-450";
    push @{$title_ref->{'locations'}}, "DE-38-ASIEN";
    push @{$title_ref->{'locations'}}, "DE-38-USBFB";
    
    print encode_json $title_ref, "\n";
}
