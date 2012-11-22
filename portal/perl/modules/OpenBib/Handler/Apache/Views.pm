#####################################################################
#
#  OpenBib::Handler::Apache::Views
#
#  Dieses File ist (C) 2004-2012 Oliver Flimm <flimm@openbib.org>
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

package OpenBib::Handler::Apache::Views;

use strict;
use warnings;
no warnings 'redefine';
use utf8;

use Apache2::Const -compile => qw(:common :http);
use Apache2::Log;
use Apache2::Reload;
use Apache2::RequestRec ();
use Apache2::Request ();
use Apache2::SubRequest ();
use Date::Manip qw/ParseDate UnixDate/;
use DBI;
use Digest::MD5;
use Encode qw/decode_utf8 encode_utf8/;
use JSON::XS;
use List::MoreUtils qw(none any);
use Log::Log4perl qw(get_logger :levels);
use POSIX;
use Template;

use OpenBib::Common::Util;
use OpenBib::Config;
use OpenBib::Config::DatabaseInfoTable;
use OpenBib::L10N;
use OpenBib::QueryOptions;
use OpenBib::Session;
use OpenBib::Statistics;
use OpenBib::User;

use CGI::Application::Plugin::Redirect;

use base 'OpenBib::Handler::Apache::Admin';

# Run at startup
sub setup {
    my $self = shift;

    $self->start_mode('show_collection');
    $self->run_modes(
        'show_collection'           => 'show_collection',
        'show_record'               => 'show_record',
        'delete_record'             => 'delete_record',
        'dispatch_to_representation'           => 'dispatch_to_representation',
    );

    # Use current path as template path,
    # i.e. the template is in the same directory as this script
#    $self->tmpl_path('./');
}

sub show_collection {
    my $self = shift;

    # Log4perl logger erzeugen
    my $logger = get_logger();

    # Dispatched Args
    my $view           = $self->param('view');

    # Shared Args
    my $config         = $self->param('config');

    my $dbinfotable = OpenBib::Config::DatabaseInfoTable->instance;
    
    my $viewinfo_ref = $config->get_viewinfo_overview();
    
    my $ttdata={
        dbinfo     => $dbinfotable,
        views      => $viewinfo_ref,
    };
    
    $self->print_page($config->{tt_views_tname},$ttdata);
    
    return Apache2::Const::OK;
}

sub show_record {
    my $self = shift;

    # Log4perl logger erzeugen
    my $logger = get_logger();

    # Dispatched Args
    my $view           = $self->param('view');
    my $viewname       = $self->strip_suffix($self->param('viewid'));

    # Shared Args
    my $config         = $self->param('config');
    my $msg            = $self->param('msg');

    # View muss existieren
    unless ($config->view_exists($viewname)) {
        $self->print_warning($msg->maketext("Ein View dieses Namens existiert nicht."));
        return Apache2::Const::OK;
    }

    my $dbinfotable = OpenBib::Config::DatabaseInfoTable->instance;

    my $viewinfo    = $config->get_viewinfo->search({ viewname => $viewname })->single();

    my $profilename = $viewinfo->profileid->profilename;
    
    my @profiledbs       = $config->get_profiledbs($profilename);
    my @viewdbs          = $config->get_viewdbs($viewname);
    my $all_rssfeeds_ref = $config->get_rssfeed_overview();
    my $viewrssfeed_ref  = $config->get_rssfeeds_of_view($viewname);

    my $ttdata={
        dbnames     => \@profiledbs,
        viewdbs     => \@viewdbs,
        viewinfo    => $viewinfo,
        dbinfo      => $dbinfotable,
        allrssfeeds => $all_rssfeeds_ref,
    };
    
    $self->print_page($config->{tt_views_record_tname},$ttdata);
}

1;