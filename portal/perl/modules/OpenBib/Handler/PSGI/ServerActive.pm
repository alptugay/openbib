#####################################################################
#
#  OpenBib::Handler::PSGI::ServerActive
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

package OpenBib::Handler::PSGI::ServerActive;

use strict;
use warnings;
no warnings 'redefine';
use utf8;

use DBI;
use Log::Log4perl qw(get_logger :levels);

use OpenBib::Config;

use base 'OpenBib::Handler::PSGI';

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

# Reihenfolgen der Abarbeitung
#
# 1) cgiapp_init   : Content-Negotiation
# 2) cgiapp_prerun : Benoetigte Informationen fuer die Handler sammeln und anbieten

sub cgiapp_init {
    my $self = shift;

    # Explicitly do *nothing*
    return;
}

sub cgiapp_prerun {

    # Explicitly do *nothing*
    return;
}

sub show {
    my $self = shift;

    # Log4perl logger erzeugen
    my $logger = get_logger();

    my $r              = $self->param('r');
    my $config         = OpenBib::Config->new;


    if ($config->local_server_is_active_and_searchable){
        $self->header_add('Status' => 200);
        $self->header_add('Content-Type' => 'text/plain');
        return 'enabled';
    }
    else {
        $self->header_add('Status' => 404);
        return;
    }
}

1;

