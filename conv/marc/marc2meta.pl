#!/usr/bin/perl

#####################################################################
#
#  marc2meta.pl
#
#  Konverierung von MARC-Daten in das Meta-Format
#
#  Dieses File ist (C) 2009-2014 Oliver Flimm <flimm@openbib.org>
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

use utf8;

use warnings;
use strict;

use Encode 'decode_utf8';
use Getopt::Long;
use DBI;
use MARC::Batch;
use MARC::Charset 'marc8_to_utf8';
use MARC::File::XML;
use YAML::Syck;
use JSON::XS qw(encode_json);
use Log::Log4perl qw(get_logger :levels);

use OpenBib::Config;
use OpenBib::Enrichment;
use OpenBib::Conv::Common::Util;

my ($inputfile,$configfile,$use_milid,$use_xml,$format,$loglevel);

&GetOptions(
            "format=s"        => \$format,
	    "inputfile=s"     => \$inputfile,
            "configfile=s"    => \$configfile,
            "loglevel=s"      => \$loglevel,
            "use-milid"       => \$use_milid,
            "use-xml"         => \$use_xml,
	    );

my $logfile = '/var/log/openbib/marc2meta.log';

$loglevel=($loglevel)?$loglevel:'INFO';

my $log4Perl_config = << "L4PCONF";
log4perl.rootLogger=$loglevel, LOGFILE, Screen
log4perl.appender.LOGFILE=Log::Log4perl::Appender::File
log4perl.appender.LOGFILE.filename=$logfile
log4perl.appender.LOGFILE.mode=append
log4perl.appender.LOGFILE.layout=Log::Log4perl::Layout::PatternLayout
log4perl.appender.LOGFILE.layout.ConversionPattern=%d [%c]: %m%n
log4perl.appender.Screen=Log::Dispatch::Screen
log4perl.appender.Screen.layout=Log::Log4perl::Layout::PatternLayout
log4perl.appender.Screen.layout.ConversionPattern=%d [%c]: %m%n
L4PCONF

Log::Log4perl::init(\$log4Perl_config);

# Log4perl logger erzeugen
my $logger = get_logger();

my $config = OpenBib::Config->new;
my $enrichmnt = new OpenBib::Enrichment;

if (!$inputfile){
    print << "HELP";
marc2meta.pl - Aufrufsyntax

    marc2meta.pl --inputfile=xxx
HELP
exit;
}

# Ininitalisierung mit Config-Parametern
my $convconfig = YAML::Syck::LoadFile($configfile) if ($configfile);

# Einlesen und Reorganisieren

open(DAT,"$inputfile");

open (TITLE,         ">:raw","meta.title");
open (PERSON,        ">:raw","meta.person");
open (CORPORATEBODY, ">:raw","meta.corporatebody");
open (CLASSIFICATION,">:raw","meta.classification");
open (SUBJECT,       ">:raw","meta.subject");
open (HOLDING,       ">:raw","meta.holding");

our $multcount_ref = {};

my $excluded_titles = 0;

$format=($format)?$format:'USMARC';

$logger->debug("Using format $format");

my $batch;

if ($use_xml){
    $logger->debug("Using MARC-XML");
    
    MARC::File::XML->default_record_format($format);
    
    $batch = MARC::Batch->new('XML', $inputfile);    
}
else {
    $logger->debug("Using native MARC");
    $batch = MARC::Batch->new($format, $inputfile);
}

# Recover from errors
$batch->strict_off();
$batch->warnings_off();

my $have_title_ref = {};

my $count=1;

my $all_count=1;

my $mexid = 1;

my $exclude_by_isbn_in_file_ref = {};

if ($configfile && $convconfig->{exclude}{by_isbn_in_file} && $convconfig->{exclude}{by_isbn_in_file}{filename}){
    my $filename = $convconfig->{exclude}{by_isbn_in_file}{filename};

    $logger->info("Einladen auszuschliessender ISBNs aus Datei $filename ");
    
    open(ISBN,$filename);

    while (<ISBN>){
        # Normierung auf ISBN13
        my $isbn13 = OpenBib::Common::Util::to_isbn13($_);

        $exclude_by_isbn_in_file_ref->{$isbn13} = 1;
    }

    close(ISBN);
}

# Ignore 4 consecutive errors
while (my $record = $batch->next() || $batch->next || $batch->next || $batch->next ){
    $all_count++;

    my $title_ref = {
        'fields' => {},
    };

    $multcount_ref = {};

    my $encoding = $record->encoding();

    $logger->debug("Encoding:$encoding:");

    if ($use_milid){
        my $field = $record->field('037');

        if (defined $field && $field->as_string('b') eq "MIL"){
            my $titleid = $field->as_string('a');
            $titleid=~s/\//_/g;
	    $titleid=~s/\\/_/g;

            $title_ref->{id} = $titleid;
        }
    }
    else {
        my $idfield = $record->field('001');
        my $titleid = (defined $idfield)?$idfield->as_string():undef;
        $titleid=~s/\//_/g;
        $titleid=~s/\\/_/g;
        
        $title_ref->{id} = $titleid;
    }

    $title_ref->{id}=~s/\s//g;

    unless (defined $title_ref->{id}){
        $logger->info("Keine ID vorhanden");
        next;
    }
    
    if (defined $have_title_ref->{$title_ref->{id}}){
        $logger->info("Doppelte ID ".$title_ref->{id});
        next;
    }

    $have_title_ref->{$title_ref->{id}} = 1;

    # Verfasser

    {
        # Verfasser
        foreach my $fieldno ('100','700'){
            foreach my $field ($record->field($fieldno)){
                my $linkage = ($encoding eq "MARC-8")?marc8_to_utf8($field->as_string('6')):decode_utf8($field->as_string('6'));
                
                my $linkage_fields_ref = get_linkage_fields({ record => $record, fieldnumber => $fieldno, linkage => $linkage});

                $field->delete_subfield(code => '6'); # Linkage
                my $content_a = ($encoding eq "MARC-8")?marc8_to_utf8($field->as_string('a')):decode_utf8($field->as_string('a'));
                my $content_c = ($encoding eq "MARC-8")?marc8_to_utf8($field->as_string('c')):decode_utf8($field->as_string('c'));
                my $content_d = ($encoding eq "MARC-8")?marc8_to_utf8($field->as_string('d')):decode_utf8($field->as_string('d'));

                $linkage_fields_ref = get_linkage_fields({ record => $record, fieldnumber => $fieldno, linkage => $linkage});

                if ($content_a){
                    $title_ref = add_person($content_a,$content_c,$content_d,$title_ref);
                }

                foreach my $linkage_field (@$linkage_fields_ref){
                    $linkage_field->delete_subfield(code => '6'); # Linkage

                    my $content_a = ($encoding eq "MARC-8")?marc8_to_utf8($linkage_field->as_string('a')):decode_utf8($linkage_field->as_string('a'));
                    my $content_c = ($encoding eq "MARC-8")?marc8_to_utf8($linkage_field->as_string('c')):decode_utf8($linkage_field->as_string('c'));
                    my $content_d = ($encoding eq "MARC-8")?marc8_to_utf8($linkage_field->as_string('d')):decode_utf8($linkage_field->as_string('d'));

                    if ($content_a){
                        $title_ref = add_person($content_a,$content_c,$content_d,$title_ref);
                    }
                }
                
            }
        }
    }

    # Koerperschaften
    {
        foreach my $fieldno ('110','710'){
            foreach my $field ($record->field($fieldno)){
                my $content_a = ($encoding eq "MARC-8")?marc8_to_utf8($field->as_string('a')):decode_utf8($field->as_string('a'));

                if ($content_a){
                    my ($corporatebody_id,$new) = OpenBib::Conv::Common::Util::get_corporatebody_id($content_a);
                    
                    if ($new){
                        my $item_ref = {
                            'fields' => {},
                        };
                        $item_ref->{id} = $corporatebody_id;
                        push @{$item_ref->{fields}{'0800'}}, {
                            mult     => 1,
                            subfield => '',
                            content  => konv($content_a),
                        };
                        
                        print CORPORATEBODY encode_json $item_ref, "\n";
                    }
                    
                    my $multcount=++$multcount_ref->{'0200'};
                    
                    push @{$title_ref->{fields}{'0200'}}, {
                        mult       => $multcount,
                        subfield   => '',
                        id         => $corporatebody_id,
                        supplement => '',
                    };
                }
            }
        }
    }

    # Klassifikationen

    {
        foreach my $field ($record->field('082')){
            my $content = ($encoding eq "MARC-8")?marc8_to_utf8($field->as_string($field)):decode_utf8($field->as_string($field));
            
            if ($content){            
                my ($classification_id,$new)=OpenBib::Conv::Common::Util::get_classification_id($content);
                
                if ($new){
                    my $item_ref = {
                        'fields' => {},
                    };
                    $item_ref->{id} = $classification_id;
                    push @{$item_ref->{fields}{'0800'}}, {
                        mult     => 1,
                        subfield => '',
                        content  => konv($content),
                    };
                    
                    print CLASSIFICATION encode_json $item_ref, "\n";
                }
                
                my $multcount=++$multcount_ref->{'0700'};
                
                push @{$title_ref->{fields}{'0700'}}, {
                    mult       => $multcount,
                    subfield   => '',
                    id         => $classification_id,
                    supplement => '',
                };
            }
        }
        
    }
    
    # Schlagworte

    {        
        # Schlagwort
        foreach my $fieldno ('650','651'){
            foreach my $field ($record->field($fieldno)){
                my $linkage = ($encoding eq "MARC-8")?marc8_to_utf8($field->as_string('6')):decode_utf8($field->as_string('6'));
                
                my $linkage_fields_ref = get_linkage_fields({ record => $record, fieldnumber => $fieldno, linkage => $linkage});

                $field->delete_subfield(code => '6'); # Linkage
                
                my $content = ($encoding eq "MARC-8")?marc8_to_utf8($field->as_string('a')):decode_utf8($field->as_string('a'));

                if ($content){
                    $title_ref = add_subject($content,$title_ref);
                }
                
                foreach my $linkage_field (@$linkage_fields_ref){
                    $linkage_field->delete_subfield(code => '6'); # Linkage

                    my $content = ($encoding eq "MARC-8")?marc8_to_utf8($linkage_field->as_string('a')):decode_utf8($linkage_field->as_string('a'));

                    if ($content){
                        $title_ref = add_subject($content,$title_ref);
                    }
                }

            }
        }
    }
    
    # Titel

    {
        # ISBN
        foreach my $field ($record->field('020')){
            my $content_a = ($encoding eq "MARC-8")?marc8_to_utf8($field->as_string('a')):decode_utf8($field->as_string('a'));
            my $content_z = ($encoding eq "MARC-8")?marc8_to_utf8($field->as_string('z')):decode_utf8($field->as_string('z'));

            $content_a=~s/\s+\(.+?\)\s*$//;
            $content_z=~s/\s+\(.+?\)\s*$//;
            
            if ($content_a){
                my $multcount=++$multcount_ref->{'0540'};
                
                push @{$title_ref->{fields}{'0540'}}, {
                    content  => konv($content_a),
                    subfield => '',
                    mult     => $multcount,
                };
            }

            if ($content_z){
                my $multcount=++$multcount_ref->{'0541'};
                
                push @{$title_ref->{fields}{'0541'}}, {
                    content  => konv($content_z),
                    subfield => '',
                    mult     => $multcount,
                };
            }

        }

        # ISSN
        foreach my $field ($record->field('022')){
            my $content_a = ($encoding eq "MARC-8")?marc8_to_utf8($field->as_string('a')):decode_utf8($field->as_string('a'));
            my $content_z = ($encoding eq "MARC-8")?marc8_to_utf8($field->as_string('z')):decode_utf8($field->as_string('z'));

            $content_a=~s/\s+\(.+?\)\s*$//;
            $content_z=~s/\s+\(.+?\)\s*$//;
            
            if ($content_a){
                my $multcount=++$multcount_ref->{'0543'};
                
                push @{$title_ref->{fields}{'0543'}}, {
                    content  => konv($content_a),
                    subfield => '',
                    mult     => $multcount,
                };
            }

            if ($content_z){
                my $multcount=++$multcount_ref->{'0544'};
                
                push @{$title_ref->{fields}{'0544'}}, {
                    content  => konv($content_z),
                    subfield => '',
                    mult     => $multcount,
                };
            }

        }
        
        foreach my $field ($record->field('040')){
            my $content_b = ($encoding eq "MARC-8")?marc8_to_utf8($field->as_string('b')):decode_utf8($field->as_string('b'));

            if ($content_b){
                my $multcount=++$multcount_ref->{'0015'};
                
                push @{$title_ref->{fields}{'0015'}}, {
                    content  => konv($content_b),
                    subfield => '',
                    mult     => $multcount,
                };
            }
        }

        # EST
        foreach my $field ($record->field('240')){
                
            my $content = ($encoding eq "MARC-8")?marc8_to_utf8($field->as_string()):decode_utf8($field->as_string());

            if ($content){
                my $multcount=++$multcount_ref->{'0304'};
                
                push @{$title_ref->{fields}{'0304'}}, {
                    content  => konv($content),
                    subfield => '',
                    mult     => $multcount,
                };
            }
        }
        
        # Uebers. HST (Translation)
        foreach my $field ($record->field('242')){
                
            my $content = ($encoding eq "MARC-8")?marc8_to_utf8($field->as_string()):decode_utf8($field->as_string());

            if ($content){
                my $multcount=++$multcount_ref->{'0503'};
                
                push @{$title_ref->{fields}{'0503'}}, {
                    content  => konv($content),
                    subfield => '',
                    mult     => $multcount,
                };
            }
        }
        
        # Sammlungsvermerk (Collective uniform title)
        foreach my $field ($record->field('243')){
                
            my $content = ($encoding eq "MARC-8")?marc8_to_utf8($field->as_string()):decode_utf8($field->as_string());

            if ($content){
                my $multcount=++$multcount_ref->{'0300'};
                
                push @{$title_ref->{fields}{'0300'}}, {
                    content  => konv($content),
                    subfield => '',
                    mult     => $multcount,
                };
            }
        }

        # HST
        foreach my $field ($record->field('245')){                      
            my $content_b = ($encoding eq "MARC-8")?marc8_to_utf8($field->as_string('b')):decode_utf8($field->as_string('b'));
            my $content_c = ($encoding eq "MARC-8")?marc8_to_utf8($field->as_string('c')):decode_utf8($field->as_string('c'));
            my $content_h = ($encoding eq "MARC-8")?marc8_to_utf8($field->as_string('h')):decode_utf8($field->as_string('h'));
            my $content_n = ($encoding eq "MARC-8")?marc8_to_utf8($field->as_string('n')):decode_utf8($field->as_string('n'));
            my $linkage   = ($encoding eq "MARC-8")?marc8_to_utf8($field->as_string('6')):decode_utf8($field->as_string('6'));
            
            # Subfields entfernen
            $field->delete_subfield(code => 'b');
            $field->delete_subfield(code => 'c');
            $field->delete_subfield(code => 'h');
            $field->delete_subfield(code => 'n');
            $field->delete_subfield(code => '6'); # Linkage


            my $linkage_fields_ref = get_linkage_fields({ record => $record, fieldnumber => '245', linkage => $linkage});
            
            # Zusatz zum HST
            if ($content_b){
                my $multcount=++$multcount_ref->{'0335'};
                
                push @{$title_ref->{fields}{'0335'}}, {
                    content  => konv($content_b),
                    subfield => '',
                    mult     => $multcount,
                };
                
            }
            
            # Vorl. Verfasser/Koerperschaft
            if ($content_c){
                my $multcount=++$multcount_ref->{'0359'};
                
                push @{$title_ref->{fields}{'0359'}}, {
                    content  => konv($content_c),
                    subfield => '',
                    mult     => $multcount,
                };                
            }

            # Zaehlung
            if ($content_n){
                my $multcount=++$multcount_ref->{'0089'};
                
                push @{$title_ref->{fields}{'0089'}}, {
                    content  => konv($content_n),
                    subfield => '',
                    mult     => $multcount,
                };
                
            }

            my $content = ($encoding eq "MARC-8")?marc8_to_utf8($field->as_string()):decode_utf8($field->as_string());

            foreach my $linkage_field (@$linkage_fields_ref){
                # Subfields entfernen
                $linkage_field->delete_subfield(code => 'h');
                $linkage_field->delete_subfield(code => '6');
            }
            
            if ($content){
                my $multcount=++$multcount_ref->{'0331'};
                
                push @{$title_ref->{fields}{'0331'}}, {
                    content  => konv($content),
                    subfield => '',
                    mult     => $multcount,
                };

                foreach my $linkage_field (@$linkage_fields_ref){
                    my $linkage_content_c = ($encoding eq "MARC-8")?marc8_to_utf8($linkage_field->as_string('c')):decode_utf8($linkage_field->as_string('c'));
                    
                    if ($linkage_content_c){
                        push @{$title_ref->{fields}{'0359'}}, {
                            content  => konv($linkage_content_c),
                            subfield => '6',
                            mult     => $multcount,
                        };
                        
                        # Subfields entfernen
                        $linkage_field->delete_subfield(code => 'c');
                    }                


                    my $linkage_content_b = ($encoding eq "MARC-8")?marc8_to_utf8($linkage_field->as_string('b')):decode_utf8($linkage_field->as_string('b'));
                    
                    if ($linkage_content_b){
                        push @{$title_ref->{fields}{'0335'}}, {
                            content  => konv($linkage_content_b),
                            subfield => '6',
                            mult     => $multcount,
                        };
                        
                        # Subfields entfernen
                        $linkage_field->delete_subfield(code => 'b');
                    }
                    
                    my $linkage_content = ($encoding eq "MARC-8")?marc8_to_utf8($linkage_field->as_string()):decode_utf8($linkage_field->as_string());
                    
                    if ($linkage_content){
                        push @{$title_ref->{fields}{'0331'}}, {
                            content  => konv($linkage_content),
                            subfield => '6',
                            mult     => $multcount,
                        };
                        
                    }
                }
            }

        }

        # HST/GT
        if (0 == 1){
        foreach my $field ($record->field('245')){
            my $content_a = ($encoding eq "MARC-8")?marc8_to_utf8($field->as_string('a')):decode_utf8($field->as_string('a'));
            my $content_c = ($encoding eq "MARC-8")?marc8_to_utf8($field->as_string('c')):decode_utf8($field->as_string('c'));
            my $content_n = ($encoding eq "MARC-8")?marc8_to_utf8($field->as_string('n')):decode_utf8($field->as_string('n'));
            my $content_p = ($encoding eq "MARC-8")?marc8_to_utf8($field->as_string('p')):decode_utf8($field->as_string('p'));
            
            
            $content_p=~s/\s+\/\s+$//; # / am Ende entfernen
            
            # Teil einer Serie
            if ($content_p && $content_a){
                
                {
                    my $multcount=++$multcount_ref->{'0331'};
                    
                    push @{$title_ref->{fields}{'0331'}}, {
                        content  => konv($content_p),
                        subfield => '',
                        mult     => $multcount,
                    };
                }
                
                {
                    my $multcount=++$multcount_ref->{'0451'};
                    
                    push @{$title_ref->{fields}{'0451'}}, {
                        content  => konv($content_a),
                        subfield => '',
                        mult     => $multcount,
                    };
                }
                
                if ($content_n){
                    my $multcount=++$multcount_ref->{'0455'};
                    
                    push @{$title_ref->{fields}{'0455'}}, {
                        content  => konv($content_n),
                        subfield => '',
                        mult     => $multcount,
                    };
                }
            }
            else {
                my $multcount=++$multcount_ref->{'0331'};
                
                push @{$title_ref->{fields}{'0331'}}, {
                    content  => konv($content_a),
                    subfield => '',
                    mult     => $multcount,
                };
            }

            # Vorl. Verfasser/Koerperschaft
            if ($content_c){
                my $multcount=++$multcount_ref->{'0359'};
                
                push @{$title_ref->{fields}{'0359'}}, {
                    content  => konv($content_c),
                    subfield => '',
                    mult     => $multcount,
                };
            }
        }
    }

        # Frueherer Titel
        foreach my $field ($record->field('247')){
                
            my $content = ($encoding eq "MARC-8")?marc8_to_utf8($field->as_string()):decode_utf8($field->as_string());

            if ($content){
                my $multcount=++$multcount_ref->{'0532'};
                
                push @{$title_ref->{fields}{'0532'}}, {
                    content  => konv($content),
                    subfield => '',
                    mult     => $multcount,
                };
            }
        }
        
        # Auflage
        foreach my $field ($record->field('250')){
            my $content_a = ($encoding eq "MARC-8")?marc8_to_utf8($field->as_string('a')):decode_utf8($field->as_string('a'));

            if ($content_a){
                my $multcount=++$multcount_ref->{'0403'};
                
                push @{$title_ref->{fields}{'0403'}}, {
                    content  => konv($content_a),
                    subfield => '',
                    mult     => $multcount,
                };
            }
        }

        # Massstab
        foreach my $field ($record->field('255')){
            my $content_a = ($encoding eq "MARC-8")?marc8_to_utf8($field->as_string('a')):decode_utf8($field->as_string('a'));

            if ($content_a){
                my $multcount=++$multcount_ref->{'0407'};
                
                push @{$title_ref->{fields}{'0407'}}, {
                    content  => konv($content_a),
                    subfield => '',
                    mult     => $multcount,
                };
            }
        }
        
        # Verlag/Verlagsort/Jahr
        foreach my $field ($record->field('260')){
            my $content_a = ($encoding eq "MARC-8")?marc8_to_utf8($field->as_string('a')):decode_utf8($field->as_string('a'));
            my $content_b = ($encoding eq "MARC-8")?marc8_to_utf8($field->as_string('b')):decode_utf8($field->as_string('b'));
            my $content_c = ($encoding eq "MARC-8")?marc8_to_utf8($field->as_string('c')):decode_utf8($field->as_string('c'));
            my $content_e = ($encoding eq "MARC-8")?marc8_to_utf8($field->as_string('e')):decode_utf8($field->as_string('e'));
            my $content_f = ($encoding eq "MARC-8")?marc8_to_utf8($field->as_string('f')):decode_utf8($field->as_string('f'));

            # Verlagsort
            if ($content_a){
                my $multcount=++$multcount_ref->{'0410'};
                
                push @{$title_ref->{fields}{'0410'}}, {
                    content  => konv($content_a),
                    subfield => '',
                    mult     => $multcount,
                };
            }

            # Verlag
            if ($content_b){
                my $multcount=++$multcount_ref->{'0412'};
                
                push @{$title_ref->{fields}{'0412'}}, {
                    content  => konv($content_b),
                    subfield => '',
                    mult     => $multcount,
                };
            }

            # Jahr
            if ($content_c){
                my $multcount=++$multcount_ref->{'0425'};
                
                push @{$title_ref->{fields}{'0425'}}, {
                    content  => konv($content_c),
                    subfield => '',
                    mult     => $multcount,
                };
            }

            # Druckort
            if ($content_e){
                my $multcount=++$multcount_ref->{'0440'};
                
                push @{$title_ref->{fields}{'0440'}}, {
                    content  => konv($content_e),
                    subfield => '',
                    mult     => $multcount,
                };

            }

            # Drucker
            if ($content_f){
                my $multcount=++$multcount_ref->{'0413'};
                
                push @{$title_ref->{fields}{'0413'}}, {
                    content  => konv($content_f),
                    subfield => '',
                    mult     => $multcount,
                };
            }
        }

        # 260 as RDA
        foreach my $field ($record->field('264')){
            my $content_a = ($encoding eq "MARC-8")?marc8_to_utf8($field->as_string('a')):decode_utf8($field->as_string('a'));
            my $content_b = ($encoding eq "MARC-8")?marc8_to_utf8($field->as_string('b')):decode_utf8($field->as_string('b'));
            my $content_c = ($encoding eq "MARC-8")?marc8_to_utf8($field->as_string('c')):decode_utf8($field->as_string('c'));

            # Verlagsort
            if ($content_a){
                my $multcount=++$multcount_ref->{'0410'};
                
                push @{$title_ref->{fields}{'0410'}}, {
                    content  => konv($content_a),
                    subfield => '',
                    mult     => $multcount,
                };
            }

            # Verlag
            if ($content_b){
                my $multcount=++$multcount_ref->{'0412'};
                
                push @{$title_ref->{fields}{'0412'}}, {
                    content  => konv($content_b),
                    subfield => '',
                    mult     => $multcount,
                };
            }

            # Jahr
            if ($content_c){
                my $multcount=++$multcount_ref->{'0425'};
                
                push @{$title_ref->{fields}{'0425'}}, {
                    content  => konv($content_c),
                    subfield => '',
                    mult     => $multcount,
                };
            }

        }
        
        # 
        foreach my $field ($record->field('300')){
            my $content_a = ($encoding eq "MARC-8")?marc8_to_utf8($field->as_string('a')):decode_utf8($field->as_string('a'));
            my $content_b = ($encoding eq "MARC-8")?marc8_to_utf8($field->as_string('b')):decode_utf8($field->as_string('b'));
            my $content_e = ($encoding eq "MARC-8")?marc8_to_utf8($field->as_string('e')):decode_utf8($field->as_string('e'));

            # Kollation
            if ($content_a){
                my $multcount=++$multcount_ref->{'0433'};

                $content_a =~s/\s+;\s*$//;
                
                push @{$title_ref->{fields}{'0433'}}, {
                    content  => konv($content_a),
                    subfield => '',
                    mult     => $multcount,
                };
            }

            # Sonst Angaben
            if ($content_b){
                my $multcount=++$multcount_ref->{'0434'};
                
                push @{$title_ref->{fields}{'0434'}}, {
                    content  => konv($content_b),
                    subfield => '',
                    mult     => $multcount,
                };
            }


            # Begleitmaterial
            if ($content_e){
                my $multcount=++$multcount_ref->{'0437'};
                
                push @{$title_ref->{fields}{'0437'}}, {
                    content  => konv($content_e),
                    subfield => '',
                    mult     => $multcount,
                };
            }
        }
        
        # Serie
        foreach my $fieldno ('440','490'){
            foreach my $field ($record->field($fieldno)){
                my $linkage = ($encoding eq "MARC-8")?marc8_to_utf8($field->as_string('6')):decode_utf8($field->as_string('6'));
                
                my $linkage_fields_ref = get_linkage_fields({ record => $record, fieldnumber => $fieldno, linkage => $linkage});

                $field->delete_subfield(code => '6'); # Linkage
                
                my $content = ($encoding eq "MARC-8")?marc8_to_utf8($field->as_string()):decode_utf8($field->as_string());
                my $content_v = ($encoding eq "MARC-8")?marc8_to_utf8($field->as_string('v')):decode_utf8($field->as_string('v'));
                
                if ($content){
                    my $multcount=++$multcount_ref->{'0451'};
                    
                    push @{$title_ref->{fields}{'0451'}}, {
                        content  => konv($content),
                        subfield => '',
                        mult     => $multcount,
                    };
                }

                foreach my $linkage_field (@$linkage_fields_ref){
                    $linkage_field->delete_subfield(code => '6'); # Linkage
                    
                    my $content = ($encoding eq "MARC-8")?marc8_to_utf8($linkage_field->as_string()):decode_utf8($linkage_field->as_string());
                    
                    if ($content){
                        my $multcount=++$multcount_ref->{'0451'};
                        
                        push @{$title_ref->{fields}{'0451'}}, {
                            content  => konv($content),
                            subfield => '',
                            mult     => $multcount,
                        };
                    }
                }
                
                
                if ($content_v){
                    my $multcount=++$multcount_ref->{'0089'};
                    
                    push @{$title_ref->{fields}{'0089'}}, {
                        content  => konv($content_v),
                        subfield => '',
                        mult     => $multcount,
                    };
                    
                    $multcount=++$multcount_ref->{'0455'};
                    
                    push @{$title_ref->{fields}{'0455'}}, {
                        content  => konv($content_v),
                        subfield => '',
                        mult     => $multcount,
                    };
                    
                }

                foreach my $linkage_field (@$linkage_fields_ref){
                    $linkage_field->delete_subfield(code => '6'); # Linkage

                    my $content_v = ($encoding eq "MARC-8")?marc8_to_utf8($linkage_field->as_string('v')):decode_utf8($linkage_field->as_string('v'));

                    if ($content_v){
                        my $multcount=++$multcount_ref->{'0089'};
                        
                        push @{$title_ref->{fields}{'0089'}}, {
                            content  => konv($content_v),
                            subfield => '',
                            mult     => $multcount,
                        };
                        
                        $multcount=++$multcount_ref->{'0455'};
                        
                        push @{$title_ref->{fields}{'0455'}}, {
                            content  => konv($content_v),
                            subfield => '',
                            mult     => $multcount,
                        };
                        
                    }
                    
                }
            }   
        }

        # Fussnote
        foreach my $field ($record->field('500')){
            my $content = ($encoding eq "MARC-8")?marc8_to_utf8($field->as_string):decode_utf8($field->as_string);

            if ($content){
                my $multcount=++$multcount_ref->{'0501'};
                
                push @{$title_ref->{fields}{'0501'}}, {
                    content  => konv($content),
                    subfield => '',
                    mult     => $multcount,
                };
            }
        }

        # HSSVermerk
        foreach my $field ($record->field('502')){
            my $content = ($encoding eq "MARC-8")?marc8_to_utf8($field->as_string):decode_utf8($field->as_string);

            if ($content){
                my $multcount=++$multcount_ref->{'0519'};
                
                push @{$title_ref->{fields}{'0519'}}, {
                    content  => konv($content),
                    subfield => '',
                    mult     => $multcount,
                };
            }
        }

        # Angaben zum Inhalt
        foreach my $field ($record->field('505')){
            my $content = ($encoding eq "MARC-8")?marc8_to_utf8($field->as_string):decode_utf8($field->as_string);

            if ($content){
                my $multcount=++$multcount_ref->{'0517'};
                
                push @{$title_ref->{fields}{'0517'}}, {
                    content  => konv($content),
                    subfield => '',
                    mult     => $multcount,
                };
            }
        }
        
        # Format
        foreach my $field ($record->field('516')){
            my $content = ($encoding eq "MARC-8")?marc8_to_utf8($field->as_string):decode_utf8($field->as_string);

            if ($content){
                my $multcount=++$multcount_ref->{'0435'};
                
                push @{$title_ref->{fields}{'0435'}}, {
                    content  => konv($content),
                    subfield => '',
                    mult     => $multcount,
                };
            }
        }

        # Angaben zum Inhalt
        foreach my $field ($record->field('520')){
            my $content = ($encoding eq "MARC-8")?marc8_to_utf8($field->as_string):decode_utf8($field->as_string);

            if ($content){
                my $multcount=++$multcount_ref->{'0517'};
                
                push @{$title_ref->{fields}{'0517'}}, {
                    content  => konv($content),
                    subfield => '',
                    mult     => $multcount,
                };
            }
        }

        # WST
        foreach my $fieldno ('720','730','740'){
            foreach my $field ($record->field($fieldno)){
                my $content = ($encoding eq "MARC-8")?marc8_to_utf8($field->as_string):decode_utf8($field->as_string);
                
                if ($content){
                    my $multcount=++$multcount_ref->{'0370'};
                    
                    push @{$title_ref->{fields}{'0370'}}, {
                        content  => konv($content),
                        subfield => '',
                        mult     => $multcount,
                    };
                }
            }
        }

        # URLs
        foreach my $field ($record->field('856')){
            my @content_u = $field->subfield('u');
            my @content_z = $field->subfield('z');
            for (my $idx=0;$idx <= $#content_u; $idx++){
                my $content_u_string = ($encoding eq "MARC-8")?marc8_to_utf8($content_u[$idx]):decode_utf8($content_u[$idx]);

                my $content_z_string = "" ;

                if ($content_z[$idx]){
                    $content_z_string = ($encoding eq "MARC-8")?marc8_to_utf8($content_z[$idx]):decode_utf8($content_z[$idx]);
                }
            
                if ($content_u_string){
                    my $multcount=++$multcount_ref->{'0662'};
                    
                    push @{$title_ref->{fields}{'0662'}}, {
                        content  => $content_u_string,
                        subfield => '',
                        mult     => $multcount,
                    };
                    
                    if ($content_z_string){
                        push @{$title_ref->{fields}{'0663'}}, {
                            content  => konv($content_z_string),
                            subfield => '',
                            mult     => $multcount,
                        };
                    }
                }
            }
        }

    }

    { # Exemplardaten
        foreach my $field ($record->field('852')){
            my $content_a = ($encoding eq "MARC-8")?marc8_to_utf8($field->as_string('a')):decode_utf8($field->as_string('a'));
            my $content_i = ($encoding eq "MARC-8")?marc8_to_utf8($field->as_string('i')):decode_utf8($field->as_string('i'));

            my $holding_ref = {
                'id'     => $mexid++,
                'fields' => {
                    '0004' =>
                        [
                            {
                                mult     => 1,
                                subfield => '',
                                content  => $title_ref->{id},
                        },
                    ],
                },
            };

            push @{$holding_ref->{fields}{'0016'}}, {
                content  => konv($content_a),
                subfield => '',
                mult     => 1,
            };

            push @{$holding_ref->{fields}{'0014'}}, {
                content  => konv($content_i),
                subfield => '',
                mult     => 1,
            };

            print HOLDING encode_json $holding_ref,"\n";
        }
    }

    if ($configfile && $convconfig->{exclude}{by_availability}){
        my $key_field = $convconfig->{exclude}{by_availability}{field};
        
        my @keys = ();
        foreach my $item_ref (@{$title_ref->{fields}{$key_field}}){
            push @keys, $item_ref->{content};
        }
        
        my $databases_ref = $convconfig->{exclude}{by_availability}{databases};
        my $locations_ref = $convconfig->{exclude}{by_availability}{locations};
        
        if ($enrichmnt->check_availability_by_isbn({isbn => \@keys, databases => $databases_ref, locations => $locations_ref })){
            $logger->info("Titel mit ISBNs ".join(' ',@keys)." bereits an Standorten ".join(' ',@$locations_ref)." vorhanden!");
            $excluded_titles++;
            next;
        }        
    }

    if ($configfile && $convconfig->{exclude}{by_isbn_in_file}){
        my $key_field = $convconfig->{exclude}{by_isbn_in_file}{field};
        
        my $in_file = 0;
        my @keys = ();
        foreach my $item_ref (@{$title_ref->{fields}{$key_field}}){
            my $isbn13 = OpenBib::Common::Util::to_isbn13($item_ref->{content});
            push @keys, $isbn13 if ($isbn13);

            if (defined $exclude_by_isbn_in_file_ref->{$isbn13} && $exclude_by_isbn_in_file_ref->{$isbn13}){
                $in_file = 1;
            }
        }
        
        if ($in_file){
            $logger->info("Titel mit ISBNs ".join(' ',@keys)." ueber ISBN in Negativ-Datei ausgeschlossen");
            $excluded_titles++;
            next;
        }        
    }
    
    print TITLE encode_json $title_ref, "\n";
    
    $logger->debug(encode_json $title_ref);
        
    if ( my @warnings = $batch->warnings() ) {
        $logger->error(join(' ; ',@warnings));
    }

    if ($count % 10000 == 0){
        $logger->info("$count titles done");
    }

    
    $count++;
    
}

$logger->info("$all_count titles done");
$logger->info("$count titles survived");
$logger->info("Excluded titles: $excluded_titles");

close(TITLE);
close(PERSON);
close(CORPORATEBODY);
close(CLASSIFICATION);
close(SUBJECT);
close(HOLDING);

close(DAT);

sub konv {
    my $content = shift;

    $content=~s/\s*[.,:\/]\s*$//g;
    $content=~s/&/&amp;/g;
    $content=~s/</&lt;/g;
    $content=~s/>/&gt;/g;
    # Buchstabenersetzungen Grundbuchstabe plus Diaeresis
    $content=~s/u\x{0308}/ü/g;
    $content=~s/a\x{0308}/ä/g;
    $content=~s/o\x{0308}/ö/g;
    $content=~s/U\x{0308}/Ü/g;
    $content=~s/A\x{0308}/Ä/g;
    $content=~s/O\x{0308}/Ö/g;

    return $content;
}

sub get_linkage_fields {
    my $arg_ref = shift;

    my $fieldnumber = exists $arg_ref->{fieldnumber}
        ? $arg_ref->{fieldnumber}             : undef;

    my $record      = exists $arg_ref->{record}
        ? $arg_ref->{record}                  : undef;

    my $linkage     = exists $arg_ref->{linkage}
        ? $arg_ref->{linkage}                 : undef;


    my $encoding = $record->encoding();
    
    my $linkage_fields_ref = [];
    
    my ($linkage_fieldnumber,$linkage_count) = $linkage =~m/^(\d\d\d)-(\d+)/;

    foreach my $thislinkage_field ($record->field($linkage_fieldnumber)){
        my $thiscontent_6 = ($encoding eq "MARC-8")?marc8_to_utf8($thislinkage_field->as_string('6')):decode_utf8($thislinkage_field->as_string('6'));            
        
        my ($thislinkage_fieldnumber,$thislinkage_count) = $thiscontent_6 =~m/^(\d\d\d)-(\d+)/;

        next unless (defined $thislinkage_fieldnumber);
        
        if ($thislinkage_fieldnumber == $fieldnumber && $thislinkage_count == $linkage_count){
            push @{$linkage_fields_ref}, $thislinkage_field;
        }
    }

    return $linkage_fields_ref;
}

sub add_subject {
    my $content = shift;
    my $title_ref = shift;
    
    my ($subject_id,$new) = OpenBib::Conv::Common::Util::get_subject_id($content);
    
    if ($new){
        my $item_ref = {
            'fields' => {},
        };
        $item_ref->{id} = $subject_id;
        push @{$item_ref->{fields}{'0800'}}, {
            mult     => 1,
            subfield => '',
            content  => konv($content),
        };
        
        print SUBJECT encode_json $item_ref, "\n";
    }
    
    my $multcount=++$multcount_ref->{'0710'};
    
    push @{$title_ref->{fields}{'0710'}}, {
        mult       => $multcount,
        subfield   => '',
        id         => $subject_id,
        supplement => '',
    };

    return $title_ref;
}

sub add_person {
    my ($content_a,$content_c,$content_d,$title_ref) = @_;
    
    my ($person_id,$new) = OpenBib::Conv::Common::Util::get_person_id($content_a);
    
    if ($new){
        my $item_ref = {
            'fields' => {},
                        };
                        $item_ref->{id} = $person_id;
        
        push @{$item_ref->{fields}{'0800'}}, {
            mult     => 1,
            subfield => '',
            content  => konv($content_a),
        };
        
        # Beruf
        if ($content_c){
            push @{$item_ref->{fields}{'0201'}}, {
                mult     => 1,
                subfield => '',
                content  => konv($content_c),
            };
        }
        
        
        # Lebensjahre
        if ($content_d){
            push @{$item_ref->{fields}{'0200'}}, {
                mult     => 1,
                subfield => '',
                content  => konv($content_d),
            };
        }
        
        
        print PERSON encode_json $item_ref, "\n";
    }
    
    my $multcount=++$multcount_ref->{'0100'};
    
    push @{$title_ref->{fields}{'0100'}}, {
        mult       => $multcount,
        subfield   => '',
        id         => $person_id,
        supplement => '',
    };
    
    return $title_ref;
}
