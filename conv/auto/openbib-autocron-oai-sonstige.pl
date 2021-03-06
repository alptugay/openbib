#!/usr/bin/perl

#####################################################################
#
#  openbib-autocron.pl
#
#  CRON-Job zum automatischen aktualisieren aller OpenBib-Datenbanken
#
#  Dieses File ist (C) 1997-2014 Oliver Flimm <flimm@openbib.org>
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
use threads;
use threads::shared;

use Getopt::Long;
use Log::Log4perl qw(get_logger :levels);
use OpenBib::Config;

our ($logfile,$loglevel,$test,$cluster,$maintenance,$updatemaster);

&GetOptions(
    "cluster"       => \$cluster,
    "test"          => \$test,
    "maintenance"   => \$maintenance,
    "logfile=s"     => \$logfile,
    "loglevel=s"    => \$loglevel,
    "update-master" => \$updatemaster,
    );

my $config = OpenBib::Config->new;

$logfile=($logfile)?$logfile:"/var/log/openbib/openbib-autocron.log";
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

Log::Log4perl::init(\$log4Perl_config);

# Log4perl logger erzeugen
my $logger = get_logger();

my $blacklist_enrichmnt_ref = {
    'bestellungen' => 1,
};

my $blacklist_ref = {
    'alekiddr' => 1,
    'ebookpda' => 1,
    'econbiz' => 1,
    'edz' => 1,
    'gentzdigital' => 1,
    'inst001' => 1,
    'inst103' => 1,
    'inst103master' => 1,
    'inst105' => 1,
    'inst105master' => 1,
    'inst128' => 1,
    'inst128master' => 1,
    'inst157' => 1,
    'inst157master' => 1,
    'inst166' => 1,
    'inst166master' => 1,
    'inst137' => 1,
    'inst301' => 1,
    'inst303' => 1,
    'inst304' => 1,
    'inst305' => 1,
    'inst306' => 1,
    'inst307' => 1,
    'inst308' => 1,
    'inst309' => 1,
    'inst310' => 1,
    'inst311' => 1,
    'inst312' => 1,
    'inst313' => 1,
    'inst314' => 1,
    'inst315' => 1,
    'inst316' => 1,
    'inst317' => 1,
    'inst318' => 1,
    'inst319' => 1,
    'inst320' => 1,
    'inst321' => 1,
    'inst323' => 1,
    'inst324' => 1,
    'inst325' => 1,
    'inst420' => 1,
    'inst132' => 1,
    'inst132master' => 1,
    'inst418master' => 1,
    'inst418' => 1,
    'inst420master' => 1,
    'inst421' => 1,
    'inst422' => 1,
    'inst423' => 1,
    'inst429master' => 1,
    'inst448master' => 1,
    'inst429' => 1,
    'inst448' => 1,
    'lehrbuchsmlg' => 1,
    'lesesaal' => 1,
    'openlibrary' => 1,
    'rheinabt' => 1,
    'rheinabt' => 1,
    'kups'     => 1,
    'tmpebooks' => 1,
    'totenzettel' => 1,
    'usbebooks' => 1,
    'usbhwa' => 1,
    'usbsab' => 1,
    'vubpda' => 1,
    'dreierpda' => 1,
    'wiso' => 1,
};

my @threads;

if ($test){
    push @threads, threads->new(\&threadTest,'Testkatalog');
}
else {
    push @threads, threads->new(\&threadA,'Thread 1');
    push @threads, threads->new(\&threadB,'Thread 2');
    push @threads, threads->new(\&threadC,'Thread 3');
}

foreach my $thread (@threads) {
    my $thread_description = $thread->join;
    $logger->info("### -> done with $thread_description");
}

$logger->info("### EBOOKPDA");

autoconvert({ updatemaster => $updatemaster, sync => 1, databases => ['ebookpda'] });

##############################

$logger->info("### VUBPDA");

autoconvert({ updatemaster => $updatemaster, sync => 1, databases => ['vubpda','dreierpda'] });

##############################

$logger->info("### Offene Bestellungen");

autoconvert({ updatemaster => $updatemaster, sync => 1, databases => ['bestellungen'] });

##############################


$logger->info("###### Updating done");

sub threadA {
    my $thread_description = shift;

    $logger->info("### -> $thread_description");

    $logger->info("### OAI-Kataloge");
    
    autoconvert({ databases => ['nsdl','ndltd','elis','hathitrust','doajarticles','zvdd','gallica','gdz','nla','mdz','loc'] });

    return $thread_description;
}

sub threadB {
    my $thread_description = shift;

    $logger->info("### -> $thread_description");    

    $logger->info("### Sonstige Kataloge");
    
    autoconvert({ databases => ['khanacademy','khanacademy_de','stanford_oer','loviscach_oer','intechopen','yale_oer','ucberkeley_oer','ocwconsortium','ucla_oer','mitocw_oer','gresham_oer','nptelhrd_oer','ssgbwlvolltexte','inst459reorg','tusculum','inst404card','nomos'] });

    return $thread_description;
}

sub threadC {
    my $thread_description = shift;

    $logger->info("### -> $thread_description");    

    $logger->info("### Master: ZBMED");
    
    autoconvert({ updatemaster => $updatemaster, sync => 1, databases => ['zbmed'] });

    ##############################
    
    return $thread_description;
}

sub threadTest {
    my $thread_description = shift;

    $logger->info("### -> Testkatalog");

    $logger->info("### Openbib");

    autoconvert({ updatemaster => $updatemaster, databases => ['openbib'] });

    return $thread_description;
}

sub autoconvert {
    my ($arg_ref) = @_;

    my @ac_cmd = ();
    
    # Set defaults
    my $blacklist_ref   = exists $arg_ref->{blacklist}
        ? $arg_ref->{blacklist}             : {};

    my $databases_ref   = exists $arg_ref->{databases}
        ? $arg_ref->{databases}             : [];

    my $sync            = exists $arg_ref->{sync}
        ? $arg_ref->{sync}                  : 0;

    my $genmex          = exists $arg_ref->{genmex}
        ? $arg_ref->{genmex}                : 0;

    my $autoconv        = exists $arg_ref->{autoconv}
        ? $arg_ref->{autoconv}              : 0;

    my $updatemaster    = exists $arg_ref->{updatemaster}
        ? $arg_ref->{updatemaster}          : 0;

    # Log4perl logger erzeugen
    my $logger = get_logger();


    push @ac_cmd, "/opt/openbib/autoconv/bin/autoconv.pl";
    push @ac_cmd, "-sync"    if ($sync); 
    push @ac_cmd, "-gen-mex" if ($genmex);
    push @ac_cmd, "-update-master" if ($updatemaster);

    my $ac_cmd_base = join(' ',@ac_cmd);

    my @databases = ();

    if (@$databases_ref){
        push @databases, @$databases_ref;
    }

    if ($autoconv){
        my $dbinfo = $config->get_databaseinfo->search(
            {
                'autoconvert' => 1,
            },
            {
                order_by => 'dbname',
            }
        );
        foreach my $item ($dbinfo->all){
            push @databases, $item->dbname;
        }
    }
  
    foreach my $database (@databases){
        if (exists $blacklist_ref->{$database}){
            $logger->info("Katalog $database auf Blacklist");
            next;
        }
        
        my $this_cmd = "$ac_cmd_base --database=$database";
        $logger->info("Konvertierung von $database");
        $logger->info("Ausfuehrung von $this_cmd");
        system($this_cmd);

        if ($maintenance && !defined $blacklist_enrichmnt_ref->{$database}){
            $logger->info("### Enriching subject headings for all institutes");
            
            system("$config->{'base_dir'}/conv/swt2enrich.pl --database=$database");
        }
    }
}
