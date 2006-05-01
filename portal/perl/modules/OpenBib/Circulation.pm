#####################################################################
#
#  OpenBib::Circulation
#
#  Dieses File ist (C) 2004-2006 Oliver Flimm <flimm@openbib.org>
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

package OpenBib::Circulation;

use strict;
use warnings;
no warnings 'redefine';
use utf8;

use Apache::Constants qw(:common);
use Apache::Reload;
use Apache::Request ();
use DBI;
use Digest::MD5;
use Email::Valid;
use Log::Log4perl qw(get_logger :levels);
use POSIX;
use SOAP::Lite;
use Socket;
use Template;

use OpenBib::Common::Util;
use OpenBib::Config;
use OpenBib::L10N;

# Importieren der Konfigurationsdaten als Globale Variablen
# in diesem Namespace

use vars qw(%config);

*config=\%OpenBib::Config::config;

sub handler {
    my $r=shift;

    # Log4perl logger erzeugen
    my $logger = get_logger();

    my $query=Apache::Request->new($r);

    my $status=$query->parse;

    if ($status) {
        $logger->error("Cannot parse Arguments - ".$query->notes("error-notes"));
    }

    my $stylesheet=OpenBib::Common::Util::get_css_by_browsertype($r);

    my $action     = ($query->param('action'    ))?$query->param('action'):'none';
    my $circaction = ($query->param('circaction'))?$query->param('circaction'):'none';
    my $offset     = ($query->param('offset'    ))?$query->param('offset'):0;
    my $listlength = ($query->param('listlength'))?$query->param('listlength'):10;
    my $sessionID  = $query->param('sessionID'  )||'';

    my $sessiondbh
        = DBI->connect("DBI:$config{dbimodule}:dbname=$config{sessiondbname};host=$config{sessiondbhost};port=$config{sessiondbport}", $config{sessiondbuser}, $config{sessiondbpasswd})
            or $logger->error_die($DBI::errstr);
  
    my $userdbh
        = DBI->connect("DBI:$config{dbimodule}:dbname=$config{userdbname};host=$config{userdbhost};port=$config{userdbport}", $config{userdbuser}, $config{userdbpasswd})
            or $logger->error_die($DBI::errstr);

    my $queryoptions_ref
        = OpenBib::Common::Util::get_queryoptions($sessiondbh,$r);

    # Message Katalog laden
    my $msg = OpenBib::L10N->get_handle($queryoptions_ref->{l}) || $logger->error("L10N-Fehler");
    $msg->fail_with( \&OpenBib::L10N::failure_handler );
    
    unless (OpenBib::Common::Util::session_is_valid($sessiondbh,$sessionID)){

        OpenBib::Common::Util::print_warning($msg->maketext("Ungültige Session"),$r,$msg);

        $sessiondbh->disconnect();
        $userdbh->disconnect();
        return OK;
    }

    my $view="";

    if ($query->param('view')) {
        $view=$query->param('view');
    }
    else {
        $view=OpenBib::Common::Util::get_viewname_of_session($sessiondbh,$sessionID);
    }
  
    my $userid=OpenBib::Common::Util::get_userid_of_session($userdbh,$sessionID);
  
    unless($userid){

        OpenBib::Common::Util::print_warning($msg->maketext("Diese Session ist nicht authentifiziert."),$r,$msg);

        $sessiondbh->disconnect();
        $userdbh->disconnect();
        return OK;
    }
  
    my ($loginname,$password)=OpenBib::Common::Util::get_cred_for_userid($userdbh,$userid);

    my $database=OpenBib::Common::Util::get_targetdb_of_session($userdbh,$sessionID);

    my $targetcircinfo_ref = OpenBib::Common::Util::get_targetcircinfo($sessiondbh);

    if ($action eq "showcirc") {

        if ($circaction eq "reservations") {
            my $circexlist=undef;
      
            my $soap = SOAP::Lite
                -> uri("urn:/Circulation")
                    -> proxy($targetcircinfo_ref->{$database}{circcheckurl});
            my $result = $soap->get_reservations($loginname,$password,$targetcircinfo_ref->{$database}{circdb});
      
            unless ($result->fault) {
                $circexlist=$result->result;
            }
            else {
                $logger->error("SOAP MediaStatus Error", join ', ', $result->faultcode, $result->faultstring, $result->faultdetail);
            }
      
            # TT-Data erzeugen
      
            my $ttdata={
                view         => $view,
                stylesheet   => $stylesheet,
		  
                sessionID    => $sessionID,
                loginname    => $loginname,
                password     => $password,
		  
                reservations => $circexlist,
		  
                utf2iso      => sub {
		    my $string=shift;
		    $string=~s/([^\x20-\x7F])/'&#' . ord($1) . ';'/gse;
		    return $string;
                },
		  
                show_corporate_banner => 0,
                show_foot_banner      => 1,
                config       => \%config,
                msg          => $msg,
            };
      
            OpenBib::Common::Util::print_page($config{tt_circulation_reserv_tname},$ttdata,$r);

        }
        elsif ($circaction eq "reminders") {
            my $circexlist=undef;
      
            my $soap = SOAP::Lite
                -> uri("urn:/Circulation")
                    -> proxy($targetcircinfo_ref->{$database}{circcheckurl});
            my $result = $soap->get_reminders($loginname,$password,$targetcircinfo_ref->{$database}{circdb});
      
            unless ($result->fault) {
                $circexlist=$result->result;
            }
            else {
                $logger->error("SOAP MediaStatus Error", join ', ', $result->faultcode, $result->faultstring, $result->faultdetail);
            }
      
            # TT-Data erzeugen
      
            my $ttdata={
                view       => $view,
                stylesheet => $stylesheet,
		  
                sessionID  => $sessionID,
                loginname  => $loginname,
                password   => $password,
		  
                reminders  => $circexlist,
		  
                utf2iso    => sub {
		    my $string=shift;
		    $string=~s/([^\x20-\x7F])/'&#' . ord($1) . ';'/gse;
		    return $string;
                },
		  
                show_corporate_banner => 0,
                show_foot_banner      => 1,
                config     => \%config,
                msg        => $msg,
            };
      
            OpenBib::Common::Util::print_page($config{tt_circulation_remind_tname},$ttdata,$r);
        }
        elsif ($circaction eq "orders") {
            my $circexlist=undef;
      
            my $soap = SOAP::Lite
                -> uri("urn:/Circulation")
                    -> proxy($targetcircinfo_ref->{$database}{circcheckurl});
            my $result = $soap->get_orders($loginname,$password,$targetcircinfo_ref->{$database}{circdb});
      
            unless ($result->fault) {
                $circexlist=$result->result;
            }
            else {
                $logger->error("SOAP MediaStatus Error", join ', ', $result->faultcode, $result->faultstring, $result->faultdetail);
            }
      
            # TT-Data erzeugen
            my $ttdata={
                view       => $view,
                stylesheet => $stylesheet,
		  
                sessionID  => $sessionID,
                loginname  => $loginname,
                password   => $password,
		  
                orders     => $circexlist,
		  
                utf2iso    => sub {
		    my $string=shift;
		    $string=~s/([^\x20-\x7F])/'&#' . ord($1) . ';'/gse;
		    return $string;
                },
		  
                show_corporate_banner => 0,
                show_foot_banner      => 1,
                config     => \%config,
                msg        => $msg,
            };
      
            OpenBib::Common::Util::print_page($config{tt_circulation_orders_tname},$ttdata,$r);
        }
        else {
            my $circexlist=undef;
      
            my $soap = SOAP::Lite
                -> uri("urn:/Circulation")
                    -> proxy($targetcircinfo_ref->{$database}{circcheckurl});
            my $result = $soap->get_borrows($loginname,$password,$targetcircinfo_ref->{$database}{circdb});
      
            unless ($result->fault) {
                $circexlist=$result->result;
            }
            else {
                $logger->error("SOAP MediaStatus Error", join ', ', $result->faultcode, $result->faultstring, $result->faultdetail);
            }
      
            # TT-Data erzeugen
            my $ttdata={
                view       => $view,
                stylesheet => $stylesheet,
		  
                sessionID  => $sessionID,
                loginname  => $loginname,
                password   => $password,
		  
                borrows    => $circexlist,
		  
                utf2iso    => sub {
		    my $string=shift;
		    $string=~s/([^\x20-\x7F])/'&#' . ord($1) . ';'/gse;
		    return $string;
                },
		  
                show_corporate_banner => 0,
                show_foot_banner      => 1,
                config     => \%config,
                msg        => $msg,
            };
      
            OpenBib::Common::Util::print_page($config{tt_circulation_tname},$ttdata,$r);
        }


    }
    else {
        OpenBib::Common::Util::print_warning($msg->maketext("Unerlaubte Aktion"),$r,$msg);
    }
  
    $sessiondbh->disconnect();
    $userdbh->disconnect();
    return OK;
}

1;
__END__

=head1 NAME

OpenBib::Circulation - Benutzerkonto

=head1 DESCRIPTION

Das mod_perl-Modul OpenBib::UserPrefs bietet dem Benutzer des 
Suchportals einen Einblick in das jeweilige Benutzerkonto und gibt
eine Aufstellung der ausgeliehenen, vorgemerkten sowie ueberzogenen
Medien.

=head1 AUTHOR

 Oliver Flimm <flimm@openbib.org>

=cut
