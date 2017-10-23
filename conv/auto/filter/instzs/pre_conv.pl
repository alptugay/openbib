#!/usr/bin/perl

#####################################################################
#
#  pre_conv.pl
#
#  Dieses File ist (C) 2005-2006 Oliver Flimm <flimm@openbib.org>
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

use OpenBib::Config;

my $config = OpenBib::Config->new;

my $rootdir       = $config->{'autoconv_dir'};
my $pooldir       = $rootdir."/pools";
my $konvdir       = $config->{'conv_dir'};

my $pool          = $ARGV[0];

print "### $pool: Entfernen ungewuenschter Standorte\n";
system("cd $rootdir/data/$pool/ ;  $rootdir/filter/$pool/exclude-locations.pl");
system("cd $rootdir/data/$pool/ ;  mv -f meta.holding.tmp meta.holding ; mv -f meta.title.tmp meta.title");

system("ls -l $rootdir/data/$pool/");

print "### $pool: ZDBID wird zur ID\n";
system("$rootdir/filter/$pool/zdbid2id.pl < $rootdir/data/$pool/meta.title > $rootdir/data/$pool/meta.title.tmp");
system("mv -f $rootdir/data/$pool/meta.title.tmp $rootdir/data/$pool/meta.title");
system("$rootdir/filter/$pool/zdbid2id-mex.pl < $rootdir/data/$pool/meta.holding | $rootdir/filter/$pool/join-journalholdings.pl > $rootdir/data/$pool/meta.holding.tmp");
system("mv -f $rootdir/data/$pool/meta.holding.tmp $rootdir/data/$pool/meta.holding");
system("cd $rootdir/data/$pool/ ; $rootdir/filter/$pool/add-locationid.pl < $rootdir/data/$pool/meta.title > $rootdir/data/$pool/meta.title.tmp");
system("mv -f $rootdir/data/$pool/meta.title.tmp $rootdir/data/$pool/meta.title");
