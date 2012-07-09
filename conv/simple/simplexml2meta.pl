#!/usr/bin/perl

#####################################################################
#
#  simplexml2meta.pl
#
#  Konvertierung eines flachen XML-Formates in des OpenBib
#  Einlade-Metaformat
#
#  Dieses File ist (C) 2012 Oliver Flimm <flimm@openbib.org>
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

use 5.008001;

use utf8;
use strict;
use warnings;

use Encode 'decode';
use Getopt::Long;
use XML::Twig::XPath;
use XML::Simple;

use YAML::Syck;

use OpenBib::Config;
use OpenBib::Conv::Common::Util;

my ($inputfile,$configfile);

&GetOptions(
	    "inputfile=s"          => \$inputfile,
            "configfile=s"         => \$configfile,
	    );

if (!$inputfile || !$configfile){
    print << "HELP";
simplexml2meta.pl - Aufrufsyntax

    simplexml2meta.pl --inputfile=xxx --configfile=yyy.yml
HELP
exit;
}

# Ininitalisierung mit Config-Parametern
my $convconfig = YAML::Syck::LoadFile($configfile);

open (TIT,     ">:utf8","meta.title");
open (AUT,     ">:utf8","meta.person");
open (KOR,     ">:utf8","meta.corporatebody");
open (NOTATION,">:utf8","meta.classification");
open (SWT,     ">:utf8","meta.subject");
open (MEX,     ">:utf8","meta.holding");

my $twig= XML::Twig::XPath->new(
   TwigHandlers => {
     "$convconfig->{recordselector}" => \&parse_record
   }
 );

our $counter = 0;

$twig->safe_parsefile($inputfile);

print STDERR "All $counter records converted\n";

close(TIT);
close(AUT);
close(KOR);
close(NOTATION);
close(SWT);
close(MEX);

sub parse_record {
    my($t, $titset)= @_;

    my @ids= $titset->get_xpath($convconfig->{uniqueidfield});

    print TIT "0000:".$ids[0]->first_child()->text()."\n";

    foreach my $kateg (keys %{$convconfig->{title}}){

        my @elements = $titset->get_xpath($kateg);

        my @parts = ();
        
        foreach my $element (@elements){
            next unless (defined $element->first_child());
            my $content = konv($element->first_child()->text());

            if ($convconfig->{filter}{$kateg}{filter_junk}){
                $content = filter_junk($content);
            }
            
            if ($convconfig->{filter}{$kateg}{filter_newline2br}){
                $content = filter_newline2br($content);
            }

            if ($convconfig->{filter}{$kateg}{filter_match}){
                $content = filter_match($content,$convconfig->{filter}{$kateg}{filter_match});
            }

            if ($convconfig->{filter}{$kateg}{filter_add_year}){
                my $new_content = filter_match($content,$convconfig->{filter}{$kateg}{filter_add_year}{regexp});
                print TIT $convconfig->{filter}{$kateg}{filter_add_year}{category}.$new_content."\n";
            }

            if ($content){
                $content=decode($convconfig->{encoding},$content) if ($convconfig->{encoding});
    
                if (exists $convconfig->{category_split_chars}{$kateg} && $content=~/$convconfig->{category_split_chars}{$kateg}/){
                    @parts = split($convconfig->{category_split_chars}{$kateg},$content);
                }
                else {
                    push @parts, $content;
                }
            }
        }
        
        foreach my $part (@parts){
            print TIT $convconfig->{title}{$kateg}.$part."\n";
        }
    }
    
    # Autoren abarbeiten Anfang
    foreach my $kateg (keys %{$convconfig->{pers}}){
        my @elements = $titset->get_xpath($kateg);

        my @parts = ();
        
        foreach my $element (@elements){
            next unless (defined $element->first_child());
            my $content = konv($element->first_child()->text());

            if ($convconfig->{filter}{$kateg}{filter_junk}){
                $content = filter_junk($content);
            }
            
            if ($convconfig->{filter}{$kateg}{filter_newline2br}){
                $content = filter_newline2br($content);
            }
            
            if ($convconfig->{filter}{$kateg}{filter_match}){
                $content = filter_match($content,$convconfig->{filter}{$kateg}{filter_match});
            }
                
            if ($content){
                $content=decode($convconfig->{encoding},$content) if ($convconfig->{encoding});
                                              
                if (exists $convconfig->{category_split_chars}{$kateg} && $content=~/$convconfig->{category_split_chars}{$kateg}/){
                    @parts = split($convconfig->{category_split_chars}{$kateg},$content);                    
                }
                else {
                    push @parts, $content;
                }
            }
        }
        
        foreach my $part (@parts){
            my ($person_id,$new) = OpenBib::Conv::Common::Util::get_person_id($part);
            
            if ($new){
                print AUT "0000:$person_id\n";
                print AUT "0001:$part\n";
                print AUT "9999:\n";
                
            }
            
            my $new_category = $convconfig->{pers}{$kateg};

            print TIT $new_category."IDN: $person_id\n";
        }
        # Autoren abarbeiten Ende
    }

    # Koerperschaften abarbeiten Anfang
    foreach my $kateg (keys %{$convconfig->{corp}}){
        my @elements = $titset->get_xpath($kateg);
        
        my @parts = ();
        
        foreach my $element (@elements){
            next unless (defined $element->first_child());
            my $content = konv($element->first_child()->text());

            if ($convconfig->{filter}{$kateg}{filter_junk}){
                $content = filter_junk($content);
            }
            
            if ($convconfig->{filter}{$kateg}{filter_newline2br}){
                $content = filter_newline2br($content);
            }
            
            if ($convconfig->{filter}{$kateg}{filter_match}){
                $content = filter_match($content,$convconfig->{filter}{$kateg}{filter_match});
            }

            if ($content){
                $content=decode($convconfig->{encoding},$content) if ($convconfig->{encoding});
                
                if (exists $convconfig->{category_split_chars}{$kateg} && $content=~/$convconfig->{category_split_chars}{$kateg}/){
                    @parts = split($convconfig->{category_split_chars}{$kateg},$content);
                }
                else {
                    push @parts, $content;
                }
            }
        }
        
        foreach my $part (@parts){
            my ($corporatebody_id,$new) = OpenBib::Conv::Common::Util::get_corporatebody_id($part);
            
            if ($new){
                print KOR "0000:$corporatebody_id\n";
                print KOR "0001:$part\n";
                print KOR "9999:\n";
                
            }
            
            my $new_category = $convconfig->{corp}{$kateg};
            
            print TIT $new_category."IDN: $corporatebody_id\n";
        }
    }
    # Koerperschaften abarbeiten Ende

    # Notationen abarbeiten Anfang
    foreach my $kateg (keys %{$convconfig->{sys}}){
        my @elements = $titset->get_xpath($kateg);
        
        my @parts = ();
        
        foreach my $element (@elements){
            next unless (defined $element->first_child());
            my $content = konv($element->first_child()->text());

            if ($convconfig->{filter}{$kateg}{filter_junk}){
                $content = filter_junk($content);
            }
            
            if ($convconfig->{filter}{$kateg}{filter_newline2br}){
                $content = filter_newline2br($content);
            }
            
            if ($convconfig->{filter}{$kateg}{filter_match}){
                $content = filter_match($content,$convconfig->{filter}{$kateg}{filter_match});
            }

            if ($content){
                $content=decode($convconfig->{encoding},$content) if ($convconfig->{encoding});
                
                if (exists $convconfig->{category_split_chars}{$kateg} && $content=~/$convconfig->{category_split_chars}{$kateg}/){
                    @parts = split($convconfig->{category_split_chars}{$kateg},$content);
                }
                else {
                    push @parts, $content;
                }
            }
        }
                
        foreach my $part (@parts){
            my ($classification_id,$new) = OpenBib::Conv::Common::Util::get_corporatebody_id($part);
            
            if ($new){
                print NOTATION "0000:$classification_id\n";
                print NOTATION "0001:$part\n";
                print NOTATION "9999:\n";
                
            }
            
            my $new_category = $convconfig->{sys}{$kateg};
            
            print TIT $new_category."IDN: $classification_id\n";
        }
    }
    # Notationen abarbeiten Ende
        
    # Schlagworte abarbeiten Anfang
    foreach my $kateg (keys %{$convconfig->{subj}}){
        my @elements = $titset->get_xpath($kateg);

        my @parts = ();
        
        foreach my $element (@elements){
            next unless (defined $element->first_child());
            my $content = konv($element->first_child()->text());

            if ($convconfig->{filter}{$kateg}{filter_junk}){
                $content = filter_junk($content);
            }
            
            if ($convconfig->{filter}{$kateg}{filter_newline2br}){
                $content = filter_newline2br($content);
            }
            
            if ($convconfig->{filter}{$kateg}{filter_match}){
                $content = filter_match($content,$convconfig->{filter}{$kateg}{filter_match});
            }

            if ($content){
                $content=decode($convconfig->{encoding},$content) if ($convconfig->{encoding});
                
                if (exists $convconfig->{category_split_chars}{$kateg} && $content=~/$convconfig->{category_split_chars}{$kateg}/){
                    @parts = split($convconfig->{category_split_chars}{$kateg},$content);
                }
                else {
                    push @parts, $content;
                }
            }
        }
                
        foreach my $part (@parts){
            my ($subject_id,$new) = OpenBib::Conv::Common::Util::get_corporatebody_id($part);
            
            if ($new){
                print SWT "0000:$subject_id\n";
                print SWT "0001:$part\n";
                print SWT "9999:\n";
                
            }
            
            my $new_category = $convconfig->{subj}{$kateg};
            
            print TIT $new_category."IDN: $subject_id\n";
        }
    }
    # Schlagworte abarbeiten Ende

    print TIT "9999:\n";

    $counter++;

    if ($counter % 1000 == 0){
        print STDERR "$counter records converted\n";
    }
    
    # Release memory of processed tree
    # up to here
    $t->purge();
}
                                   
sub konv {
    my ($content)=@_;

#    $content=~s/\&/&amp;/g;
    $content=~s/>/&gt;/g;
    $content=~s/</&lt;/g;

    return $content;
}

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

    my ($match)=$content=~m/($regexp)/g;
    
    return $match;
}

