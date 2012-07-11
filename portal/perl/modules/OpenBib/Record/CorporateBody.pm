#####################################################################
#
#  OpenBib::Record::CorporateBody.pm
#
#  Koerperschaft
#
#  Dieses File ist (C) 2007-2012 Oliver Flimm <flimm@openbib.org>
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

package OpenBib::Record::CorporateBody;

use strict;
use warnings;
no warnings 'redefine';
use utf8;

use Apache2::Reload;
use Benchmark ':hireswallclock';
use DBI;
use Encode 'decode_utf8';
use JSON::XS;
use Log::Log4perl qw(get_logger :levels);
use SOAP::Lite;
use Storable;
use YAML ();

use OpenBib::Record::Person;
use OpenBib::Record::CorporateBody;
use OpenBib::Record::Subject;
use OpenBib::Record::Classification;
use OpenBib::Search::Util;

use base 'OpenBib::Record';

sub new {
    my ($class,$arg_ref) = @_;

    # Set defaults
    my $id        = exists $arg_ref->{id}
        ? $arg_ref->{id}             : undef;

    my $database  = exists $arg_ref->{database}
        ? $arg_ref->{database}       : undef;

    # Log4perl logger erzeugen
    my $logger = get_logger();

    my $self = { };

    bless ($self, $class);

    $logger->debug("Creating CorporateBody-Record-Object");

    if (defined $database){
        $self->{database} = $database;
        $self->connectDB();
        $logger->debug("Setting CorporateBody database: $database");
    }

    if (defined $id){
        $self->{id}       = $id;
        $logger->debug("Setting CorporateBody id: $id");
    }

    $logger->debug("CorporateBody-Record-Object created with id $id in database $database");

    return $self;
}

sub load_full_record {
    my ($self,$arg_ref) = @_;

    # Set defaults
    my $id                = exists $arg_ref->{id}
        ? $arg_ref->{id}                :
            (exists $self->{id})?$self->{id}:undef;

    # Log4perl logger erzeugen
    
    my $logger = get_logger();

    my $config = OpenBib::Config->instance;

    my $normset_ref={};

    $self->{id      }        = $id;
    $normset_ref->{id      } = $id;
    $normset_ref->{database} = $self->{database};

    my ($atime,$btime,$timeall);

    if ($config->{benchmark}) {
	$atime=new Benchmark;
    }

    # DBI "select category,content,indicator from corporatebody where id = ?";
    my $corporatebody_fields = $self->{schema}->resultset('Corporatebody')->search(
        {
            'me.id' => $id,
        },
        {
            select => ['corporatebody_fields.field','corporatebody_fields.mult','corporatebody_fields.subfield','corporatebody_fields.content'],
            as     => ['thisfield','thismult','thissubfield','thiscontent'],
            join   => ['corporatebody_fields'],
        }
    );
    
    foreach my $item ($corporatebody_fields->all){
        my $field    = "C".sprintf "%04d",$item->get_column('thisfield');
        my $subfield =                    $item->get_column('thissubfield');
        my $mult     =                    $item->get_column('thismult');
        my $content  =                    $item->get_column('thiscontent');
        
        push @{$normset_ref->{$field}}, {
            mult      => $mult,
            subfield  => $subfield,
            content   => $content,
        };
    }

    if ($config->{benchmark}) {
	$btime=new Benchmark;
	$timeall=timediff($btime,$atime);
	$logger->info("Benoetigte Zeit fuer Corporatebodyenbestimmung ist ".timestr($timeall));
	undef $atime;
	undef $btime;
	undef $timeall;
    }

    if ($config->{benchmark}) {
	$atime=new Benchmark;
    }

    # Ausgabe der Anzahl verkuepfter Titel
    my $titcount = $self->get_number_of_titles;
    
    push @{$normset_ref->{C5000}}, {
        content => $titcount,
    };

    if ($config->{benchmark}) {
	$btime=new Benchmark;
	$timeall=timediff($btime,$atime);
	$logger->info("Benoetigte Zeit ist ".timestr($timeall));
	undef $atime;
	undef $btime;
	undef $timeall;
    }

    $logger->debug(YAML::Dump($normset_ref));
    
    $self->{_normset}=$normset_ref;

    return $self;
}

sub load_name {
    my ($self,$arg_ref) = @_;

    # Set defaults
    my $id                = exists $arg_ref->{id}
        ? $arg_ref->{id}                :
            (exists $self->{id})?$self->{id}:undef;

    # Log4perl logger erzeugen
    my $logger = get_logger();

    my $config = OpenBib::Config->instance;

    $logger->debug("Loading main entry");
    my ($atime,$btime,$timeall);

    if ($config->{benchmark}) {
	$atime=new Benchmark;
    }

    # DBI: "select content from corporatebody where id = ? and category=0001";
    my $corporatebody_fields = $self->{schema}->resultset('Corporatebody')->search(
        {
            'me.id'                 => $id,
            'corporatebody_fields.field'   => '0001',
        },
        {
            select => ['corporatebody_fields.content'],
            as     => ['thiscontent'],
            join   => ['corporatebody_fields'],
        }
    )->single;

    my $main_entry="Unbekannt";

    if ($corporatebody_fields){
        $main_entry  =                    $corporatebody_fields->get_column('thiscontent');
    }
    
    if ($config->{benchmark}) {
	$btime=new Benchmark;
	$timeall=timediff($btime,$atime);
	$logger->info("Benoetigte Zeit ist ".timestr($timeall));
	undef $atime;
	undef $btime;
	undef $timeall;
    }

    $self->{name}=$main_entry;

    return $self;
}

sub get_number_of_titles {
    my ($self,$arg_ref) = @_;

    # Set defaults
    my $id                = exists $arg_ref->{id}
        ? $arg_ref->{id}                :
            (exists $self->{id})?$self->{id}:undef;
    
    # Log4perl logger erzeugen
    my $logger = get_logger();

    my $config = OpenBib::Config->instance;
    
    my ($atime,$btime,$timeall);

    if ($config->{benchmark}) {
        $atime=new Benchmark;
    }

    # DBI: "select count(distinct sourceid) as conncount from conn where targetid=? and sourcetype=1 and targettype=3";
    my $titlecount = $self->{schema}->resultset('Corporatebody')->search(
        {
            'me.id'                 => $id,
        },
        {
            join   => ['title_corporatebodies'],
            columns  => [ qw/title_corporatebodies.titleid/ ], # columns/group_by -> versch. titleid 
            group_by => [ qw/title_corporatebodies.titleid/ ], # via group_by und nicht via distinct (Performance)

        }
    )->count;

    return $titlecount;
}

sub to_rawdata {
    my ($self) = @_;

    return $self->{_normset};
}

sub to_json {
    my ($self)=@_;

    my $title_ref = {
        'metadata'    => $self->{_normset},
    };

    return encode_json $title_ref;
}

sub name_as_string {
    my $self=shift;
    
    return $self->{name};
}


1;
