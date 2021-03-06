#####################################################################
#
#  OpenBib::Handler::PSGI::Clouds
#
#  Dieses File ist (C) 2006-2012 Oliver Flimm <flimm@openbib.org>
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

package OpenBib::Handler::PSGI::Clouds;

use strict;
use warnings;
no warnings 'redefine';
use utf8;

use DBI;
use Encode 'decode_utf8';
use JSON::XS;
use Log::Log4perl qw(get_logger :levels);
use Template;

use OpenBib::Common::Util;
use OpenBib::Config;
use OpenBib::L10N;
use OpenBib::QueryOptions;
use OpenBib::Session;
use OpenBib::Statistics;
use OpenBib::User;
use OpenBib::Template::Utilities;

use base 'OpenBib::Handler::PSGI';

# Run at startup
sub setup {
    my $self = shift;

    $self->start_mode('show_collection');
    $self->run_modes(
        'show_collection'                      => 'show_collection',
        'show_collection_databases'            => 'show_collection_databases',
        'show_collection_databases_record'     => 'show_collection_databases_record',
        'show_record'                          => 'show_record',
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
    my $view           = $self->param('view')           || '';
    
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
    my $format         = $query->param('format')         || '';
    
    my $statistics  = new OpenBib::Statistics();
    my $utils       = new OpenBib::Template::Utilities;

    my $viewdesc      = $config->get_viewdesc_from_viewname($view);

    # TT-Data erzeugen
    my $ttdata={
        format        => $format,
        queryoptions  => $queryoptions,
        query         => $query,
        viewdesc      => $viewdesc,
        statistics    => $statistics,
        utils         => $utils,
    };

    return $self->print_page($config->{tt_clouds_tname},$ttdata);
}

sub show_collection_databases {
    my $self = shift;

    # Log4perl logger erzeugen
    my $logger = get_logger();

    # Dispatched Args
    my $view           = $self->param('view')           || '';
    
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
    my $format         = $query->param('format')         || '';
    
    my $statistics  = new OpenBib::Statistics();
    my $utils       = new OpenBib::Template::Utilities;

    my $viewdesc      = $config->get_viewdesc_from_viewname($view);

    # TT-Data erzeugen
    my $ttdata={
        format        => $format,
        queryoptions  => $queryoptions,
        query         => $query,
        viewdesc      => $viewdesc,
        statistics    => $statistics,
        utils         => $utils,
    };

    return $self->print_page($config->{tt_clouds_databases_tname},$ttdata);
}

sub show_collection_databases_record {
    my $self = shift;

    # Log4perl logger erzeugen
    my $logger = get_logger();

    # Dispatched Args
    my $view           = $self->param('view');
    my $database       = $self->param('database');
    
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
    my $format         = $query->param('format')         || '';
    
    my $statistics  = new OpenBib::Statistics();
    my $utils       = new OpenBib::Template::Utilities;

    my $viewdesc      = $config->get_viewdesc_from_viewname($view);

    # TT-Data erzeugen
    my $ttdata={
        database      => $database,
        format        => $format,
        queryoptions  => $queryoptions,
        query         => $query,
        viewdesc      => $viewdesc,
        statistics    => $statistics,
        utils         => $utils,
    };

    return $self->print_page($config->{tt_clouds_databases_record_tname},$ttdata);
}

sub show_record {
    my $self = shift;

    # Log4perl logger erzeugen
    my $logger = get_logger();

    # Dispatched Args
    my $r              = $self->param('r');
    my $view           = $self->param('view');
    my $cloudid        = $self->strip_suffix($self->param('cloudid'));
    my $database       = $self->param('database');
    
    # Shared Args
    my $query          = $self->query();
    my $config         = $self->param('config');
    my $session        = $self->param('session');
    my $user           = $self->param('user');
    my $msg            = $self->param('msg');
    my $queryoptions   = $self->param('qopts');
    my $stylesheet     = $self->param('stylesheet');
    my $useragent      = $self->param('useragent');
    my $path_prefix    = $self->param('path_prefix');
    
    # CGI Args
    my $format         = $query->param('format')         || '';
    
    my $statistics  = new OpenBib::Statistics();
    my $utils       = new OpenBib::Template::Utilities;

    if ($database){
        $database=$self->strip_suffix($database);
    }
    else {
        $cloudid=$self->strip_suffix($cloudid);
    }
    
    my $viewdesc      = $config->get_viewdesc_from_viewname($view);

    # TT-Data erzeugen
    my $ttdata={
        format        => $format,
        stid          => $cloudid,
        database      => $database,
        query         => $query,
        viewdesc      => $viewdesc,
        statistics    => $statistics,
        utils         => $utils,
    };

    my $templatename = "tt_clouds_".$cloudid."_tname";

    return $self->print_page($config->{$templatename},$ttdata);
}

1;
