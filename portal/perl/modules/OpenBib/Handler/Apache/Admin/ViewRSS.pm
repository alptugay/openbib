#####################################################################
#
#  OpenBib::Handler::Apache::Admin::ViewRSS
#
#  Dieses File ist (C) 2004-2011 Oliver Flimm <flimm@openbib.org>
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

package OpenBib::Handler::Apache::Admin::ViewRSS;

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

use base 'OpenBib::Handler::Apache';

# Run at startup
sub setup {
    my $self = shift;

    $self->start_mode('show_record');
    $self->run_modes(
        'show_record'               => 'show_record',
        'show_record_form'          => 'show_record_form',
        'update_record'             => 'update_record',
        'delete_record'             => 'delete_record',
    );

    # Use current path as template path,
    # i.e. the template is in the same directory as this script
#    $self->tmpl_path('./');
}

sub show_record {
    my $self = shift;

    # Log4perl logger erzeugen
    my $logger = get_logger();
    
    # Dispatched Args
    my $view           = $self->param('view');
    my $viewname       = $self->param('viewid');

    # Shared Args
    my $query          = $self->query();
    my $r              = $self->param('r');
    my $config         = $self->param('config');
    my $session        = $self->param('session');
    my $user           = $self->param('user');
    my $msg            = $self->param('msg');
    my $queryoptions   = $self->param('qopts');
    my $stylesheet     = $self->param('stylesheet');
    my $useragent      = $self->param('useragent');
    my $path_prefix    = $self->param('path_prefix');

    if (!$self->is_authenticated('admin')){
        return;
    }

    if (!$config->view_exists($viewname)) {
        $self->print_warning($msg->maketext("Es existiert kein View unter diesem Namen"));
        return Apache2::Const::OK;
    }

    my $dbinfotable = OpenBib::Config::DatabaseInfoTable->instance;

    my $viewinfo_obj  = $config->get_viewinfo->search({ viewname => $viewname })->single();

    my $description = $viewinfo_obj->description;
    my $primrssfeed = $viewinfo_obj->get_column('rssid');

    my $all_rssfeeds_ref = $config->get_rssfeed_overview();
    my $viewrssfeed_ref  = $config->get_rssfeeds_of_view($viewname);

    my $viewinfo={
        viewname     => $viewname,
        description  => $description,
        allrssfeeds  => $all_rssfeeds_ref,
        viewrssfeed  => $viewrssfeed_ref,
        primrssfeed  => $primrssfeed,
    };

    my $ttdata={
        viewinfo   => $viewinfo,
        dbinfo     => $dbinfotable,
    };
    
    $self->print_page($config->{tt_admin_view_rss_record_tname},$ttdata);

    return Apache2::Const::OK;
}

sub show_record_form {
    my $self = shift;

    # Log4perl logger erzeugen
    my $logger = get_logger();
    
    # Dispatched Args
    my $view           = $self->param('view');
    my $viewname       = $self->param('viewid');

    # Shared Args
    my $query          = $self->query();
    my $r              = $self->param('r');
    my $config         = $self->param('config');
    my $session        = $self->param('session');
    my $user           = $self->param('user');
    my $msg            = $self->param('msg');
    my $queryoptions   = $self->param('qopts');
    my $stylesheet     = $self->param('stylesheet');
    my $useragent      = $self->param('useragent');
    my $path_prefix    = $self->param('path_prefix');

    if (!$self->is_authenticated('admin')){
        return;
    }

    if (!$config->view_exists($viewname)) {
        $self->print_warning($msg->maketext("Es existiert kein View unter diesem Namen"));
        return Apache2::Const::OK;
    }

    my $dbinfotable = OpenBib::Config::DatabaseInfoTable->instance;

    my $viewinfo    = $config->get_viewinfo->search({ viewname => $viewname })->single();

    my $all_rssfeeds_ref = $config->get_rssfeed_overview();
    my $viewrssfeed_ref  = $config->get_rssfeeds_of_view($viewname);

    my $ttdata={
        viewinfo   => $viewinfo,

        allrssfeeds  => $all_rssfeeds_ref,
        viewrssfeed  => $viewrssfeed_ref,

        dbinfo     => $dbinfotable,
    };

    $self->print_page($config->{tt_admin_view_rss_record_edit_tname},$ttdata);

    return Apache2::Const::OK;
}

sub update_record {
    my $self = shift;

    # Log4perl logger erzeugen
    my $logger = get_logger();

    # Dispatched Args
    my $view           = $self->param('view');
    my $viewname       = $self->param('viewid');

    # Shared Args
    my $query          = $self->query();
    my $r              = $self->param('r');
    my $config         = $self->param('config');
    my $session        = $self->param('session');
    my $user           = $self->param('user');
    my $msg            = $self->param('msg');
    my $queryoptions   = $self->param('qopts');
    my $stylesheet     = $self->param('stylesheet');
    my $useragent      = $self->param('useragent');
    my $path_prefix    = $self->param('path_prefix');

    # CGI Args
    my $method          = decode_utf8($query->param('_method')) || '';
    my $confirm         = $query->param('confirm') || 0;
    my $primrssfeed     = $query->param('primrssfeed')     || '';
    my @rssfeeds        = ($query->param('rssfeeds'))?$query->param('rssfeeds'):();

    if (!$self->is_authenticated('admin')){
        return;
    }

    $logger->debug("Server: ".$r->get_server_name);

    if (!$config->view_exists($viewname)) {
        $self->print_warning($msg->maketext("Es existiert kein View unter diesem Namen"));
        return Apache2::Const::OK;
    }

    # Ansonsten POST oder PUT => Aktualisieren
    $config->update_view_rss($viewname,$primrssfeed,\@rssfeeds);
    
    $self->query->method('GET');
    $self->query->headers_out->add(Location => "$path_prefix/$config->{admin_view_loc}/$viewname/rss/edit.html");
    $self->query->status(Apache2::Const::REDIRECT);

    return;
}

1;
