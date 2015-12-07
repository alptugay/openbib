#!/usr/bin/perl

#####################################################################
#
#  ugc-migrations-korrektur.pl
#
#  Korrektur des User Generated Contents (Literaturlisten, Merklisten, Tags)
#  von Titeln, die aus einem Instituts- in den USB-Katalog migriert wurden
#
#  Dieses File ist (C) 2015 Oliver Flimm <flimm@openbib.org>
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

use OpenBib::Config;
use OpenBib::Enrichment;
use OpenBib::Record::Title;
use OpenBib::RecordList::Title;

use Business::ISBN;
use DBIx::Class::ResultClass::HashRefInflator;
use Encode 'decode_utf8';
use Log::Log4perl qw(get_logger :levels);
use Benchmark ':hireswallclock';
use DBI;
use Getopt::Long;
use YAML::Syck;

my $config      = OpenBib::Config->new;

my ($sourcedatabase,$targetdatabase,$masterdatabase,$targetlocation,$help,$logfile);

&GetOptions("source-database=s"     => \$sourcedatabase,
            "target-database=s"     => \$targetdatabase,
            "target-location=s"     => \$targetlocation,
            "master-database=s"     => \$masterdatabase,
            "logfile=s"              => \$logfile,
	    "help"                   => \$help
	    );

if ($help || !$sourcedatabase || !$targetdatabase || !$masterdatabase){
    print_help();
}

$logfile=($logfile)?$logfile:'/var/log/openbib/ugc-migrations-korrektur.log';

my $log4Perl_config = << "L4PCONF";
log4perl.rootLogger=INFO, LOGFILE, Screen
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

my $enrichmnt = new OpenBib::Enrichment;

$logger->info("1. Durchgang: Gezieltes Sammeln von Informationen fuer $sourcedatabase");

my $litlist_titles = $config->get_schema->resultset('Litlistitem')->search(
    {
        dbname => $sourcedatabase,
    },
    {
        column       => [ qw/titleid/ ],
        result_class => 'DBIx::Class::ResultClass::HashRefInflator',
    }
);

my @source_titleids = ();

while (my $litlist_title = $litlist_titles->next()){
    push @source_titleids, $litlist_title->{titleid};
}

$logger->info("Source Titleids: ".YAML::Dump(\@source_titleids));

my $sourcetitle_bibkeys = $enrichmnt->get_schema->resultset('AllTitleByBibkey')->search(
    {
        dbname  => $sourcedatabase,
        titleid => { -in => \@source_titleids },
    },
    {
        column       => [ qw/bibkey titleid/ ],
    }
);

my $bibkey_sourcetitle_ref = {};
my $have_bibkey_ref        = {};

while (my $sourcetitle_bibkey = $sourcetitle_bibkeys->next()){
    my $bibkey  = $sourcetitle_bibkey->bibkey;
    my $titleid = $sourcetitle_bibkey->titleid;
    $have_bibkey_ref->{$titleid} = 1;
    $bibkey_sourcetitle_ref->{$bibkey} = $titleid;
}

my @remaining_titleids = ();

foreach my $titleid (@source_titleids){
    if (!defined $have_bibkey_ref->{$titleid}){
        push @remaining_titleids, $titleid;
    }
}

$logger->info("Source Titleids ohne Bibkey: ".YAML::Dump(\@remaining_titleids));

my @source_bibkeys = keys %$bibkey_sourcetitle_ref;

$logger->info("Source Bibkeys: ".YAML::Dump(\@source_bibkeys));

my $targettitle_bibkeys = $enrichmnt->get_schema->resultset('AllTitleByBibkey')->search(
    {
        dbname  => $targetdatabase,
        bibkey  => { -in => \@source_bibkeys },
    },
    {
        column       => [ qw/bibkey titleid/ ],
    }
);

my $bibkey_targettitle_ref = {};

while (my $targettitle_bibkey = $targettitle_bibkeys->next()){
    my $target_record = OpenBib::Record::Title->new({id => $targettitle_bibkey->titleid, database => $targetdatabase})->load_full_record;

    my $target_location_is_ok = 0;
    foreach my $holding_ref (@{$target_record->get_holding}){
        if ($holding_ref->{X0016}{content} eq $targetlocation){
            $bibkey_targettitle_ref->{$targettitle_bibkey->bibkey} = $targettitle_bibkey->titleid;
        }
    }
}

my @target_bibkeys = keys %$bibkey_targettitle_ref;

$logger->info("Source Bibkeys: ".YAML::Dump(\@target_bibkeys));

foreach my $target_bibkey (@target_bibkeys){
    my $sourceid;
    my $targetid = $bibkey_targettitle_ref->{$target_bibkey};

    if (defined $bibkey_sourcetitle_ref->{$target_bibkey}){
        $sourceid = $bibkey_sourcetitle_ref->{$target_bibkey};
    }

    if ($targetid && $sourceid){
        my $sourcetitle = OpenBib::Record::Title->new({id => $sourceid, database => $sourcedatabase})->load_full_record;
        my $targettitle = OpenBib::Record::Title->new({id => $targetid, database => $targetdatabase})->load_full_record;

        print "$sourcedatabase:$sourceid -> $targetdatabase:$targetid\n";
        print YAML::Dump($sourcetitle->get_fields),"\n";
        print YAML::Dump($targettitle->get_fields),"\n";
        print "----------------------------------------------\n";
    }
    
}


