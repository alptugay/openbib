#!/usr/bin/perl
#####################################################################
#
#  get_usb_ebook_isbns.pl
#
#  Bestimmung aller ISBNs, die zu USB-E-Books gehoeren
#
#  Dieses File ist (C) 2013 Oliver Flimm <flimm@openbib.org>
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

use Business::ISBN;
use Encode 'decode_utf8';
use Log::Log4perl qw(get_logger :levels);
use Benchmark ':hireswallclock';
use DBI;
use DBIx::Class::ResultClass::HashRefInflator;
use Getopt::Long;
use YAML;
use POSIX qw/strftime/;

use OpenBib::Config;
use OpenBib::Catalog::Factory;
use OpenBib::Common::Util;
use OpenBib::Statistics;
use OpenBib::Search::Util;

my $config     = OpenBib::Config->new;

my ($database,$help,$logfile);

&GetOptions("database=s"      => \$database,
            "logfile=s"       => \$logfile,
	    "help"            => \$help
	    );

if ($help){
    print_help();
}

$logfile=($logfile)?$logfile:"/var/log/openbib/get_usb_ebook_isbns.log";

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

# Haeufigkeit von ISBNs im KUG:
# select isbn,count(dbname) as dbcount from all_isbn group by isbn order by dbcount desc limit 10

my $last_insertion_date = 0; # wird fuer inkrementelles Update benoetigt

$logger->info("Getting ISBNs from database $database");

my $catalog = OpenBib::Catalog::Factory->create_catalog({ database => $database});

open(ISBNOUT,">online_isbns_$database.txt");

my $online = $catalog->get_schema->resultset('TitleField')->search(
    {
        'field'   => '4400',
        'content' => 'online',
    },
    {
        select => ['titleid'],
        as     => ['thistitleid'],
        group_by => ['titleid'],
    }
);

my $isbn_insertcount = 0;

my $all_isbns = $catalog->get_schema->resultset('Title')->search_rs(
    {
        'me.id'    => { -in => $online->as_query },
        -or   => [
            'title_fields.field' => '0540',
            'title_fields.field' => '0541',
            'title_fields.field' => '0553',
            'title_fields.field' => '0634',
        ],
    },
    {
        select => ['title_fields.content'],
        as     => ['thisisbn'],
        group_by => ['title_fields.content'],
        join   => ['title_fields'],
	result_class => 'DBIx::Class::ResultClass::HashRefInflator',
    }
);

foreach my $item ($all_isbns->all){
    my $thisisbn = $item->{'thisisbn'};

    print ISBNOUT $thisisbn,"\n";
    
    $isbn_insertcount++;
}

close(ISBNOUT);

$logger->info("$isbn_insertcount ISBN's found");

sub print_help {
    print << "ENDHELP";
get_usb_ebook_isbns.pl - Bestimmung der ISBN's zu E-Books die im jeweiligen Katalog nachgewiesen sind.


   Optionen:
   -help                 : Diese Informationsseite
       
   --database=inst001    : Datenbankname (USB=inst001)


ENDHELP
    exit;
}

