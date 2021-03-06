#!/usr/bin/perl

#####################################################################
#
#  authority2xapian.pl
#
#  Dieses File ist (C) 2013-2017 Oliver Flimm <flimm@openbib.org>
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
use utf8;

BEGIN {
#    $ENV{XAPIAN_PREFER_CHERT}    = '1';
    $ENV{XAPIAN_FLUSH_THRESHOLD} = $ENV{XAPIAN_FLUSH_THRESHOLD} || '200000';
}

use Benchmark ':hireswallclock';
use DB_File;
use DBI;
use Encode qw(decode_utf8 encode_utf8);
use MLDBM qw(DB_File Storable);
use Storable ();
use Getopt::Long;
use JSON::XS;
use Log::Log4perl qw(get_logger :levels);
use Search::Xapian;
use YAML::Syck;
use OpenBib::Config;
use OpenBib::Index::Factory;
use OpenBib::Common::Util;

use DBIx::Class::ResultClass::HashRefInflator;

my ($database,$help,$logfile,$withsorting,$withpositions,$loglevel,$indexpath,$incremental,$authtype);

&GetOptions(
    "indexpath=s"       => \$indexpath,
    "database=s"        => \$database,
    "logfile=s"       => \$logfile,
    "loglevel=s"      => \$loglevel,
    "with-sorting"    => \$withsorting,
    "with-positions"  => \$withpositions,
    "incremental"     => \$incremental,
    "help"            => \$help
);

if ($help){
    print_help();
}

$logfile=($logfile)?$logfile:"/var/log/openbib/authority2xapian/${database}.log";
$loglevel=($loglevel)?$loglevel:"INFO";

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

if (!-d "/var/log/openbib/authority2xapian/"){
    mkdir "/var/log/openbib/authority2xapian/";
}

Log::Log4perl::init(\$log4Perl_config);

# Log4perl logger erzeugen
my $logger = get_logger();

my $config  = new OpenBib::Config();
my $rootdir = $config->{'autoconv_dir'};

if (!$database){
  $logger->fatal("Kein Pool mit --database= ausgewaehlt");
  exit;
}

my @tpro = (
    'Autogramm',
    'Einlage',
    'Exlibris',
    'gedr. Besitzvermerk',
    'hs. Besitzvermerk',
    'Stempel',
    'Supralibros',
    'Widmung',
    );

$indexpath=($indexpath)?$indexpath:$config->{xapian_index_base_path}."/".$database."_authority";

my $FLINT_BTREE_MAX_KEY_LEN = $config->{xapian_option}{max_key_length};

my @authority_files = (
    {
        type     => "title",
        filename => "$rootdir/pools/$database/meta.title.gz",
    },
    {
        type     => "person",
        filename => "$rootdir/pools/$database/meta.person.gz",
    },
    {
        type     => "corporatebody",
        filename => "$rootdir/pools/$database/meta.corporatebody.gz",
    },
    {
        type     => "subject",
        filename => "$rootdir/pools/$database/meta.subject.gz",
    },
);

my $conv_config = new OpenBib::Conv::Config({dbname => $database});

$logger->info(YAML::Dump($conv_config));

# Ueberschreibung fuer Titelkategorien:
$logger->info("### POOL $database");

$logger->info("Loeschung des alten Index fuer Datenbank $database");
    
system("rm $indexpath/*");

my $atime = new Benchmark;

my $indexer = OpenBib::Index::Factory->create_indexer({ database => $database, create_index => 1, index_type => 'readwrite', index_path => $indexpath });

$indexer->set_stopper;
$indexer->set_termgenerator;


if (! -d "$rootdir/data/$database"){
    system("mkdir $rootdir/data/$database");
}

my $inverted_ref  = $conv_config->{inverted_authority_title};

my $valid_person_id_ref = {};
my $valid_corporatebody_id_ref = {};
my $valid_subject_id_ref = {};

foreach my $authority_file_ref (@authority_files){
    
    my $type            = $authority_file_ref->{type};
    my $source_filename = $authority_file_ref->{filename};
    my $dest_filename   = "authority_meta.$type";

    if (-f $source_filename){
        my $atime = new Benchmark;

        # Entpacken der Pool-Daten in separates Arbeits-Verzeichnis unter 'data'

        $logger->info("### $database: Entpacken der Authority-Daten fuer Typ $type");
                
        system("rm $rootdir/data/$database/authority_*");
        system("/bin/gzip -dc $source_filename > $rootdir/data/$database/$dest_filename");
        
        my $btime      = new Benchmark;
        my $timeall    = timediff($btime,$atime);
        my $resulttime = timestr($timeall,"nop");
        $resulttime    =~s/(\d+\.\d+) .*/$1/;
        
        $logger->info("### $database: Benoetigte Zeit -> $resulttime");
        
        if ($database && -e "$config->{autoconv_dir}/filter/$database/authority_pre_conv_$type.pl"){
            $logger->info("### $database: Verwende Plugin authority_pre_conv_$type.pl");
            system("$config->{autoconv_dir}/filter/$database/authority_pre_conv_$type.pl $database");
        }
        
        $logger->info("### POOL $database - ".$type);
        
        my $fieldprefix = ($authority_file_ref->{type} eq "person")?"P":
            ($authority_file_ref->{type} eq "subject")?"S":
                ($authority_file_ref->{type} eq "corporatebody")?"C":
                ($authority_file_ref->{type} eq "title")?"T":
		($authority_file_ref->{ty pe} eq "holding")?"X":"";
        next unless ($fieldprefix);
        
        open(SEARCHENGINE,"cat $rootdir/data/$database/$dest_filename |" ) || die "$rootdir/data/$database/$dest_filename konnte nicht geoeffnet werden";
        
        {
            $logger->info("Aufbau eines neuen temporaeren Index fuer Datenbank $database");
            
            
            $logger->info("Migration der Normdaten");
            
            my $count = 1;
            
            {

		my %habe_provenienzmerkmal = ();
                
                my $atime = new Benchmark;
                
                while (my $searchengine=<SEARCHENGINE>) {

                    my $auth_ref = decode_json($searchengine);

		    my $id         = $auth_ref->{id};
                    my $fields_ref = $auth_ref->{fields};
		    
		    next if ($type eq "person" && !$valid_person_id_ref->{$id});
		    next if ($type eq "corporatebody" && !$valid_corporatebody_id_ref->{$id});
		    next if ($type eq "subject" && !$valid_subject_id_ref->{$id});

                    # Initialisieren und Basisinformationen setzen
                    my $document = OpenBib::Index::Document->new({ database => $database, id => $auth_ref->{id} });

                    $document->set_data("type",$authority_file_ref->{type});

		    # 1st Pass: enrich fields

                    foreach my $field (keys %{$fields_ref}){
			# Ansetzungsformen muessen aus der Datenbank geholt werden, da nicht in meta.title enthalten.
			if ($type eq "title"){

			    $logger->info("Processing title field $field");
			    
			    if ($field eq "4307"){ # Koerperschaft
				foreach my $item_ref (@{$fields_ref->{$field}}){
				    $valid_corporatebody_id_ref->{$item_ref->{id}} = 1;
				}

			    }
			    elsif ($field eq "4306"){ # Sammlung/Subject
				foreach my $item_ref (@{$fields_ref->{$field}}){
				    $valid_subject_id_ref->{$item_ref->{id}} = 1;
				}

			    }
			    elsif ($field eq "4308"){ # Person
				foreach my $item_ref (@{$fields_ref->{$field}}){
				    $valid_person_id_ref->{$item_ref->{id}} = 1;
				}

			    }
			    elsif ($field eq "4310"){ # Merkmal
				my $filtered_fields_ref = [];
				foreach my $item_ref (@{$fields_ref->{$field}}){
				    if (defined $habe_provenienzmerkmal{$item_ref->{content}}){
					next;
				    }
				    else {
					push @{$filtered_fields_ref}, $item_ref;
					$habe_provenienzmerkmal{$item_ref->{content}} = 1;
				    }
				}
				$fields_ref->{$field} = $filtered_fields_ref;

				my $mult = 1;
				$fields_ref->{'0700'} = [];
				foreach my $item_ref (@{$fields_ref->{'4310'}}){
				    foreach my $merkmal (@tpro){
					if ($item_ref->{content} =~m/$merkmal/){
					    push @{$fields_ref->{'0700'}}, {
						mult     => $mult,
						subfield => '',
						content  => $merkmal,
					    };
					    $mult++;
					}
				    }
				}
				
				$fields_ref->{'4410'} = [
				    {
					mult     => 1,
					subfield => '',
					content  => "T-PRO Besitzkennzeichen",
				    },
				    ];
				
			    }

			}			
			elsif ($type eq "person"){
				$fields_ref->{'4410'} = [
				    {
					mult     => 1,
					subfield => '',
					content  => "Provenienz Person",
				    },
				    ];

			}
			elsif ($type eq "corporatebody"){
				$fields_ref->{'4410'} = [
				    {
					mult     => 1,
					subfield => '',
					content  => "Provenienz Körperschaft",
				    },
				    ];
				
			}
			elsif ($type eq "subject"){
				$fields_ref->{'4410'} = [
				    {
					mult     => 1,
					subfield => '',
					content  => "Provenienz Sammlung",
				    },
				    ];
				
			}
		    }
		    
                    foreach my $field (keys %{$fields_ref}){

                        $document->set_data("$fieldprefix$field",$fields_ref->{$field});

			if ($logger->is_debug){
			    $logger->debug("Fields for type $type: ".YAML::Dump($fields_ref));
			}
			# Facettierung
			foreach my $searchfield (keys %{$conv_config->{"inverted_authority_".$authority_file_ref->{type}}{$field}->{facet}}) {
				next unless (defined $fields_ref->{$field});
				
				foreach my $item_ref (@{$fields_ref->{$field}}) {
				    next unless ($item_ref->{content});
				    $logger->debug("Adding Facet facet_$searchfield for ".$item_ref->{content});
				    
				    $document->add_facet("facet_$searchfield", $item_ref->{content});        
				}
			}
			

			# Indexierung
                        foreach my $searchfield (keys %{$conv_config->{"inverted_authority_".$authority_file_ref->{type}}{$field}->{index}}) {
                            my $weight = $conv_config->{"inverted_authority_".$authority_file_ref->{type}}{$field}->{index}{$searchfield};

#                            my $have_term_ref = {};
                            foreach my $item_ref (@{$fields_ref->{$field}}){
                                next unless $item_ref->{content};
#				next if (defined $have_term_ref->{$item_ref->{content}});
				$logger->info("indexing ".$item_ref->{content}." for searchfield $searchfield with weight $weight") if ($type eq "title");
				
                                $document->add_index($searchfield,$weight, ["$fieldprefix$field",$item_ref->{content}]);
#				$have_term_ref->{$item_ref->{content}} = 1;
                            }
                        }

                    }

                    if ($logger->is_debug){
			$logger->debug(YAML::Dump($document->get_document()))
		    }
		    
                    my $doc = $indexer->create_document({ document => $document, with_sorting => $withsorting, with_positions => $withpositions });

                    $indexer->create_record($doc);
                    
                    if ($count % 1000 == 0) {
                        my $btime      = new Benchmark;
                        my $timeall    = timediff($btime,$atime);
                        my $resulttime = timestr($timeall,"nop");
                        $resulttime    =~s/(\d+\.\d+) .*/$1/;
                        $atime         = new Benchmark;
                        $logger->info("$database: $count Saetze indexiert in $resulttime Sekunden");
                    }
                    
                    $count++;
                }
            }
        }
        
        close(SEARCHENGINE);
    }
    
}



my $btime      = new Benchmark;
my $timeall    = timediff($btime,$atime);
my $resulttime = timestr($timeall,"nop");
$resulttime    =~s/(\d+\.\d+) .*/$1/;

$logger->info("Gesamtzeit: $resulttime Sekunden");

sub print_help {
    print << "ENDHELP";
authority2xapian.pl - Aufbau eines Xapian-Index für die Normdaten von Provenienzen

   Optionen:
   -help                 : Diese Informationsseite
       
   -with-fields          : Integration von einzelnen Suchfeldern (nicht default)
   -with-sorting         : Integration von Sortierungsinformationen (nicht default)
   -with-positions       : Integration von Positionsinformationen(nicht default)
   --database=...        : Angegebenen Datenpool verwenden

ENDHELP
    exit;
}
