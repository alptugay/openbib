#!/usr/bin/perl

#####################################################################
#
#  lidos32meta.pl
#
#  Konvertierung von Lidos 3 Daten in das Meta-Format
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

use Encode;
use Getopt::Long;
use JSON::XS;
use YAML::Syck;

use OpenBib::Config;
use OpenBib::Conv::Common::Util;

# Importieren der Konfigurationsdaten als Globale Variablen
# in diesem Namespace

my ($inputfile,$configfile);

&GetOptions(
	    "inputfile=s"       => \$inputfile,
            "configfile=s"      => \$configfile,
	    );

if (!$inputfile && !$configfile){
    print << "HELP";
lidos32meta.pl - Aufrufsyntax

    lidos32meta.pl --inputfile=xxx --configfile=yyy
HELP
exit;
}

# Ininitalisierung mit Config-Parametern
my $convconfig = YAML::Syck::LoadFile($configfile);

# $mergecat_ref = {
# 	       '0100' => 1,
# 	       '0331' => 1,
# 	       '0509' => 1,
# 	       '0590' => 1,
# };

# Einlesen und Reorganisieren

print "### Einlesen, kategorisieren und Umwandeln der Ursprungs-Daten\n";

open(DAT,"$inputfile");

my $encoding = q{ # 
		 [\x00-\xA0]                                  # ASCII
		 | [\xA1-\xF7][\xA1-\xFE]                     # GB2312/EUC-CN
		};

my ($title_ref,$multcount_ref,$holding_ref)=({ 'fields' => {}, },{},{'fields' => {},});
my $category_src = "";

my $mexidn = 1;

open (TIT,">:raw","meta.title");
open (PER,">:raw","meta.person");
open (KOR,">:raw","meta.corporatebody");
open (SYS,">:raw","meta.classification");
open (SWD,">:raw","meta.subject");
open (MEX,">:raw","meta.holding");

while (<DAT>){
    s/\r//;
    if (/^\d+\S+\d+\S+\d+/){ # Neuer-Titel
        if (defined $title_ref->{id}){
            print TIT encode_json $title_ref, "\n";
            $holding_ref->{id} = $mexidn++;
            push @{$holding_ref->{fields}{'0004'}},{
                content  => $title_ref->{id},
                mult     => 1,
                subfield => '',
            };
            print MEX encode_json $holding_ref, "\n";
        }
        $title_ref     = {};
        $holding_ref   = {};
        $multcount_ref = {};
    }
    # Kategorien fangen mit + an
    elsif (/^\+(.+)$/){
        $category_src = $1;
    }
    # Auf die Kategorien folgen die Inhalte mit -
    elsif (/^-(.+)/){
        my $content = $1;
        
        if ($category_src){
            
            # Inhalt in gemischtem Encoding decodieren
            {
                my $newcontent = "";
                
                my @chars = $content =~ /$encoding/gosx;  # Pro 1 oder 2-byte Zeichen ein Char
                
                foreach my $char (@chars) {
                    if (length($char) == 2) { # 2-byte Zeichen
                        #	  $newcontent .= Encode::decode("euc-cn",$char)." ";
                        # Sonderwunsch: Keine Leerzeichen
                        $newcontent .= Encode::decode("euc-cn",$char);
                    }
                    else {  # 1-byte Zeichen
                        $newcontent .= Encode::decode("cp437",$char);
                    }
                }
                
                $newcontent=~s/ //g; # Schmutzzeichen weg.
                $content = $newcontent;
            }
            
            if ($convconfig->{uniqueidfield} eq $category_src){
                $title_ref->{id} = $content;
            }
            
            # Titel
            if (defined $convconfig->{title}{$category_src}){
                my $field     = $convconfig->{title}{$category_src};
                my $multcount = ++$multcount_ref->{$field};

                # Inhalte filtern
                {
                    if ($convconfig->{filter}{$field}{filter_generic}){
                        foreach my $filter (@{$convconfig->{filter}{$field}{filter_generic}}){
                            my $from = $filter->{from};
                            my $to   = $filter->{to};
                            
                            $content =~s/$from/$to/g;
                        }
                    }
                    
                    if ($convconfig->{filter}{$field}{filter_junk}){
                        $content = filter_junk($content);
                    }
                    
                    if ($convconfig->{filter}{$field}{filter_newline2br}){
                        $content = filter_newline2br($content);
                    }
                    
                    if ($convconfig->{filter}{$field}{filter_match}){
                        $content = filter_match($content,$convconfig->{filter}{$field}{filter_match});
                    }
                }

                if (defined $convconfig->{continued_line_fields}{$field}){
                    if (!defined $title_ref->{fields}{$field}){
                        push @{$title_ref->{fields}{$field}}, {
                            content  => $content,
                            mult     => $multcount,
                            subfield => '',
                        };
                    }
                    else {
                        $title_ref->{fields}{$field}[0]{content} = $title_ref->{fields}{$field}[0]{content}." $content";
                    }
                }
                else {
                    push @{$title_ref->{fields}{$field}}, {
                        content  => $content,
                        mult     => $multcount,
                        subfield => '',
                    };
                }
            }
            
            # Personen
            if (defined $convconfig->{pers}{$category_src}){
                my $field     = $convconfig->{pers}{$category_src};
                my $multcount = ++$multcount_ref->{$field};
                
                my $supplement="";
                if ($content =~/^(.+?) *\/? *(\(.*?$)/){
                    $content    = $1;
                    $supplement = " ; $2";
                }
                
                my ($person_id,$new)=OpenBib::Conv::Common::Util::get_person_id($content);
                
                if ($new){
                    my $item_ref = {
                        'fields' => {},
                    };
                    $item_ref->{id} = $person_id;
                    push @{$item_ref->{fields}{'0800'}}, {
                        mult     => 1,
                        subfield => '',
                        content  => $content,
                    };
                    
                    print PER encode_json $item_ref, "\n";
                }
                
                push @{$title_ref->{fields}{$field}}, {
                    mult       => $multcount,
                    subfield   => '',
                    id         => $person_id,
                    supplement => $supplement,
                };
            }
            
            # Koerperschaften
            if (defined $convconfig->{corp}{$category_src}){
                my $field     = $convconfig->{corp}{$category_src};
                my $multcount = ++$multcount_ref->{$field};
                
                my ($corporatebody_id,$new)=OpenBib::Conv::Common::Util::get_corporatebody_id($content);
                
                if ($new){
                    my $item_ref = {
                        'fields' => {},
                    };
                    $item_ref->{id} = $corporatebody_id;
                    push @{$item_ref->{fields}{'0800'}}, {
                        mult     => 1,
                        subfield => '',
                        content  => $content,
                    };
                    
                    print KOR encode_json $item_ref, "\n";
                }
                
                push @{$title_ref->{fields}{$field}}, {
                    mult       => $multcount,
                    subfield   => '',
                    id         => $corporatebody_id,
                    supplement => '',
                };
            }

            # Klassifikation
            if (defined $convconfig->{sys}{$category_src}){
                my $field     = $convconfig->{sys}{$category_src};
                my $multcount = ++$multcount_ref->{$field};

                my ($classification_id,$new)=OpenBib::Conv::Common::Util::get_classification_id($content);
                
                if ($new){
                    my $item_ref = {
                        'fields' => {},
                    };
                    $item_ref->{id} = $classification_id;
                    push @{$item_ref->{fields}{'0800'}}, {
                        mult     => 1,
                        subfield => '',
                        content  => $content,
                    };
                    
                    print SYS encode_json $item_ref, "\n";
                }
                
                push @{$title_ref->{fields}{$field}}, {
                    mult       => $multcount,
                    subfield   => '',
                    id         => $classification_id,
                    supplement => '',
                };
            }

            if (defined $convconfig->{subj}{$category_src}){
                my $field     = $convconfig->{subj}{$category_src};
                my $multcount = ++$multcount_ref->{$field};

                my ($subject_id,$new)=OpenBib::Conv::Common::Util::get_subject_id($content);
                
                if ($new){
                    my $item_ref = {
                        'fields' => {},
                    };
                    $item_ref->{id} = $subject_id;
                    push @{$item_ref->{fields}{'0800'}}, {
                        mult     => 1,
                        subfield => '',
                        content  => $content,
                    };
                    
                    print SWD encode_json $item_ref, "\n";
                }
                
                push @{$title_ref->{fields}{$field}}, {
                    mult       => $multcount,
                    subfield   => '',
                    id         => $subject_id,
                    supplement => '',
                };
            }

            if (defined $convconfig->{holding}{$category_src}){
                my $field     = $convconfig->{holding}{$category_src};
                my $multcount = ++$multcount_ref->{$field};

                push @{$holding_ref->{fields}{$field}}, {
                    content  => $content,
                    mult     => $multcount,
                    subfield => '',
                };
            }
        }
    }
}

    # Letzten Satz schreiben
if (defined $title_ref->{id}){
    print TIT encode_json $title_ref, "\n";
    print MEX encode_json $holding_ref, "\n";
}

close(DAT);

close(TIT);
close(PER);
close(KOR);
close(SWD);
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

