#!/usr/bin/perl

#####################################################################
#
#  autoconv-econbiz.pl
#
#  Automatische Konvertierung von Econbiz-Daten
#
#  Dieses File ist (C) 2004  Oliver Flimm <flimm@openbib.org>
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

use Getopt::Long;
use DBI;

use OpenBib::Config;

# Importieren der Konfigurationsdaten als Globale Variablen
# in diesem Namespace

use vars qw(%config);

*config=\%OpenBib::Config::config;

&GetOptions("single-pool=s" => \$singlepool,
	    "get-via-sql" => \$getviasql,
	    "fastload" => \$fastload,
	    "help" => \$help
	    );

if ($help){
    print_help();
}

$rootdir=$config{'autoconv_dir'};
$pooldir=$rootdir."/pools";

$econbiz2metaexe="$config{'conv_dir'}/econbiz2meta.pl";
$oai2metaexe="$config{'conv_dir'}/oai2meta.pl";
$meta2sqlexe="$config{'conv_dir'}/meta2sql.pl";
$meta2waisexe="$config{'conv_dir'}/meta2wais.pl";
$wais2sqlexe="$config{'conv_dir'}/wais2searchSQL.pl";
$mysqlexe="/usr/bin/mysql -u  $config{'dbuser'} --password=$config{'dbpasswd'} -f";
$mysqladminexe="/usr/bin/mysqladmin -u $config{'dbuser'} --password=$config{'dbpasswd'} -f";
$myisamchkexe="/usr/bin/myisamchk --tmpdir=$config{'base_dir'}/tmp";

if (!$singlepool){
   print STDERR "Kein Pool mit --single-pool= ausgewaehlt\n";
   exit;
}

my $sessiondbh=DBI->connect("DBI:$config{dbimodule}:dbname=$config{sessiondbname};host=$config{sessiondbhost};port=$config{sessiondbport}", $config{sessiondbuser}, $config{sessiondbpasswd}) or die "could not connect";

# Verweis: Datenbankname -> Sigel

my $dbinforesult=$sessiondbh->prepare("select sigel from dbinfo where dbname='$singlepool'") or die "Error -- $DBI::errstr";
$dbinforesult->execute();

my %poolsigel=();

my $result=$dbinforesult->fetchrow_hashref();
my $sigel=$result->{'sigel'};

if ($sigel eq ""){
  print STDERR "Kein Sigel zu Pool $singlepool auffindbar\n";
  exit;
}

$dbinforesult=$sessiondbh->prepare("select * from dboptions where dbname='$singlepool'") or die "Error -- $DBI::errstr";
$dbinforesult->execute();
$result=$dbinforesult->fetchrow_hashref();

my $host=$result->{'host'};
my $protocol=$result->{'protocol'};
my $remotepath=$result->{'remotepath'};
my $remoteuser=$result->{'remoteuser'};
my $remotepasswd=$result->{'remotepasswd'};
my $filename=$result->{'filename'};
my $titfilename=$result->{'titfilename'};
my $autfilename=$result->{'autfilename'};
my $korfilename=$result->{'korfilename'};
my $swtfilename=$result->{'swtfilename'};
my $notfilename=$result->{'notfilename'};
my $mexfilename=$result->{'mexfilename'};
my $autoconvert=$result->{'autoconvert'};

$dbinforesult->finish();

$sessiondbh->disconnect();

if ($getviasql){
  print "### $singlepool: Poolabzug via sql\n";
  system("$econbiz2metaexe |gzip > $rootdir/pools/$singlepool/pool.dat.gz");
  
}

# Konvertierung Pool -> Exportdateien
if (! -e "$pooldir/$singlepool/pool.dat.gz"){
  print "!!! Pool $singlepool existiert nicht\n";
  next;
}

if (! -d "$rootdir/data/$singlepool"){
  system("mkdir $rootdir/data/$singlepool");
}
    
print "### $singlepool: Konvertierung Pool -> Exportdateien\n";

system("rm $rootdir/data/$singlepool/*");
system("/bin/gzip -dc $pooldir/$singlepool/pool.dat.gz > $rootdir/data/$singlepool/pool.dat");
system("cd $rootdir/data/$singlepool; $oai2metaexe -mit-schlagworten --oaifile=pool.dat");

# Konvertierung Exportdateien -> SQL

print "### $singlepool: Konvertierung Exportdateien -> SQL\n";

system("cd $rootdir/data/$singlepool ; $meta2sqlexe -all -mysql");
  
# Konvertierung Exportdateien -> WAIS

print "### $singlepool: Konvertierung Exportdateien -> WAIS\n";
system("cd $rootdir/data/$singlepool ; $meta2waisexe -combined ; $wais2sqlexe < data.wais ");
  
# Loeschen der Daten in Biblio

print "### $singlepool: Loeschen der Daten in Biblio\n";

system("$mysqlexe $singlepool < $config{'dbdesc_dir'}/mysql/poolflush.mysql");
system("$mysqlexe $singlepool < $config{'dbdesc_dir'}/mysql/pool.mysql");

# Einladen der Daten nach Biblio

print "### $singlepool: Einladen der Daten nach Biblio\n";
system("$mysqlexe $singlepool < $rootdir/data/$singlepool/control.mysql");
print "### $singlepool: Fixen der Sigel\n";
system("$mysqlexe -e \"update mex set sigel=\\\"".$sigel."\\\" where idn < 99999999 \" ".$singlepool."");

# Kopieren der WAIS-Daten

if ($fastload){
  system("$mysqlexe $singlepool -e \"truncate table search\"");
  system("$mysqladminexe flush-tables");
  system("$myisamchkexe --keys-used=0 -rq /var/lib/mysql/$singlepool/search");
  system("$mysqlexe $singlepool -e \"load data infile '$rootdir/data/$singlepool/search.sql' into table search fields terminated by '|' \" ");
  system("$myisamchkexe -r -q /var/lib/mysql/$singlepool/search");
  system("$mysqladminexe flush-tables");
}
else {
  system("cd $rootdir/data/$singlepool ; $mysqlexe $singlepool -e \"load data infile '$rootdir/data/$singlepool/search.sql' into table search fields terminated by '|'\" ");
}

print "### $singlepool: Updating Titcount\n";
system("$config{'base_dir'}/bin/updatetitcount.pl --single-pool=$singlepool");

print "### $singlepool: Cleanup\n";
  
sub print_help {
    print "autoconv-econbiz.pl - Automatische Konvertierung von Econbiz-Daten\n\n";
    print "Optionen: \n";
    print "  -help                 : Diese Informationsseite\n\n";
    print "  -get-via-sql          : Hole Pool automatisch mit SQL\n";
    print "  -fastload             : Beschleunigtes Einladen via myisamchk\n";
    print "  --single-pool=...     : Nur angegebenen Datenpool verwenden\n";
    exit;
}

