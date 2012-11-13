#####################################################################
#
#  OpenBib::Handler::Apache::Admin::Clusters
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

package OpenBib::Handler::Apache::Admin::Clusters;

use strict;
use warnings;
no warnings 'redefine';
use utf8;

use Apache2::Const -compile => qw(:common);
use Apache2::Log;
use Apache2::Reload;
use Apache2::RequestRec ();
use Apache2::Request ();
use Apache2::SubRequest ();
use Date::Manip qw/ParseDate UnixDate/;
use DBI;
use Digest::MD5;
use Encode qw/decode_utf8 encode_utf8/;
use Log::Log4perl qw(get_logger :levels);
use POSIX;
use SOAP::Lite;
use Template;

use OpenBib::Common::Util;
use OpenBib::Config;
use OpenBib::Config::DatabaseInfoTable;
use OpenBib::L10N;
use OpenBib::QueryOptions;
use OpenBib::Session;
use OpenBib::Statistics;
use OpenBib::User;

use base 'OpenBib::Handler::Apache::Admin';

# Run at startup
sub setup {
    my $self = shift;

    $self->start_mode('show_collection');
    $self->run_modes(
        'show_collection'           => 'show_collection',
        'show_record_form'          => 'show_record_form',
        'create_record'             => 'create_record',
        'update_record'             => 'update_record',
        'confirm_delete_record'     => 'confirm_delete_record',
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
    my $view           = $self->param('view')                   || '';

    # Shared Args
    my $config         = $self->param('config');

    if (!$self->authorization_successful){
        $self->print_authorization_error();
        return;
    }

    my $clusterinfos_ref = $config->get_clusterinfo_overview;
    
    my $ttdata = {
        clusterinfos => $clusterinfos_ref,
    };
    
    $self->print_page($config->{tt_admin_cluster_tname},$ttdata);
}

sub show_record_form {
    my $self = shift;

    # Log4perl logger erzeugen
    my $logger = get_logger();

    # Dispatches Args
    my $view             = $self->param('view');
    my $clusterid        = $self->param('clusterid');

    # Shared Args
    my $config           = $self->param('config');

    if (!$self->authorization_successful){
        $self->print_authorization_error();
        return;
    }

    my $clusterinfo_ref = $config->get_clusterinfo->search_rs({ id => $clusterid })->single();
    
    my $ttdata = {
        clusterid     => $clusterid,
        clusterinfo   => $clusterinfo_ref,
    };
    
    $self->print_page($config->{tt_admin_cluster_record_edit_tname},$ttdata);
}

sub show_record {
    my $self = shift;

    # Log4perl logger erzeugen
    my $logger = get_logger();

    # Dispatches Args
    my $view             = $self->param('view');
    my $clusterid         = $self->param('clusterid');

    # Shared Args
    my $config           = $self->param('config');

    if (!$self->authorization_successful){
        $self->print_authorization_error();
        return;
    }

    my $clusterinfo_ref = $config->get_clusterinfo->search_rs({ id => $clusterid });
    
    my $ttdata = {
        clusterid     => $clusterid,
        clusterinfo   => $clusterinfo_ref,
    };
    
    $self->print_page($config->{tt_admin_cluster_record_tname},$ttdata);
}

sub create_record {
    my $self = shift;

    # Log4perl logger erzeugen
    my $logger = get_logger();

    # Dispatched Args
    my $view           = $self->param('view')                   || '';

    # Shared Args
    my $query          = $self->query();
    my $config         = $self->param('config');
    my $msg            = $self->param('msg');
    my $path_prefix    = $self->param('path_prefix');
    my $location       = $self->param('location');

    # CGI / JSON input
    my $input_data_ref = $self->parse_valid_input($self->get_input_definition);

    if (!$self->authorization_successful){
        $self->print_authorization_error();
        return;
    }

    my $new_clusterid = $config->new_cluster($input_data_ref);

    if ($self->param('representation') eq "html"){
        $self->query->method('GET');
        $self->query->headers_out->add(Location => "$path_prefix/$config->{admin_clusters_loc}/id/$new_clusterid/edit");
        $self->query->status(Apache2::Const::REDIRECT);
    }
    else {
        $logger->debug("Weiter zum Record");
        if ($new_clusterid){ # Datensatz erzeugt, wenn neue id
            $logger->debug("Weiter zur DB $new_clusterid");
            $self->param('status',Apache2::Const::HTTP_CREATED);
            $self->param('clusterid',$new_clusterid);
            $self->param('location',"$location/$new_clusterid");
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
    my $view             = $self->param('view');
    my $clusterid        = $self->param('clusterid');

    # Shared Args
    my $query          = $self->query();
    my $config         = $self->param('config');
    my $path_prefix    = $self->param('path_prefix');

    # CGI Args
    my $method          = decode_utf8($query->param('_method')) || '';
    my $confirm         = $query->param('confirm')              || 0;

    # CGI / JSON input
    my $input_data_ref = $self->parse_valid_input($self->get_input_definition);

    $input_data_ref->{id} = $clusterid;
    
    if (!$self->authorization_successful){
        $self->print_authorization_error();
        return;
    }

    # Method workaround fuer die Unfaehigkeit von Browsern PUT/DELETE in Forms
    # zu verwenden

    if ($method eq "DELETE"){
        $logger->debug("About to delete $clusterid");
        
        if ($confirm){
        }
        else {
            $logger->debug("Redirecting to delete location");
            $self->delete_record;
            return;
        }
    }

    # Ansonsten POST oder PUT => Aktualisieren

    $config->update_cluster($input_data_ref);

    if ($self->param('representation') eq "html"){
        $self->query->method('GET');
        $self->query->headers_out->add(Location => "$path_prefix/$config->{admin_clusters_loc}");
        $self->query->status(Apache2::Const::REDIRECT);
    }
    else {
        $logger->debug("Weiter zum Record $clusterid");
        $self->show_record;
    }

    return;
}

sub confirm_delete_record {
    my $self = shift;

    # Log4perl logger erzeugen
    my $logger = get_logger();
    
    my $r              = $self->param('r');

    my $view           = $self->param('view');
    my $clusterid      = $self->strip_suffix($self->param('clusterid'));
    my $config         = $self->param('config');

    my $clusterinfo_ref = $config->get_clusterinfo->search({ id => $clusterid})->single;

    my $ttdata={
        clusterid  => $clusterid,
        clusterinfo => $clusterinfo_ref,
    };
    
    $logger->debug("Asking for confirmation");
    $self->print_page($config->{tt_admin_cluster_record_delete_confirm_tname},$ttdata);
    return Apache2::Const::OK;
}

sub delete_record {
    my $self = shift;

    # Log4perl logger erzeugen
    my $logger = get_logger();
    
    my $r                = $self->param('r');

    # Dispatched Args
    my $view            = $self->param('view')                  || '';
    my $clusterid       = $self->param('clusterid')             || '';

    # Shared Args
    my $config         = $self->param('config');
    my $path_prefix    = $self->param('path_prefix');

    if (!$self->authorization_successful){
        $self->print_authorization_error();
        return;
    }

    $config->del_cluster({id => $clusterid});

    $self->query->method('GET');
    $self->query->headers_out->add(Location => "$path_prefix/$config->{admin_clusters_loc}");
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
        status => {
            default  => '',
            encoding => 'utf8',
            type     => 'scalar',
        },
        active => {
            default  => 'false',
            encoding => 'none',
            type     => 'scalar',
        },
    };
}

1;