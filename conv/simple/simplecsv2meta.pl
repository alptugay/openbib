#!/usr/bin/perl

#####################################################################
#
#  simplecsv2meta.pl
#
#  Konverierung der einfach aufgebauter CVS-Daten in das Meta-Format
#
#  Dieses File ist (C) 1999-2012 Oliver Flimm <flimm@openbib.org>
#
#  Dieses Programm ist freie Software. Sie koennen es unter
#  den Bedingungen der GNU General Public License, wie von der
#  Free Software Foundation herausgegeben, weitergeben und/oder
#  modifizieren, entweder unter Version 2 der Lizenz oder (wenn
#  Sie es wuenschen) jeder spaeteren Version.
#
#  Die Veroeffentlichung dieses Programms erfolgt in der
#  Hoffnung, dass es Ihnen von Nutzen sein wird, aber OHNE JEDE
#  GEWAEHRLEISTUNG - sogar ohne die implizite Gewaehrleistung
#  der MARKTREIFE oder der EIGNUNG FUER EINEN BESTIMMTEN ZWECK.
#  Details finden Sie in der GNU General Public License.
#
#  Sie sollten eine Kopie der GNU General Public License zusammen
#  mit diesem Programm erhalten haben. Falls nicht, schreiben Sie
#  an die Free Software Foundation, Inc., 675 Mass Ave, Cambridge,
#  MA 02139, USA.
#
#####################################################################

#####################################################################
# Einladen der benoetigten Perl-Module
#####################################################################

use strict;
use warnings;
use utf8;

use Encode 'decode';
use Getopt::Long;
use DBI;
use YAML::Syck;

use OpenBib::Config;
use OpenBib::Conv::Common::Util;


my $config = OpenBib::Config->instance;

my ($inputfile,$configfile);

&GetOptions(
	    "inputfile=s"          => \$inputfile,
            "configfile=s"         => \$configfile,
	    );

if (!$inputfile && !$configfile){
    print << "HELP";
simplecsv2meta.pl - Aufrufsyntax

    simplecsv2meta.pl --inputfile=xxx --configfile=yyy.yml
HELP
exit;
}

# Ininitalisierung mit Config-Parametern
my $convconfig = YAML::Syck::LoadFile($configfile);

# Einlesen und Reorganisieren

if (defined $convconfig->{tracelevel} && $convconfig->{tracelevel} >= 0){
    DBI->trace($convconfig->{tracelevel});
}

my $dbh = DBI->connect("DBI:CSV:");
$dbh->{'csv_tables'}->{'data'} = {
    'eol'         => $convconfig->{csv}{eol},
    'sep_char'    => $convconfig->{csv}{sep_char},
    'quote_char'  => $convconfig->{csv}{quote_char},
    'escape_char' => $convconfig->{csv}{escape_char},
    'file'        => "$inputfile",
};

$dbh->{'RaiseError'} = 1;

our $mexidn=1;

my $request = $dbh->prepare("select * from data") || die $dbh->errstr;
$request->execute();

my $outputencoding = ($convconfig->{outputencoding})?$convconfig->{outputencoding}:'utf8';

open (TIT,     ">:encoding($outputencoding)","meta.title");
open (AUT,     ">:encoding($outputencoding)","meta.person");
open (KOR,     ">:encoding($outputencoding)","meta.corporatebody");
open (NOTATION,">:encoding($outputencoding)","meta.classification");
open (SWT,     ">:encoding($outputencoding)","meta.subject");
open (MEX,     ">:encoding($outputencoding)","meta.holding");

my $titid = 1;
my $have_titid_ref = {};
while (my $result=$request->fetchrow_hashref){
    print YAML::Dump($result);
    if ($convconfig->{uniqueidfield}){
        my $id = $result->{$convconfig->{uniqueidfield}};
        if ($convconfig->{uniqueidmatch}){
            my $uniquematchregexp = $convconfig->{uniqueidmatch};
            ($id)=$id=~m/$uniquematchregexp/;
        }
        unless ($id){
            print STDERR  "KEINE ID\n";
            next;
        }
        
        if ($have_titid_ref->{$id}){
            print STDERR  "Doppelte ID: $id\n";
	    next;
        }
        printf TIT "0000:$id\n";
        $have_titid_ref->{$id} = 1;
    }
    else {
        printf TIT "0000:%d\n", $titid++;
    }

    foreach my $kateg (keys %{$convconfig->{title}}){
        my $content = decode($convconfig->{encoding},$result->{$kateg});

        if ($content){
            if ($convconfig->{filter}{$kateg}{filter_generic}){
                foreach my $filter (@{$convconfig->{filter}{$kateg}{filter_generic}}){
                    my $from = $filter->{from};
                    my $to   = $filter->{to};
                    $content =~s/$from/$to/g;
                    
                    #                print STDERR "Filtering from $from to $to: New content $content\n";
                }
            }
            
            if ($convconfig->{filter}{$kateg}{filter_junk}){
                $content = filter_junk($content);
            }
            
            if ($convconfig->{filter}{$kateg}{filter_newline2br}){
                $content = filter_newline2br($content);
            }

            if ($convconfig->{filter}{$kateg}{filter_match}){
                $content = filter_match($content,$convconfig->{filter}{$kateg}{filter_match});
            }

            my $multiple = 0;
            my @parts = ();
            if (exists $convconfig->{category_split_chars}{$kateg} && $content=~/$convconfig->{category_split_chars}{$kateg}/){
                @parts = split($convconfig->{category_split_chars}{$kateg},$content);
                $multiple = 1;
            }
            else {
                $content=~s/\n/ /g;
                push @parts, $content;
            }
            
            foreach my $part (@parts){
                $part=~s/uhttp:/http:/;
                my $new_category = $convconfig->{title}{$kateg};

                if ($multiple && $new_category=~/^(\d+):$/){
                    $new_category=sprintf "%s.%03d:",$1,$multiple;
                    $multiple++;
                }
                print TIT $new_category.$part."\n";
            }
        }
    }

    # Autoren abarbeiten Anfang
    foreach my $kateg (keys %{$convconfig->{pers}}){
        my $content = decode($convconfig->{encoding},$result->{$kateg});

        if ($content){

            if ($convconfig->{filter}{$kateg}{filter_generic}){
                foreach my $filter (@{$convconfig->{filter}{$kateg}{filter_generic}}){
                    my $from = $filter->{from};
                    my $to   = $filter->{to};
                    
#                    print STDERR "Filtering $content from $from to $to\n";
                    
                    $content =~s/$from/$to/g;
                    
#                    print STDERR "New content $content\n";
                }
            }

            if ($convconfig->{filter}{$kateg}{filter_junk}){
                $content = filter_junk($content);
            }
            
            if ($convconfig->{filter}{$kateg}{filter_newline2br}){
                $content = filter_newline2br($content);
            }

            if ($convconfig->{filter}{$kateg}{filter_match}){
                $content = filter_match($content,$convconfig->{filter}{$kateg}{filter_match});
            }

            my $multiple = 0;
            my @parts = ();
            if (exists $convconfig->{category_split_chars}{$kateg} && $content=~/$convconfig->{category_split_chars}{$kateg}/){
                @parts = split($convconfig->{category_split_chars}{$kateg},$content);
                $multiple = 1;
            }
            else {
                push @parts, $content;
            }
            
            foreach my $part (@parts){
                my ($person_id,$new) = OpenBib::Conv::Common::Util::get_person_id($part);
                
                if ($new){
                    print AUT "0000:$person_id\n";
                    print AUT "0001:$part\n";
                    print AUT "9999:\n";
                    
                }

                my $new_category = $convconfig->{pers}{$kateg};

                if ($multiple && $new_category=~/^(\d+):$/){
                    $new_category=sprintf "%s.%03d:",$1,$multiple;
                    $multiple++;
                }

                print TIT $new_category."IDN: $person_id\n";
            }
        }

    }
    # Autoren abarbeiten Ende
    
    # Koerperschaften abarbeiten Anfang
    foreach my $kateg (keys %{$convconfig->{corp}}){
        my $content = decode($convconfig->{encoding},$result->{$kateg});
        
        if ($content){
            if ($convconfig->{filter}{$kateg}{filter_generic}){
                foreach my $filter (@{$convconfig->{filter}{$kateg}{filter_generic}}){
                    my $from = $filter->{from};
                    my $to   = $filter->{to};
                    
#                    print STDERR "Filtering $content from $from to $to\n";
                    
                    $content =~s/$from/$to/g;
                    
#                    print STDERR "New content $content\n";
                }
            }

            if ($convconfig->{filter}{$kateg}{filter_junk}){
                $content = filter_junk($content);
            }
            
            if ($convconfig->{filter}{$kateg}{filter_newline2br}){
                $content = filter_newline2br($content);
            }

            if ($convconfig->{filter}{$kateg}{filter_match}){
                $content = filter_match($content,$convconfig->{filter}{$kateg}{filter_match});
            }

            my $multiple = 0;
            my @parts = ();
            if (exists $convconfig->{category_split_chars}{$kateg} && $content=~/$convconfig->{category_split_chars}{$kateg}/){
                @parts = split($convconfig->{category_split_chars}{$kateg},$content);
                $multiple = 1;                
            }
            else {
                push @parts, $content;
            }
            
            foreach my $part (@parts){
                my ($corporatebody_id,$new) = OpenBib::Conv::Common::Util::get_corporatebody_id($part);
                
                if ($new){
                    print KOR "0000:$corporatebody_id\n";
                    print KOR "0001:$part\n";
                    print KOR "9999:\n";
                    
                }

                my $new_category = $convconfig->{corp}{$kateg};

                if ($multiple && $new_category=~/^(\d+):$/){
                    $new_category=sprintf "%s.%03d:",$1,$multiple;
                    $multiple++;
                }
                
                print TIT $new_category."IDN: $corporatebody_id\n";
            }
        }
    }
    # Koerperschaften abarbeiten Ende


    # Notationen abarbeiten Anfang
    foreach my $kateg (keys %{$convconfig->{sys}}){
        my $content = decode($convconfig->{encoding},$result->{$kateg});
        
        if ($content){
            if ($convconfig->{filter}{$kateg}{filter_generic}){
                foreach my $filter (@{$convconfig->{filter}{$kateg}{filter_generic}}){
                    my $from = $filter->{from};
                    my $to   = $filter->{to};
                    
#                    print STDERR "Filtering $content from $from to $to\n";
                    
                    $content =~s/$from/$to/g;
                    
#                    print STDERR "New content $content\n";
                }
            }
            
            if ($convconfig->{filter}{$kateg}{filter_junk}){
                $content = filter_junk($content);
            }
            
            if ($convconfig->{filter}{$kateg}{filter_newline2br}){
                $content = filter_newline2br($content);
            }

            if ($convconfig->{filter}{$kateg}{filter_match}){
                $content = filter_match($content,$convconfig->{filter}{$kateg}{filter_match});
            }

            my $multiple = 0;
            my @parts = ();
            if (exists $convconfig->{category_split_chars}{$kateg} && $content=~/$convconfig->{category_split_chars}{$kateg}/){
                @parts = split($convconfig->{category_split_chars}{$kateg},$content);
                $multiple = 1;
            }
            else {
                push @parts, $content;
            }
            
            foreach my $part (@parts){
                my ($classification_id,$new) = OpenBib::Conv::Common::Util::get_corporatebody_id($part);
                
                if ($new){
                    print NOTATION "0000:$classification_id\n";
                    print NOTATION "0001:$part\n";
                    print NOTATION "9999:\n";
                    
                }

                my $new_category = $convconfig->{sys}{$kateg};

                if ($multiple && $new_category=~/^(\d+):$/){
                    $new_category=sprintf "%s.%03d:",$1,$multiple;
                    $multiple++;
                }
                
                print TIT $new_category."IDN: $classification_id\n";
            }
        }
    }
    # Notationen abarbeiten Ende

    # Schlagworte abarbeiten Anfang
    foreach my $kateg (keys %{$convconfig->{subj}}){
        my $content = decode($convconfig->{encoding},$result->{$kateg});

        if ($content){
            if ($convconfig->{filter}{$kateg}{filter_generic}){
                foreach my $filter (@{$convconfig->{filter}{$kateg}{filter_generic}}){
                    my $from = $filter->{from};
                    my $to   = $filter->{to};
                    
#                    print STDERR "Filtering $content from $from to $to\n";
                    
                    $content =~s/$from/$to/g;
                    
#                    print STDERR "New content $content\n";
                }
            }

            if ($convconfig->{filter}{$kateg}{filter_junk}){
                $content = filter_junk($content);
            }
            
            if ($convconfig->{filter}{$kateg}{filter_newline2br}){
                $content = filter_newline2br($content);
            }

            if ($convconfig->{filter}{$kateg}{filter_match}){
                $content = filter_match($content,$convconfig->{filter}{$kateg}{filter_match});
            }
            
            my $multiple = 0;
            my @parts = ();
            if (exists $convconfig->{category_split_chars}{$kateg} && $content=~/$convconfig->{category_split_chars}{$kateg}/){
                @parts = split($convconfig->{category_split_chars}{$kateg},$content);
                $multiple = 1;
            }
            else {
                push @parts, $content;
            }
            
            foreach my $part (@parts){
                my ($subject_id,$new) = OpenBib::Conv::Common::Util::get_corporatebody_id($part);
                
                if ($new){
                    print SWT "0000:$subject_id\n";
                    print SWT "0001:$part\n";
                    print SWT "9999:\n";
                    
                }

                my $new_category = $convconfig->{subj}{$kateg};

                if ($multiple && $new_category=~/^(\d+):$/){
                    $new_category=sprintf "%s.%03d:",$1,$multiple;
                    $multiple++;
                }
                
                print TIT $new_category."IDN: $subject_id\n";
            }
            
        }
    }
    # Schlagworte abarbeiten Ende


    my %mex = ();
    # Exemplare abarbeiten Anfang
    foreach my $kateg (keys %{$convconfig->{exempl}}){
        my $content = decode($convconfig->{encoding},$result->{$kateg});

        if ($content){
            if ($convconfig->{filter}{$kateg}{filter_generic}){
                foreach my $filter (@{$convconfig->{filter}{$kateg}{filter_generic}}){
                    my $from = $filter->{from};
                    my $to   = $filter->{to};
                    
#                    print STDERR "Filtering $content from $from to $to\n";
                    
                    $content =~s/$from/$to/g;
                    
#                    print STDERR "New content $content\n";
                }
            }

            if ($convconfig->{filter}{$kateg}{filter_junk}){
                $content = filter_junk($content);
            }
            
            if ($convconfig->{filter}{$kateg}{filter_newline2br}){
                $content = filter_newline2br($content);
            }

            if ($convconfig->{filter}{$kateg}{filter_match}){
                $content = filter_match($content,$convconfig->{filter}{$kateg}{filter_match});
            }

            my $multiple = 1;
            my @parts = ();
            if (exists $convconfig->{category_split_chars}{$kateg} && $content=~/$convconfig->{category_split_chars}{$kateg}/){
                @parts = split($convconfig->{category_split_chars}{$kateg},$content);
            }
            else {
                push @parts, $content;
            }

            foreach my $part (@parts){
                 $mex{$multiple}{$convconfig->{exempl}{$kateg}} = $part; 
            }
        }
    }

    #print YAML::Dump(\%mex);
    foreach my $part (keys %mex){        
        print MEX "0000:$mexidn\n";
        print MEX "0004:$titid\n";
        foreach my $category (keys %{$mex{$part}}){
            print MEX $category.$mex{$part}{$category}."\n";
        }
        print MEX "9999:\n";
        $mexidn++;
    }

    # Exemplare abarbeiten Ende

    print TIT "9999:\n";
}

close(TIT);
close(AUT);
close(KOR);
close(NOTATION);
close(SWT);
close(MEX);

# Filter

sub filter_junk {
    my ($content) = @_;

    $content=~s/\W/ /g;
    $content=~s/\s+/ /g;
    $content=~s/\s\D\s/ /g;

    
    return $content;
}

sub filter_newline2br {
    my ($content) = @_;

    $content=~s/\n/<br\/>/g;
    
    return $content;
}

sub filter_match {
    my ($content,$regexp) = @_;

    my ($match)=$content=~m/$regexp/g;

    return $match;
}
