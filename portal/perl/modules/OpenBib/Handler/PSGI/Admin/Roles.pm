#####################################################################
#
#  OpenBib::Handler::PSGI::Admin::Roles
#
#  Dieses File ist (C) 2004-2015 Oliver Flimm <flimm@openbib.org>
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

package OpenBib::Handler::PSGI::Admin::Roles;

use strict;
use warnings;
no warnings 'redefine';
use utf8;

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
use OpenBib::L10N;
use OpenBib::QueryOptions;
use OpenBib::Session;
use OpenBib::Statistics;
use OpenBib::User;

use base 'OpenBib::Handler::PSGI::Admin';

# Run at startup
sub setup {
    my $self = shift;

    $self->start_mode('show_collection');
    $self->run_modes(
        'show_collection'           => 'show_collection',
        'show_record'               => 'show_record',
        'show_record_form'          => 'show_record_form',
        'create_record'             => 'create_record',
        'update_record'             => 'update_record',
        'confirm_delete_record'     => 'confirm_delete_record',
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
    my $view           = $self->param('view')                   || '';

    # Shared Args
    my $config         = $self->param('config');

    if (!$self->authorization_successful('right_read')){
        return $self->print_authorization_error();
    }

    my $roleinfos_ref = $config->get_roleinfo_overview;
    
    my $ttdata = {
        roleinfos => $roleinfos_ref,
    };
    
    return $self->print_page($config->{tt_admin_roles_tname},$ttdata);
}

sub show_record_form {
    my $self = shift;

    # Log4perl logger erzeugen
    my $logger = get_logger();

    # Dispatches Args
    my $view             = $self->param('view');
    my $roleid           = $self->param('roleid');

    # Shared Args
    my $config           = $self->param('config');
    my $queryoptions     = $self->param('qopts');

    if (!$self->authorization_successful('right_update')){
        return $self->print_authorization_error();
    }

    my $viewinfo_ref = $config->get_viewinfo_overview();
    
    my $roleinfo_ref = $config->get_roleinfo->search_rs({ rolename => $roleid })->single;

    my $selected_views_ref = {};
    
    foreach my $viewname ($config->get_views_of_role($roleid)){
        $selected_views_ref->{$viewname} = 1;
    }

    my $all_scopes_ref     = $config->get_scopes;

    my $rights_of_role_ref = $config->get_rights_of_role($roleid);
    
    my $ttdata = {
        roleid           => $roleid,
        roleinfo         => $roleinfo_ref,
        viewinfos        => $viewinfo_ref,
        selected_views   => $selected_views_ref,
        all_scopes       => $all_scopes_ref,
        rights_of_role   => $rights_of_role_ref,
    };
    
    return $self->print_page($config->{tt_admin_roles_record_edit_tname},$ttdata);
}

sub show_record {
    my $self = shift;

    # Log4perl logger erzeugen
    my $logger = get_logger();

    # Dispatches Args
    my $view             = $self->param('view');
    my $roleid         = $self->strip_suffix($self->param('roleid'));

    # Shared Args
    my $config           = $self->param('config');

    if (!$self->authorization_successful('right_read')){
        return $self->print_authorization_error();
    }

    my $viewinfo_ref = $config->get_viewinfo_overview();
    
    my $roleinfo_ref = $config->get_roleinfo->search_rs({ rolename => $roleid })->single;

    my $selected_views_ref = {};
    
    foreach my $viewname ($config->get_views_of_role($roleid)){
        $selected_views_ref->{$viewname} = 1;
    }

    my $all_scopes_ref     = $config->get_scopes;

    my $rights_of_role_ref = $config->get_rights_of_role($roleid);
    
    my $ttdata = {
        roleid           => $roleid,
        roleinfo         => $roleinfo_ref,
        viewinfos        => $viewinfo_ref,
        selected_views   => $selected_views_ref,
        all_scopes       => $all_scopes_ref,
        rights_of_role   => $rights_of_role_ref,
    };
    
    return $self->print_page($config->{tt_admin_roles_record_tname},$ttdata);
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
    my $lang           = $self->param('lang');
    my $user           = $self->param('user');
    my $path_prefix    = $self->param('path_prefix');
    my $location       = $self->param('location');

    # CGI / JSON input
    my $input_data_ref = $self->parse_valid_input($self->get_input_definition);

    if (!$self->authorization_successful('right_create')){
        return $self->print_authorization_error();
    }

    if ($input_data_ref->{rolename} eq "") {
        return $self->print_warning($msg->maketext("Sie müssen einen Rollennamen eingeben."));
    }

    if ($config->role_exists($input_data_ref->{rolename})){
        return $self->print_warning($msg->maketext("Rollenname ist bereits vergeben."));
    }
    
    my $new_roleid = $config->new_role($input_data_ref);

    if ($self->param('representation') eq "html"){
        # TODO GET?
        $self->redirect("$path_prefix/$config->{admin_loc}/$config->{roles_loc}/id/$input_data_ref->{rolename}/edit.html?l=$lang");
        return ;
    }
    else {
        $logger->debug("Weiter zum Record");
        if ($new_roleid){ # Datensatz erzeugt, wenn neue id
            $logger->debug("Weiter zur DB $new_roleid");
            $self->param('status',201); # created
            $self->param('roleid',$input_data_ref->{rolename});
            $self->param('location',"$location/$input_data_ref->{rolename}");
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
    my $view           = $self->param('view');
    my $roleid         = $self->param('roleid');

    # Shared Args
    my $query          = $self->query();
    my $config         = $self->param('config');
    my $path_prefix    = $self->param('path_prefix');

    # CGI / JSON input
    my $input_data_ref = $self->parse_valid_input($self->get_input_definition);

    $input_data_ref->{rolename} = $roleid;
    
    if (!$self->authorization_successful('right_update')){
        return $self->print_authorization_error();
    }

    if ($logger->is_debug){
        $logger->debug(YAML::Dump($input_data_ref));
    }
    
    $config->update_role($input_data_ref);

    if ($self->param('representation') eq "html"){
        # TODO GET?
        return $self->redirect("$path_prefix/$config->{roles_loc}");
    }
    else {
        $logger->debug("Weiter zum Record $roleid");
        return $self->show_record;
    }
}

sub confirm_delete_record {
    my $self = shift;

    # Log4perl logger erzeugen
    my $logger = get_logger();
    
    my $r              = $self->param('r');

    my $view           = $self->param('view');
    my $roleid         = $self->strip_suffix($self->param('roleid'));
    my $config         = $self->param('config');

    my $roleinfo_ref = $config->get_roleinfo->search({ rolename => $roleid})->single;

    my $ttdata={
        roleinfo => $roleinfo_ref,
    };
    
    $logger->debug("Asking for confirmation");

    return $self->print_page($config->{tt_admin_roles_record_delete_confirm_tname},$ttdata);
}

sub delete_record {
    my $self = shift;

    # Log4perl logger erzeugen
    my $logger = get_logger();
    
    my $r              = $self->param('r');

    # Dispatched Args
    my $view           = $self->param('view')               || '';
    my $roleid         = $self->param('roleid')             || '';

    # Shared Args
    my $config         = $self->param('config');
    my $path_prefix    = $self->param('path_prefix');

    if (!$self->authorization_successful('right_delete')){
        return $self->print_authorization_error();
    }

    $config->delete_role($roleid);

    #TODO GET?
    return unless ($self->param('representation') eq "html");

    $self->header_add('Content-Type' => 'text/html');

    return $self->redirect("$path_prefix/$config->{roles_loc}");
}

sub get_input_definition {
    my $self=shift;
    
    return {
        rolename => {
            default  => '',
            encoding => 'none',
            type     => 'scalar',
        },
        description => {
            default  => '',
            encoding => 'utf8',
            type     => 'scalar',
        },
        views => {
            default  => [],
            encoding => 'none',
            type     => 'array',
        },
        # Muster: scope|right_XXX
        rights => {
            default  => [],
            encoding => 'none',
            type     => 'rights',
        },
    };
}

1;
