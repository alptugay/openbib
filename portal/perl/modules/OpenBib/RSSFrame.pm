####################################################################
#
#  OpenBib::RSSFrame
#
#  Dieses File ist (C) 2006 Oliver Flimm <flimm@openbib.org>
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

package OpenBib::RSSFrame;

use strict;
use warnings;
no warnings 'redefine';
use utf8;

use Apache::Constants qw(:common);
use Apache::Reload;
use Apache::Request ();
use DBI;
use Encode 'decode_utf8';
use Log::Log4perl qw(get_logger :levels);
use POSIX;
use Template;

use OpenBib::Common::Util;
use OpenBib::Config;
use OpenBib::L10N;
use OpenBib::Session;

sub handler {
    my $r=shift;

    # Log4perl logger erzeugen
    my $logger = get_logger();

    my $config = new OpenBib::Config();
    
    my $query=Apache::Request->new($r);

    my $status=$query->parse;

    if ($status) {
        $logger->error("Cannot parse Arguments - ".$query->notes("error-notes"));
    }

    my $session   = new OpenBib::Session({
        sessionID => $query->param('sessionID'),
    });
    
    my $stylesheet=OpenBib::Common::Util::get_css_by_browsertype($r);
  
    my $queryoptions_ref
        = $session->get_queryoptions($query);

    # Message Katalog laden
    my $msg = OpenBib::L10N->get_handle($queryoptions_ref->{l}) || $logger->error("L10N-Fehler");
    $msg->fail_with( \&OpenBib::L10N::failure_handler );

    if (!$session->is_valid()){
        OpenBib::Common::Util::print_warning($msg->maketext("Ungültige Session"),$r,$msg);

        return OK;
    }

    my $view="";

    if ($query->param('view')) {
        $view=$query->param('view');
    }
    else {
        $view=$session->get_viewname();
    }

    my $rssfeedinfo_ref = {
    };

    if ($view){
        my $request=$config->{dbh}->prepare("select dbinfo.dbname,dbinfo.description,dbinfo.orgunit,rssfeeds.type from dbinfo,rssfeeds,viewrssfeeds where dbinfo.active=1 and rssfeeds.active=1 and dbinfo.dbname=rssfeeds.dbname and rssfeeds.type = 1 and viewrssfeeds.viewname = ? and viewrssfeeds.rssfeed=rssfeeds.id order by orgunit ASC, description ASC");
        $request->execute($view);
        
        while (my $result=$request->fetchrow_hashref){
            my $orgunit    = decode_utf8($result->{'orgunit'});
            my $name       = decode_utf8($result->{'description'});
            my $pool       = decode_utf8($result->{'dbname'});
            my $rsstype    = decode_utf8($result->{'type'});
            
            push @{$rssfeedinfo_ref->{$orgunit}},{
                pool     => $pool,
                pooldesc => $name,
                type     => 'neuzugang',
            };
        }
    }
    else {
        my $request=$config->{dbh}->prepare("select dbinfo.dbname,dbinfo.description,dbinfo.orgunit,rssfeeds.type from dbinfo,rssfeeds where dbinfo.active=1 and rssfeeds.active=1 and dbinfo.dbname=rssfeeds.dbname and rssfeeds.type = 1 order by orgunit ASC, description ASC");
        $request->execute();
        
        while (my $result=$request->fetchrow_hashref){
            my $orgunit    = decode_utf8($result->{'orgunit'});
            my $name       = decode_utf8($result->{'description'});
            my $pool       = decode_utf8($result->{'dbname'});
            my $rsstype    = decode_utf8($result->{'type'});
            
            push @{$rssfeedinfo_ref->{$orgunit}},{
                pool     => $pool,
                pooldesc => $name,
                type     => 'neuzugang',
            };
        }
    }

    # TT-Data erzeugen
    my $ttdata={
        view        => $view,
        rssfeedinfo => $rssfeedinfo_ref,
        stylesheet  => $stylesheet,
        config      => $config,
        msg         => $msg,
    };

    OpenBib::Common::Util::print_page($config->{tt_rssframe_tname},$ttdata,$r);

    return OK;
}

1;
