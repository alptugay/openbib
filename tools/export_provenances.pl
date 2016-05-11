#!/usr/bin/perl
#####################################################################
#
#  export_provenances..pl
#
#  Export der Provenienzen in ein JSON-Format
#
#  Dieses File ist (C) 2015-2016 Oliver Flimm <flimm@openbib.org>
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

use strict;
use warnings;
no warnings 'redefine';
use utf8;

use Encode 'decode_utf8';
use Log::Log4perl qw(get_logger :levels);
use Benchmark ':hireswallclock';
use DBI;
use DBIx::Class::ResultClass::HashRefInflator;
use Getopt::Long;
use JSON::XS qw/encode_json/;
use YAML;
use POSIX qw/strftime/;

use OpenBib::Config;
use OpenBib::Catalog::Factory;
use OpenBib::Common::Util;
use OpenBib::Statistics;
use OpenBib::Search::Util;

my $config     = OpenBib::Config->new;

my ($database,$help,$logfile,$filename);

&GetOptions("database=s"      => \$database,
            "logfile=s"       => \$logfile,
            "filename=s"      => \$filename,
	    "help"            => \$help
	    );

if ($help){
    print_help();
}

$logfile=($logfile)?$logfile:"/var/log/openbib/export_provenances.log";
$filename=($filename)?$filename:"provenances_$database.json";

my $log4Perl_config = << "L4PCONF";
log4perl.rootLogger=ERROR, LOGFILE, Screen
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

$logger->info("Exporting provenances to JSON");

my $catalog = OpenBib::Catalog::Factory->create_catalog({ database => $database});

open(OUT,">$filename");

my $titles_with_provenances = $catalog->get_schema->resultset('TitleField')->search(
    {
        'field'   => '4309',
    },
    {
        column   => ['titleid'],
        group_by => ['titleid','id','mult','content'],
        result_class => 'DBIx::Class::ResultClass::HashRefInflator',
    }
);

my $provenances_count = 0;

my $title_done_ref = {};

foreach my $title ($titles_with_provenances->all){
    my $titleid = $title->{titleid};

    next if (defined $title_done_ref->{$titleid});

    my $record = OpenBib::Record::Title->new({ database => $database, id => $titleid})->load_full_record;

    my $hbzid  = $record->get_field({ field => 'T0010', mult => 1});
    
    $logger->debug("Record: ".YAML::Dump($record->get_fields));
    
    my $provenances_ids_ref = [];
    foreach my $field_ref (@{$record->get_field({field => 'T4309'})}){
 #       $logger->debug("Record-Field: ".YAML::Dump($field_ref));
        push @$provenances_ids_ref, $field_ref->{mult};
    }

#    $logger->debug("Mult: ".YAML::Dump($provenances_ids_ref));
    
    foreach my $mult (@$provenances_ids_ref){
        my $provenance_ref = {};

        my $medianumber   = $record->get_field({ field => 'T4309', mult => $mult});
        my $description   = $record->get_field({ field => 'T4310', mult => $mult});
        my $sigel         = $record->get_field({ field => 'T4311', mult => $mult});
        my $incomplete    = $record->get_field({ field => 'T4312', mult => $mult});
        my $reference     = $record->get_field({ field => 'T4313', mult => $mult});
        my $former_mark   = $record->get_field({ field => 'T4314', mult => $mult});

        # Mark from Holdings

        my $current_mark = "";
        foreach my $holding_ref (@{$record->get_holding}){
            my $this_medianumber = $holding_ref->{X0010}{content};
            $this_medianumber =~s/# $//;
            if ($this_medianumber eq $medianumber){
                $current_mark = $holding_ref->{X0014}{content};
            }
        }

        # GND for collections

        my $collection_gnd = "";

        if ($record->has_field('T4306')){
            foreach my $field_ref (@{$record->get_field({ field => 'T4306'})}){
                if ($field_ref->{mult} eq $mult){
                    my $subject = OpenBib::Record::Subject->new({database => $database, id => $field_ref->{id}})->load_full_record;
                    
                    my $this_subject_gnd = $subject->get_field({field => 'S0010', mult => 1});

                    next unless (defined $this_subject_gnd);

                    ($collection_gnd) = $this_subject_gnd =~/.DE-588.(.+)$/;
            }
            }
        }

        # GND for corporate bodies

        my $corp_gnd = "";

        if ($record->has_field('T4307')){                    
            foreach my $field_ref (@{$record->get_field({ field => 'T4307'})}){
                if ($field_ref->{mult} eq $mult){
                    my $corp = OpenBib::Record::CorporateBody->new({database => $database, id => $field_ref->{id}})->load_full_record;
                    
                    my $this_corp_gnd = $corp->get_field({field => 'C0010', mult => 1});

                    next unless (defined $this_corp_gnd);
                    
                    ($corp_gnd) = $this_corp_gnd =~/.DE-588.(.+)$/;
                }
            }
        }
        
        # GND for Persons

        my $person_gnd = "";

        if ($record->has_field('T4308')){

            $logger->debug("Personen: ".YAML::Dump($record->get_field({field => 'T4308'})));
            
            foreach my $field_ref (@{$record->get_field({ field => 'T4308'})}){
                if ($field_ref->{mult} eq $mult){

                    my $person = OpenBib::Record::Person->new({database => $database, id => $field_ref->{id}})->load_full_record;
                    
                    my $this_person_gnd = $person->get_field({field => 'P0010', mult => 1});

                    next unless (defined $this_person_gnd);
                    
                    $logger->debug("Person-ID: ".$person->get_id." - $this_person_gnd");
                    
                    ($person_gnd) = $this_person_gnd =~/.DE-588.(.+)$/;
                }
            }
        }
        
        $provenance_ref->{hbzid}        = $hbzid if ($hbzid);
        $provenance_ref->{medianumber}  = $medianumber if ($medianumber);
        $provenance_ref->{tpro_description}  = $description if ($description);
        $provenance_ref->{sigel}        = $sigel if ($sigel);
        $provenance_ref->{incomplete}   = $incomplete if ($incomplete);
        $provenance_ref->{reference}    = $reference  if ($reference);
        $provenance_ref->{former_mark}  = $former_mark  if ($former_mark);
        $provenance_ref->{current_mark} = $current_mark  if ($current_mark);
        $provenance_ref->{collection_gnd}   = $collection_gnd  if ($collection_gnd);
        $provenance_ref->{corporatebody_gnd}   = $corp_gnd  if ($corp_gnd);
        $provenance_ref->{person_gnd}   = $person_gnd  if ($person_gnd);

        print OUT encode_json $provenance_ref, "\n" if ($corp_gnd || $person_gnd || $collection_gnd);
    }

    $title_done_ref->{$titleid} = 1;
}


close(OUT);

$logger->info("$provenances_count provenances exported");

sub print_help {
    print << "ENDHELP";
export_provenances.pl - Export der Provenienzen in ein JSON-Format


   Optionen:
   -help                 : Diese Informationsseite
       
   --database=inst001    : Datenbankname (USB=inst001)


ENDHELP
    exit;
}

