#####################################################################
#
#  OpenBib::Importer::JSON::CorporateBody.pm
#
#  Koerperschaft
#
#  Dieses File ist (C) 2014-2015 Oliver Flimm <flimm@openbib.org>
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

package OpenBib::Importer::JSON::CorporateBody;

use strict;
use warnings;
no warnings 'redefine';
use utf8;

use Benchmark ':hireswallclock';
use Digest::MD5 qw(md5_hex);
use Encode qw/decode_utf8/;
use JSON::XS;
use Log::Log4perl qw(get_logger :levels);
use YAML ();
use Business::ISBN;

use OpenBib::Common::Util;
use OpenBib::Config;
use OpenBib::Conv::Config;
use OpenBib::Container;
use OpenBib::Index::Document;

use base 'OpenBib::Importer::JSON';

sub process {
    my ($self,$arg_ref) = @_;

    my $json      = exists $arg_ref->{json}
        ? $arg_ref->{json}           : undef;

    # Log4perl logger erzeugen
    my $logger = get_logger();

    return $self unless (defined $json);

    my $database    = $self->{database};

    $logger->debug("Processing JSON: $json");

    # Cleanup
    $self->{_columns}                = [];
    $self->{_columns_fields}         = [];
    
    my $inverted_ref  = $self->{conv_config}{inverted_corporatebody};
    my $blacklist_ref = $self->{conv_config}{blacklist_corporatebody};
    
    my $record_ref;

    my $import_hash = "";

    if ($json){
        $import_hash = md5_hex($json);
        
        eval {
            $record_ref = decode_json $json;
        };
        
        if ($@){
            $logger->error("Skipping record: $@");
            return;
        }
    }

    $logger->debug("JSON decoded");
    
    my $id            = $record_ref->{id};
    my $fields_ref    = $record_ref->{fields};

    # Primaeren Normdatensatz erstellen und schreiben
            
    my $create_tstamp = "1970-01-01 12:00:00";
    
    if (defined $fields_ref->{'0002'} && defined $fields_ref->{'0002'}[0]) {
        $create_tstamp = $fields_ref->{'0002'}[0]{content};
        if ($create_tstamp=~/^(\d\d)\.(\d\d)\.(\d\d\d\d)/) {
            $create_tstamp=$3."-".$2."-".$1." 12:00:00";
        }
    }
    
    my $update_tstamp = "1970-01-01 12:00:00";
    
    if (exists $fields_ref->{'0003'} && exists $fields_ref->{'0003'}[0]) {
        $update_tstamp = $fields_ref->{'0003'}[0]{content};
        if ($update_tstamp=~/^(\d\d)\.(\d\d)\.(\d\d\d\d)/) {
            $update_tstamp=$3."-".$2."-".$1." 12:00:00";
        }            
    }

    push @{$self->{_columns}}, [$id,$create_tstamp,$update_tstamp,$import_hash];
    
    # Ansetzungsformen fuer Kurztitelliste merken
    
    my $mainentry;
    
    if (exists $fields_ref->{'0800'} && exists $fields_ref->{'0800'}[0] ) {
        $mainentry = $fields_ref->{'0800'}[0]{content};
    }
    
    if ($mainentry) {
        $self->{storage}{listitemdata_corporatebody}{$id}=$mainentry;
    }
    
    foreach my $field (keys %{$fields_ref}) {
        next if ($field eq "id" || defined $blacklist_ref->{$field} );
        foreach my $item_ref (@{$fields_ref->{$field}}) {
            if (exists $inverted_ref->{$field}->{index}) {
                foreach my $searchfield (keys %{$inverted_ref->{$field}->{index}}) {
                    my $weight = $inverted_ref->{$field}->{index}{$searchfield};
                    
                    my $hash_ref = {};
                    if (exists $self->{storage}{indexed_corporatebody}{$id}) {
                        $hash_ref = $self->{storage}{indexed_corporatebody}{$id};
                    }
                    push @{$hash_ref->{$searchfield}{$weight}}, ["C$field",$item_ref->{content}];
                    
                    $self->{storage}{indexed_corporatebody}{$id} = $hash_ref;
                }
            }
            
            if ($id && $field && defined $item_ref->{content}) {
                $item_ref->{content} = $self->cleanup_content($item_ref->{content});
                # Abhaengige Feldspezifische Saetze erstellen und schreiben
                push @{$self->{_columns_fields}}, [$self->{serialid},$id,$field,$item_ref->{mult},$item_ref->{subfield},$item_ref->{content}];
                $self->{serialid}++;
            }
        }
    }
    
    return $self;
}

1;
