#####################################################################
#
#  OpenBib::Handler::Apache::ExternalJump
#
#  Dieses File ist (C) 2005-2011 Oliver Flimm <flimm@openbib.org>
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

package OpenBib::Handler::Apache::ExternalJump;

use strict;
use warnings;
no warnings 'redefine';
use utf8;

use Apache2::Const -compile => qw(:common);
use Apache2::Reload;
use Apache2::RequestRec ();
use Apache2::Request ();
use DBI;
use Digest::MD5;
use Encode 'decode_utf8';
use Log::Log4perl qw(get_logger :levels);
use POSIX;
use Template;

use OpenBib::Common::Util;
use OpenBib::Config;
use OpenBib::L10N;
use OpenBib::QueryOptions;
use OpenBib::SearchQuery;
use OpenBib::Session;
use OpenBib::User;

use base 'OpenBib::Handler::Apache';

# Run at startup
sub setup {
    my $self = shift;

    $self->start_mode('show');
    $self->run_modes(
        'show'       => 'show',
        'dispatch_to_representation'           => 'dispatch_to_representation',
    );

    # Use current path as template path,
    # i.e. the template is in the same directory as this script
#    $self->tmpl_path('./');
}

sub show {
    my $self = shift;

    # Log4perl logger erzeugen
    my $logger = get_logger();
    
    my $r              = $self->param('r');

    my $view           = $self->param('view')           || '';

    my $config = OpenBib::Config->instance();
    
    my $query  = Apache2::Request->new($r);

    my $session = OpenBib::Session->instance({ apreq => $r });             

    my $user      = OpenBib::User->instance({sessionID => $session->{ID}});
    
    my $useragent=$r->subprocess_env('HTTP_USER_AGENT');
    my $stylesheet=OpenBib::Common::Util::get_css_by_browsertype($r);
  
    # CGI-Uebergabe
    my @databases     = ($query->param('db'))?$query->param('db'):();
    my $singleidn     = $query->param('singleidn')     || '';
    my $action        = ($query->param('action'))?$query->param('action'):'';
    my $fs            = $query->param('fs')            || ''; # Freie Suche
    my $verf          = $query->param('verf')          || '';
    my $hst           = $query->param('hst')           || '';
    my $hststring     = $query->param('hststring')     || '';
    my $swt           = $query->param('swt')           || '';
    my $kor           = $query->param('kor')           || '';
    my $sign          = $query->param('sign')          || '';
    my $isbn          = $query->param('isbn')          || '';
    my $issn          = $query->param('issn')          || '';
    my $notation      = $query->param('notation')      || '';
    my $ejahr         = $query->param('ejahr')         || '';
    my $mart          = $query->param('mart')          || '';
    my $boolhst       = $query->param('boolhst')       || '';
    my $boolswt       = $query->param('boolswt')       || '';
    my $boolkor       = $query->param('boolkor')       || '';
    my $boolnotation  = $query->param('boolnotation')  || '';
    my $boolisbn      = $query->param('boolisbn')      || '';
    my $boolsign      = $query->param('boolsign')      || '';
    my $boolejahr     = $query->param('boolejahr')     || '';
    my $boolissn      = $query->param('boolissn')      || '';
    my $boolverf      = $query->param('boolverf')      || '';
    my $boolfs        = $query->param('boolfs')        || '';
    my $boolmart      = $query->param('boolmart')      || '';
    my $boolhststring = $query->param('boolhststring') || '';
    my $queryid       = $query->param('queryid')       || '';

    my $queryoptions = OpenBib::QueryOptions->instance($query);
    
    # Message Katalog laden
    my $msg = OpenBib::L10N->get_handle($queryoptions->get_option('l')) || $logger->error("L10N-Fehler");
    $msg->fail_with( \&OpenBib::L10N::failure_handler );
    
    if (!$session->is_valid()){
        $self->print_warning($msg->maketext("Ungültige Session"));
        return Apache2::Const::OK;
    }

    my $viewdesc = $config->get_viewdesc_from_viewname($view);

    my $searchquery = OpenBib::SearchQuery->instance({r => $r, view => $view});

    if ($queryid ne "") {
        $searchquery->load({sessionID => $session->{ID}, queryid => $queryid});
    }
    else {
        $self->print_warning($msg->maketext("Keine gültige Anfrage-ID"));
        return Apache2::Const::OK;
    }

    # Haben wir eine Benutzernummer? Dann versuchen wir den 
    # Authentifizierten Sprung in die Digibib

    my ($username,$password) = $user->get_credentials();

    my $authurl="";
    unless (defined $username && defined $password && Email::Valid->address($username)){

        # Hash im username durch %23 ersetzen
        $username=~s/#/\%23/;

        if ($username && $password) {
            $authurl="&USERID=$username&PASSWORD=$password";
        }
    }

    # TT-Data erzeugen
    my $ttdata={
        view         => $view,
        stylesheet   => $stylesheet,
        viewdesc     => $viewdesc,
        sessionID    => $session->{ID},
	      
	thisquery    => $searchquery,

        authurl      => $authurl,
	      
        config       => $config,
        user         => $user,
        msg          => $msg,
    };

    $self->print_page($config->{tt_externaljump_tname},$ttdata);

    return Apache2::Const::OK;
}

1;
