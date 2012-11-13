#####################################################################
#
#  OpenBib::Handler::Apache::Admin::Authenticators
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

package OpenBib::Handler::Apache::Admin::Authenticators;

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
        'show_record_form'          => 'show_record_form',
        'show_record'               => 'show_record',
        'create_record'             => 'create_record',
        'update_record'             => 'update_record',
        'delete_record'             => 'delete_record',
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
    my $query          = $self->query();
    my $r              = $self->param('r');
    my $config         = $self->param('config');

    if (!$self->authorization_successful){
        $self->print_authorization_error();
        return;
    }

    # TT-Data erzeugen
    my $ttdata={
    };
    
    $self->print_page($config->{tt_admin_authentication_tname},$ttdata);
}

sub show_record {
    my $self = shift;

    # Log4perl logger erzeugen
    my $logger = get_logger();

    # Dispatched Args
    my $view             = $self->param('view')                   || '';
    my $authenticationid = $self->strip_suffix($self->param('authenticationid'))       || '';

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
    
    if (!$self->authorization_successful){
        $self->print_authorization_error();
        return;
    }

    $logger->debug("Server: ".$r->get_server_name);

    my $authenticationtarget_ref = $config->get_authenticationtarget_by_id($authenticationid);
    
    my $ttdata={
        authenticationtarget => $authenticationtarget_ref,
    };
    
    $self->print_page($config->{tt_admin_authentication_record_tname},$ttdata);
}

sub show_record_form {
    my $self = shift;

    # Log4perl logger erzeugen
    my $logger = get_logger();

    # Dispatched Args
    my $view             = $self->param('view')                   || '';
    my $authenticationid = $self->param('authenticationid')       || '';

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
    
    if (!$self->authorization_successful){
        $self->print_authorization_error();
        return;
    }

    $logger->debug("Server: ".$r->get_server_name);

    my $authenticationtarget_ref = $config->get_authenticationtarget_by_id($authenticationid);
    
    my $ttdata={
        authenticationtarget => $authenticationtarget_ref,
    };
    
    $self->print_page($config->{tt_admin_authentication_record_edit_tname},$ttdata);
}

sub create_record {
    my $self = shift;

    # Log4perl logger erzeugen
    my $logger = get_logger();

    # Dispatched Args
    my $view           = $self->param('view')                   || '';

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
    my $location       = $self->param('location');

    # CGI / JSON input
    my $input_data_ref = $self->parse_valid_input();

    if (!$self->authorization_successful){
        $self->print_authorization_error();
        return;
    }

    $logger->debug("Server: ".$r->get_server_name);

    if ($input_data_ref->{description} eq "") {
        
        $self->print_warning($msg->maketext("Sie müssen mindestens eine Beschreibung eingeben."));
        
        return Apache2::Const::OK;
    }
    
    if ($config->authenticationtarget_exists({description => $input_data_ref->{description}})) {
        
        $self->print_warning($msg->maketext("Es existiert bereits ein Anmeldeziel unter diesem Namen"));
        
        return Apache2::Const::OK;
    }
    
    my $new_authenticationtargetid = $config->new_authenticationtarget($input_data_ref);

    if ($self->param('representation') eq "html"){
        $self->query->method('GET');
        $self->query->headers_out->add(Location => "$path_prefix/$config->{admin_authenticators_loc}");
        $self->query->status(Apache2::Const::REDIRECT);
    }
    else {
        $logger->debug("Weiter zum Record");
        if ($new_authenticationtargetid){
            $logger->debug("Weiter zum Record $new_authenticationtargetid");
            $self->param('status',Apache2::Const::HTTP_CREATED);
            $self->param('authenticationid',$new_authenticationtargetid);
            $self->param('location',"$location/$new_authenticationtargetid");
            $self->show_record;
        }
    }
    
    return;
}

sub update_record {
    my $self = shift;

    # Log4perl logger erzeugen
    my $logger = get_logger();
    
    # Dispatched Args
    my $view             = $self->param('view')                   || '';
    my $authenticationid = $self->param('authenticationid')       || '';

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

    # CGI / JSON input
    my $input_data_ref = $self->parse_valid_input();
    $input_data_ref->{id} = $authenticationid;
    
    if (!$self->authorization_successful){
        $self->print_authorization_error();
        return;
    }
    
    $logger->debug("Server: ".$r->get_server_name);

    # Method workaround fuer die Unfaehigkeit von Browsern PUT/DELETE in Forms
    # zu verwenden

    if ($method eq "DELETE"){
        $logger->debug("About to delete $authenticationid");
        
        if ($confirm){
            my $authenticationtarget_ref = $config->get_authenticationtarget_by_id($authenticationid);
            
            my $ttdata={
                stylesheet => $stylesheet,
                authenticationtarget  => $authenticationtarget_ref,

                view       => $view,
                
                config     => $config,
                session    => $session,
                user       => $user,
                msg        => $msg,
            };

            $logger->debug("Asking for confirmation");
            $self->print_page($config->{tt_admin_authentication_record_delete_confirm_tname},$ttdata);

            return Apache2::Const::OK;
        }
        else {
            $logger->debug("Redirecting to delete location");
            $self->delete_record;
            return;
        }
    }

    # Ansonsten POST oder PUT => Aktualisieren
    
    $config->update_authenticationtarget($input_data_ref);

    return unless ($self->param('representation') eq "html");

    if ($self->param('representation') eq "html"){
        $self->query->method('GET');
        $self->query->headers_out->add(Location => "$path_prefix/$config->{admin_authenticators_loc}");
        $self->query->status(Apache2::Const::REDIRECT);
    }
    else {
        $logger->debug("Weiter zum Record $authenticationid");
        $self->show_record;
    }

    return;
}

sub delete_record {
    my $self = shift;

    # Log4perl logger erzeugen
    my $logger = get_logger();
    
    # Dispatched Args
    my $view             = $self->param('view')                   || '';
    my $authenticationid = $self->param('authenticationid')             || '';

    # Shared Args
    my $r              = $self->param('r');
    my $config         = $self->param('config');
    my $path_prefix    = $self->param('path_prefix');

    if (!$self->authorization_successful){
        $self->print_authorization_error();
        return;
    }

    $logger->debug("Server: ".$r->get_server_name);

    $config->delete_authenticationtarget($authenticationid);

    return unless ($self->param('representation') eq "html");
    
    $self->query->method('GET');
    $self->query->headers_out->add(Location => "$path_prefix/$config->{admin_authenticators_loc}");
    $self->query->status(Apache2::Const::REDIRECT);

    return;
}

sub get_input_definition {
    my $self=shift;
    
    return {
        description => {
            default  => '',
            encoding => 'utf8',
            type     => 'scalar',
        },
        hostname => {
            default  => '',
            encoding => 'none',
            type     => 'scalar',
        },
        port => {
            default  => '',
            encoding => 'none',
            type     => 'scalar',
        },
        remoteuser => {
            default  => '',
            encoding => 'none',
            type     => 'scalar',
        },
        remoteuser => {
            default  => '',
            encoding => 'none',
            type     => 'scalar',
        },
        remotedb => {
            default  => '',
            encoding => 'none',
            type     => 'scalar',
        },
        type => {
            default  => '',
            encoding => 'none',
            type     => 'scalar',
        },        
    };
}
    
1;