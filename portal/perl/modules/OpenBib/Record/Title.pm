#####################################################################
#
#  OpenBib::Record::Title.pm
#
#  Titel
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

package OpenBib::Record::Title;

use strict;
use warnings;
no warnings 'redefine';
use utf8;

use Apache2::Reload;
use Benchmark ':hireswallclock';
use Business::ISBN;
use DBIx::Class::ResultClass::HashRefInflator;
use DBI;
use Encode 'decode_utf8';
use JSON::XS;
use Log::Log4perl qw(get_logger :levels);
use SOAP::Lite;
use Storable;
use XML::LibXML;
use YAML ();

use OpenBib::BibSonomy;
use OpenBib::Catalog::Factory;
use OpenBib::Common::Util;
use OpenBib::Config;
use OpenBib::Config::CirculationInfoTable;
use OpenBib::Config::DatabaseInfoTable;
use OpenBib::Conv::Config;
use OpenBib::Index::Document;
use OpenBib::Schema::Catalog;
use OpenBib::Schema::Enrichment;
use OpenBib::Schema::DBI;
use OpenBib::L10N;
use OpenBib::QueryOptions;
use OpenBib::Record::Person;
use OpenBib::Record::CorporateBody;
use OpenBib::Record::Subject;
use OpenBib::Record::Classification;
use OpenBib::RecordList::Title;
use OpenBib::Search::Util;
use OpenBib::SearchQuery;
use OpenBib::Session;
use OpenBib::User;

use base 'OpenBib::Record';

sub new {
    my ($class,$arg_ref) = @_;

    # Set defaults
    my $id        = exists $arg_ref->{id}
        ? $arg_ref->{id}             : undef;

    my $database  = exists $arg_ref->{database}
        ? $arg_ref->{database}       : undef;

    my $date      = exists $arg_ref->{date}
        ? $arg_ref->{date}           : undef;

    my $listid    = exists $arg_ref->{listid}
        ? $arg_ref->{listid}         : undef;

    my $comment   = exists $arg_ref->{comment}
        ? $arg_ref->{comment}        : undef;

    my $generic_attributes = exists $arg_ref->{generic_attributes}
        ? $arg_ref->{generic_attributes}   : {};

    # Log4perl logger erzeugen
    my $logger = get_logger();

    my $self = { };

    bless ($self, $class);

    $self->{_same_records}    = new OpenBib::RecordList::Title();
    $self->{_similar_records} = new OpenBib::RecordList::Title();
    $self->{_related_records} = new OpenBib::RecordList::Title();

    if (defined $database){
        $self->{database} = $database;
    }

    if (defined $id){
        $self->{id}           = $id;
    }

    if (defined $date){
        $self->{date}     = $date;
    }

    if (defined $comment){
        $self->{comment}  = $comment;
    }
    
    if (defined $listid){
        $self->{listid}   = $listid;
    }

    if (defined $generic_attributes){
        $self->{generic_attributes}   = $generic_attributes;
    }

    if (defined $id && defined $database){
        $logger->debug("Title-Record-Object created with id $id in database $database");
    }
    
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

    # (Re-)Initialisierung
    delete $self->{_fields}         if (exists $self->{_fields});
    delete $self->{_holding}        if (exists $self->{_holding});
    delete $self->{_circulation}    if (exists $self->{_circulation});

    my $fields_ref   = {};

    $self->{id      }        = $id;

    unless (defined $self->{id} && defined $self->{database}){
        ($self->{_fields},$self->{_holding},$self->{_circulation})=({},(),[]);

        $logger->error("Incomplete Record-Information Id: ".((defined $self->{id})?$self->{id}:'none')." Database: ".((defined $self->{database})?$self->{database}:'none'));
        return $self;
    }

    my $catalog = OpenBib::Catalog::Factory->create_catalog({ database => $self->{database}});
    
    my $record = $catalog->load_full_title_record({id => $id});
    
    $logger->debug("Zurueck ".YAML::Dump($record->get_fields));
    
    $self->set_fields($record->get_fields);
    $self->set_holding($record->get_holding);
    $self->load_circulation;
    
    return $self;
}

sub load_brief_record {
    my ($self,$arg_ref) = @_;

    # Set defaults
    my $id                = exists $arg_ref->{id}
        ? $arg_ref->{id}                :
            (exists $self->{id})?$self->{id}:undef;

    # Log4perl logger erzeugen
    my $logger = get_logger();

    my $config = OpenBib::Config->instance;

    # (Re-)Initialisierung
    delete $self->{_fields}       if (exists $self->{_fields});
    delete $self->{_holding}        if (exists $self->{_holding});
    delete $self->{_circulation}    if (exists $self->{_circulation});

    my $record_exists = 0;

    my $fields_ref   = {};

    $self->{id      }        = $id;

    unless (defined $self->{id} && defined $self->{database}){
        ($self->{_fields},$self->{_holding},$self->{_circulation})=({},(),[]);

        $logger->error("Incomplete Record-Information Id: ".((defined $self->{id})?$self->{id}:'none')." Database: ".((defined $self->{database})?$self->{database}:'none'));
        return $self;
    }

    my ($atime,$btime,$timeall)=(0,0,0);
    
    if ($config->{benchmark}) {
        $atime  = new Benchmark;
    }

    my $catalog = OpenBib::Catalog::Factory->create_catalog({ database => $self->{database}});
    
    my $record = $catalog->load_brief_title_record({id => $id});

    $fields_ref         = $record->get_fields;
    $record_exists      = $record->record_exists;

    # Titel-ID und zugehoerige Datenbank setzen

    $fields_ref->{id      } = $id;
    $fields_ref->{database} = $self->{database};

    if ($config->{benchmark}) {
        $btime=new Benchmark;
        $timeall=timediff($btime,$atime);
        my $timeall=timediff($btime,$atime);
        $logger->info("Zeit fuer : Bestimmung der gesamten Informationen         : ist ".timestr($timeall));
    }

    $logger->debug(YAML::Dump($fields_ref));

    ($self->{_fields},$self->{_exists},$self->{_type})=($fields_ref,$record_exists,'brief');

    return $self;
}

sub enrich_content {
    my ($self, $arg_ref) = @_;

    my $profilename = exists $arg_ref->{profilename}
        ? $arg_ref->{profilename}        : undef;
    
    my $viewname = exists $arg_ref->{viewname}
        ? $arg_ref->{viewname}        : undef;

    # Log4perl logger erzeugen
    my $logger = get_logger();
    
    my $config = OpenBib::Config->instance;

    my ($atime,$btime,$timeall);
        
    if ($config->{benchmark}) {
        $atime=new Benchmark;
    }
    
    if (!exists $self->{enrich_schema}){
        $self->connectEnrichmentDB;
        $self->{enrich_schema}->storage->debug(1);
    }

    my @isbn_refs = ();
    push @isbn_refs, @{$self->get_field({field => 'T0540'})} if ($self->has_field('T0540'));
    push @isbn_refs, @{$self->get_field({field => 'T0553'})} if ($self->has_field('T0553'));
    
    my $bibkey    = $self->get_field({field => 'T5050', mult => 1});
    
    my @issn_refs = ();
    push @issn_refs, @{$self->get_field({field => 'T0543'})} if ($self->has_field('T0543'));                                           
    
    $logger->debug("Enrichment ISBN's ".YAML::Dump(\@isbn_refs));
    $logger->debug("Enrichment ISSN's ".YAML::Dump(\@issn_refs));
    
    my %seen_content = ();            
    
    my $mult_map_ref = {};
    

    if (@isbn_refs){
        my @filter_databases = ($profilename)?$config->get_profiledbs($profilename):
            ($viewname)?$config->get_viewdbs($viewname):();


        if ($config->{benchmark}) {
            $btime=new Benchmark;
            $timeall=timediff($btime,$atime);
            $logger->info("Zeit fuer : Bestimmung von Enrich-Informationen vor Normdaten ".timestr($timeall));
        }

        $logger->debug("Filtern Profile: $profilename / View: $viewname nach Datenbanken ".YAML::Dump(\@filter_databases));
        
        my @isbn_refs_tmp = ();
        
        # Normierung auf ISBN-13
        foreach my $isbn_ref (@isbn_refs){
            my $thisisbn = $isbn_ref->{content};
            
            # Alternative ISBN zur Rechercheanrei
            my $isbn     = Business::ISBN->new($thisisbn);
            
            if (defined $isbn && $isbn->is_valid){
                $thisisbn = $isbn->as_isbn13->as_string;
            }
            
            push @isbn_refs_tmp, OpenBib::Common::Util::normalize({
                field => 'T0540',
                content  => $thisisbn,
            });
            
        }
        
        # Dubletten Bereinigen
        my %seen_isbns = ();
        
        @isbn_refs = grep { ! $seen_isbns{$_} ++ } @isbn_refs_tmp;
        
        $logger->debug("Relevante ISBNs des Titels fuer die Anreicherung: ".YAML::Dump(\@isbn_refs));

        # Anreicherung der Normdaten
        {
            # DBI "select distinct category,content from normdata where isbn=? order by category,indicator";
            my $enriched_contents = $self->{enrich_schema}->resultset('EnrichedContentByIsbn')->search_rs(
                {
                    isbn => \@isbn_refs,
                },
                {
                    group_by => ['isbn','field','content','origin','subfield'],
                    order_by => ['field','content'],
                    result_class => 'DBIx::Class::ResultClass::HashRefInflator',
                }
            );

            while (my $item = $enriched_contents->next) {
                my $field      = "E".sprintf "%04d",$item->{field};
                my $subfield   =                    $item->{subfield};
                my $content    =                    $item->{content};

                if ($seen_content{$content}) {
                    next;
                }
                else {
                    $seen_content{$content} = 1;
                }
                my $mult = ++$mult_map_ref->{$field};
                $self->set_field({
                    field      => $field,
                    subfield   => $subfield,
                    mult       => $mult,
                    content    => $content,
                });
            }
        }
        
        if ($config->{benchmark}) {
            $btime=new Benchmark;
            $timeall=timediff($btime,$atime);
            $logger->info("Zeit fuer : Bestimmung von Enrich-Informationen / inkl Normdaten ist ".timestr($timeall));
        }
        
        # Anreicherung mit 'gleichen' (=gleiche ISBN) Titeln aus anderen Katalogen
        {
            # Same Records via Backend sind Grundlage.               
            my $same_recordlist = $self->get_same_records;
            
            $logger->debug("Same records via backend ".YAML::Dump($same_recordlist));

            my $where_ref = {
                isbn    => \@isbn_refs,
                titleid => {'!=' => $self->{id} },
                dbname  => {'!=' => $self->{database}}
            };
            
            if (@filter_databases){
                $where_ref = {
                    isbn    => \@isbn_refs,
                    titleid => {'!=' => $self->{id} },
                    -and => [
                        {
                            dbname  => {'!=' => $self->{database}}
                        },
                        {
                            dbname => \@filter_databases,
                        },
                    ]
                };
            }
            
            # DBI: "select distinct id,dbname from all_isbn where isbn=? and dbname != ? and id != ?";
            my $same_titles = $self->{enrich_schema}->resultset('AllTitleByIsbn')->search_rs(
                $where_ref,
                {
                    group_by => ['titleid','dbname','isbn','tstamp'],
                    result_class => 'DBIx::Class::ResultClass::HashRefInflator',
                }
            );
            
            #            $logger->debug("Found ".($same_titles->count)." records");
            
            while (my $item = $same_titles->next) {
                my $id         = $item->{titleid};
                my $database   = $item->{dbname};
                
                $same_recordlist->add(new OpenBib::Record::Title({ id => $id, database => $database}));
            }
            
            $same_recordlist->load_brief_records;
            
            $self->set_same_records($same_recordlist);
        }
        
        if ($config->{benchmark}) {
            $btime=new Benchmark;
            $timeall=timediff($btime,$atime);
            $logger->info("Zeit fuer : Bestimmung von Enrich-Informationen / inkl Normdaten/Same Titles ist ".timestr($timeall));
        }
        
        # Anreicherung mit 'aehnlichen' (=andere Auflage, Sprache) Titeln aus allen Katalogen
        {
            my $similar_recordlist = $self->get_similar_records;
            
            $logger->debug("Similar records via backend ".YAML::Dump($similar_recordlist));
            
            # Alle Werke zu gegebenen ISBNs bestimmen
            my $works = $self->{enrich_schema}->resultset('WorkByIsbn')->search_rs(
                {
                    isbn    => \@isbn_refs,,
                },
                {
                    columns => ['workid'],
                    group_by => ['workid'],
                }
            );
            
            my $similar_isbns = $self->{enrich_schema}->resultset('WorkByIsbn')->search_rs(
                {
                    isbn      => { '!=' => \@isbn_refs },
                    workid    => { -in => $works->as_query },
                },
                {
                    columns => ['isbn'],
                    group_by => ['isbn'],
                }
            );
            
            my $where_ref = {
                isbn    => { -in => $similar_isbns->as_query },
            };
            
            if (@filter_databases){
                $where_ref = {
                    isbn    => { -in => $similar_isbns->as_query },                            
                    dbname => \@filter_databases,
                };
            }
            
            my $titles = $self->{enrich_schema}->resultset('AllTitleByIsbn')->search_rs(
                $where_ref,
                {
                    group_by => ['dbname','isbn','tstamp','titleid'],
                    result_class => 'DBIx::Class::ResultClass::HashRefInflator',
                }
            );
            
            while (my $titleitem = $titles->next) {
                my $id         = $titleitem->{titleid};
                my $database   = $titleitem->{dbname};
                
                $logger->debug("Found Title with id $id in database $database");
                
                $similar_recordlist->add(new OpenBib::Record::Title({ id => $id, database => $database}));
            }

            $similar_recordlist->load_brief_records;
            
            $self->set_similar_records($similar_recordlist);
        }
        
        if ($config->{benchmark}) {
            $btime=new Benchmark;
            $timeall=timediff($btime,$atime);
            $logger->info("Zeit fuer : Bestimmung von Enrich-Informationen / inkl Normdaten/Same Titles/Similar Titles ist ".timestr($timeall));
        }
        
        # Anreichern mit thematisch verbundenen Titeln (z.B. via Wikipedia) im gleichen Katalog(!)
        {
            my $ctime;
            my $dtime;
            if ($config->{benchmark}) {
                $ctime=new Benchmark;
            }

            my $related_recordlist = $self->get_related_records;
            
            $logger->debug("Related records via backend ".YAML::Dump($related_recordlist));
            
            my $titles_found_ref = {}; # Ein Titel kann ueber verschiedenen ISBNs erreicht werden. Das laesst sich nicht trivial via SQL loesen, daher haendisch                    
            
            my $related_ids = $self->{enrich_schema}->resultset('RelatedTitleByIsbn')->search_rs(
                {
                    isbn    => \@isbn_refs,
                },
                {
                    columns => ['id'],
                    group_by => ['id'],
                }
            );
            
            $logger->debug("Found ".($related_ids->count)." related isbns");
            
            my $related_isbns = $self->{enrich_schema}->resultset('RelatedTitleByIsbn')->search_rs(
                {
                    isbn      => { '!=' => \@isbn_refs },
                    id    => { -in => $related_ids->as_query },
                },
                {
                    columns => ['isbn'],
                    group_by => ['isbn'],
                }
            );
            
            $logger->debug("Found ".($related_isbns->count)." isbns");
            
            my $where_ref = {
                isbn    => { -in => $related_isbns->as_query },
            };
            
            if (@filter_databases){
                $where_ref = {
                    isbn    => { -in => $related_isbns->as_query },
                    dbname => \@filter_databases,
                };
            }
            
            my $titles = $self->{enrich_schema}->resultset('AllTitleByIsbn')->search_rs(
                $where_ref,
                {
                    group_by => ['dbname','isbn','tstamp','titleid'],
                    result_class => 'DBIx::Class::ResultClass::HashRefInflator',
                    rows => 20,
                }
            );
            
            while (my $titleitem = $titles->next) {
                my $id         = $titleitem->{titleid};
                my $database   = $titleitem->{dbname};
                
                next if (defined $titles_found_ref->{"$database:$id"});
                $related_recordlist->add(new OpenBib::Record::Title({ id => $id, database => $database}));
                $titles_found_ref->{"$database:$id"} = 1;
            }

            if ($config->{benchmark}) {
                $dtime=new Benchmark;
                $timeall=timediff($dtime,$ctime);
                $logger->info("Zeit fuer : Bestimmung von Enrich-Informationen related_recordlist ist ".timestr($timeall));
            }

            $related_recordlist->load_brief_records;
            $related_recordlist->sort({order => 'up', type => 'title'});
            
            $self->set_related_records($related_recordlist);
            
        }
    }
    elsif ($bibkey){
        # DBI "select category,content from normdata where isbn=? order by category,indicator";
        my $enriched_contents = $self->{enrich_schema}->resultset('EnrichedContentByBibkey')->search_rs(
            {
                bibkey => $bibkey,
            },
            {                        
                group_by => ['field','content','bibkey','origin','subfield'],
                order_by => ['field','content'],
                result_class => 'DBIx::Class::ResultClass::HashRefInflator',
            }
        );
        
        while (my $item = $enriched_contents->next) {
            my $field      = "E".sprintf "%04d",$item->{field};
            my $subfield   =                    $item->{subfield};
            my $content    =                    $item->{content};
            
            if ($seen_content{$content}) {
                next;
            }
            else {
                $seen_content{$content} = 1;
            }                    
            
            my $mult = ++$mult_map_ref->{$field};
            
            $self->set_field({
                field      => $field,
                subfield   => $subfield,
                mult       => $mult,
                content    => $content,
            });
        }
    }
    elsif (@issn_refs){
        my @issn_refs_tmp = ();
        # Normierung
        
        foreach my $issn_ref (@issn_refs){
            my $thisissn = $issn_ref->{content};
            
            push @issn_refs_tmp, OpenBib::Common::Util::normalize({
                field => 'T0543',
                content  => $thisissn,
            });
            
        }
        
        # Dubletten Bereinigen
        my %seen_issns = ();
        
        @issn_refs = grep { ! $seen_issns{$_} ++ } @issn_refs_tmp;
        
        $logger->debug("ISSN: ".YAML::Dump(\@issn_refs));
        
        # DBI "select category,content from normdata where isbn=? order by category,indicator"
        my $enriched_contents = $self->{enrich_schema}->resultset('EnrichedContentByIssn')->search_rs(
            {
                issn => \@issn_refs,
            },
            {                        
                group_by => ['field','content','issn','origin','subfield'],
                order_by => ['field','content'],
                result_class => 'DBIx::Class::ResultClass::HashRefInflator',
            }
        );
        
        while (my $item = $enriched_contents->next) {
            my $field      = "E".sprintf "%04d",$item->{field};
            my $subfield   =                    $item->{subfield};
            my $content    =                    $item->{content};
            
            if ($seen_content{$content}) {
                next;
            } else {
                $seen_content{$content} = 1;
            }                    
            
            my $mult = ++$mult_map_ref->{$field};
            
            $self->set_field({
                field      => $field,
                subfield   => $subfield,
                mult       => $mult,
                content    => $content,
            });
        }
        
        
    }
    
    if ($config->{benchmark}) {
        $btime=new Benchmark;
        $timeall=timediff($btime,$atime);
        $logger->info("Zeit fuer : Bestimmung von Enrich-Informationen ist ".timestr($timeall));
        undef $atime;
        undef $btime;
        undef $timeall;
    }

    return;
}

sub load_circulation {
    my ($self,$arg_ref) = @_;

    # Set defaults
    my $id                = exists $arg_ref->{id}
        ? $arg_ref->{id}                :
            (exists $self->{id})?$self->{id}:undef;

    # Log4perl logger erzeugen
    my $logger = get_logger();

    my $config        = OpenBib::Config->instance;
    my $circinfotable = OpenBib::Config::CirculationInfoTable->instance;
    my $dbinfotable   = OpenBib::Config::DatabaseInfoTable->instance;

    # Ausleihinformationen der Exemplare
    my $circulation_ref = [];
    {
        my $circexlist=undef;
        
        if (exists $circinfotable->{$self->{database}}{circ}) {

            eval {
                my $soap = SOAP::Lite
                    -> uri("urn:/MediaStatus")
                        -> proxy($circinfotable->{$self->{database}}{circcheckurl});
                my $result = $soap->get_mediastatus(
                    SOAP::Data->name(parameter  =>\SOAP::Data->value(
                        SOAP::Data->name(katkey   => $id)->type('string'),
                        SOAP::Data->name(database => $circinfotable->{$self->{database}}{circdb})->type('string'))));
                
                unless ($result->fault) {
                    $circexlist=$result->result;
                }
                else {
                    $logger->error("SOAP MediaStatus Error", join ', ', $result->faultcode, $result->faultstring, $result->faultdetail);
                }
            };
            
            if ($@){
                $logger->error("SOAP-Target konnte nicht erreicht werden :".$@);
            }
            
        }
        
        # Bei einer Ausleihbibliothek haben - falls Exemplarinformationen
        # in den Ausleihdaten vorhanden sind -- diese Vorrange ueber die
        # titelbasierten Exemplardaten
        
        if (defined($circexlist)) {
            $circulation_ref = $circexlist;
        }
        
        # Anreichern mit Bibliotheksinformationen
        if (exists $circinfotable->{$self->{database}}{circ}
                && @{$circulation_ref}) {
            for (my $i=0; $i < scalar(@{$circulation_ref}); $i++) {
                
                my $bibliothek="-";
                my $sigel=$dbinfotable->{dbases}{$self->{database}};
                
                if (length($sigel)>0) {
                    if (exists $dbinfotable->{sigel}{$sigel}) {
                        $bibliothek=$dbinfotable->{sigel}{$sigel};
                    } else {
                        $bibliothek="($sigel)";
                    }
                } else {
                    if (exists $dbinfotable->{sigel}{$dbinfotable->{dbases}{$self->{database}}}) {
                        $bibliothek=$dbinfotable->{sigel}{
                            $dbinfotable->{dbases}{$self->{database}}};
                    }
                }
                
                my $bibinfourl=$dbinfotable->{bibinfo}{
                    $dbinfotable->{dbases}{$self->{database}}};
                
                $circulation_ref->[$i]{'Bibliothek'} = $bibliothek;
                $circulation_ref->[$i]{'Bibinfourl'} = $bibinfourl;
                $circulation_ref->[$i]{'Ausleihurl'} = $circinfotable->{$self->{database}}{circurl};
            }
        } else {
            $circulation_ref=[];
        }
    }

    $self->set_circulation($circulation_ref);

    return $self;
}

sub load_olwsviewer {
    my ($self,$arg_ref) = @_;

    # Set defaults
    my $id                = exists $arg_ref->{id}
        ? $arg_ref->{id}                :
            (exists $self->{id})?$self->{id}:undef;

    # Log4perl logger erzeugen
    my $logger = get_logger();

    my $config        = OpenBib::Config->instance;
    my $circinfotable = OpenBib::Config::CirculationInfoTable->instance;
    my $dbinfotable   = OpenBib::Config::DatabaseInfoTable->instance;

    # Anreicherung mit OLWS-Daten
    if (exists $circinfotable->{$self->{database}} && exists $circinfotable->{$self->{database}}{circcheckurl}){
        $logger->debug("Endpoint: ".$circinfotable->{$self->{database}}{circcheckurl});
        my $soapresult;
        eval {
            my $soap = SOAP::Lite
                -> uri("urn:/Viewer")
                    -> proxy($circinfotable->{$self->{database}}{circcheckurl});
            
            my $result = $soap->get_item_info(
                SOAP::Data->name(parameter  =>\SOAP::Data->value(
                    SOAP::Data->name(collection => $circinfotable->{$self->{database}}{circdb})->type('string'),
                    SOAP::Data->name(item       => $self->{id})->type('string'))));
            
            unless ($result->fault) {
                $soapresult=$result->result;
            }
            else {
                $logger->error("SOAP Viewer Error", join ', ', $result->faultcode, $result->faultstring, $result->faultdetail);
            }
        };
        
        if ($@){
            $logger->error("SOAP-Target konnte nicht erreicht werden :".$@);
        }
        
        $self->{olws}=$soapresult;
    }
    
    return $self;
}

sub is_brief {
    my ($self)=@_;

    return ($self->{_type} eq "brief")?1:0;
}

sub is_full {
    my ($self)=@_;

    return ($self->{_type} eq "full")?1:0;
}

sub get_holding {
    my ($self)=@_;

    return $self->{_holding}
}

sub set_holding {
    my ($self,$holding_ref)=@_;

    $self->{_holding} = $holding_ref;

    return;
}

sub set_fields {
    my ($self,$fields_ref)=@_;

    $self->{_fields} = $fields_ref;

    return;
}

sub get_circulation {
    my ($self)=@_;

    return $self->{_circulation}
}

sub set_circulation {
    my ($self,$circulation_ref)=@_;

    $self->{_circulation} = $circulation_ref;

    return;
}

sub set_same_records {
    my ($self,$recordlist)=@_;

    $self->{_same_records} = $recordlist;

    return $self;
}

sub get_same_records {
    my ($self)=@_;

    return $self->{_same_records}
}

sub get_similar_records {
    my ($self)=@_;

    return $self->{_similar_records}
}

sub set_similar_records {
    my ($self,$recordlist)=@_;

    $self->{_similar_records} = $recordlist;

    return $self;
}

sub get_related_records {
    my ($self)=@_;

    return $self->{_related_records}
}

sub set_related_records {
    my ($self,$recordlist)=@_;

    $self->{_related_records} = $recordlist;
    
    return $self;
}

sub set_fields_from_storable {
    my ($self,$storable_ref)=@_;

    # Log4perl logger erzeugen
    my $logger = get_logger();

    # (Re-)Initialisierung
    delete $self->{_exists}        if (exists $self->{_exists});
    delete $self->{_fields}       if (exists $self->{_fields});
    delete $self->{_holding}        if (exists $self->{_holding});
    delete $self->{_circulation}    if (exists $self->{_circulation});

    $logger->debug("Got :".YAML::Dump($storable_ref));
    $self->{_fields} = $storable_ref;
    $self->{_type} = 'brief';
    
    return $self;
}

sub set_fields_from_json {
    my ($self,$json_string)=@_;

    # Log4perl logger erzeugen
    my $logger = get_logger();

    # (Re-)Initialisierung
    delete $self->{_exists}         if (exists $self->{_exists});
    delete $self->{_fields}       if (exists $self->{_fields});
    delete $self->{_holding}        if (exists $self->{_holding});
    delete $self->{_circulation}    if (exists $self->{_circulation});

    my $json_ref = {};

    eval {
        $json_ref = decode_json $json_string;
    };
    
    if ($@){
        $logger->error("Can't decode JSON string $json_string");
    }
    else {
        $self->{_fields} = $json_ref;
        $self->{_type} = 'brief';
    }

    return $self;
}

sub to_bibkey {
    my ($self) = @_;

    # Log4perl logger erzeugen
    my $logger = get_logger();

    my $bibkey_record_ref = {
        'T0100' => $self->{_fields}->{'T0100'},
        'T0101' => $self->{_fields}->{'T0101'},
        'T0331' => $self->{_fields}->{'T0331'},
        'T0425' => $self->{_fields}->{'T0425'},
    };

    return OpenBib::Common::Util::gen_bibkey({ fields => $bibkey_record_ref});
}

sub to_normalized_isbn13 {
    my ($self) = @_;

    # Log4perl logger erzeugen
    my $logger = get_logger();

    my $thisisbn = $self->{_fields}{"T0540"}[0]{content};

    $logger->debug("ISBN: $thisisbn");

    # Normierung auf ISBN13

    my $isbn     = Business::ISBN->new($thisisbn);
    
    if (defined $isbn && $isbn->is_valid){
        $thisisbn = $isbn->as_isbn13->as_string;
    }
    
    $thisisbn = OpenBib::Common::Util::normalize({
        field => 'T0540',
        content  => $thisisbn,
    });
    
    return $thisisbn;
}

sub to_endnote {
    my ($self) = @_;

    # Log4perl logger erzeugen
    my $logger = get_logger();

    my $endnote_category_map_ref = {
        'T0100' => '%A',    # Author
        'T0101' => '%A',    # Person
        'T0103' => '%A',    # Celebr. Person 
        'T0200' => '%C',    # Corporate Author
        'T0331' => '%T',    # Title of the article or book
        'T0451' => '%S',    # Title of the serie
        'T0590' => '%J',    # Journal containing the article
#        '3'     => '%B',    # Journal Title (refer: Book containing article)
        'T0519' => '%R',    # Report, paper, or thesis type
        'T0455' => '%V',    # Volume 
        'T0089' => '%N',    # Number with volume
#        '7'     => '%E',    # Editor of book containing article
#        '8'     => '%P',    # Page number(s)
        'T0412' => '%I',    # Issuer. This is the publisher
        'T0410' => '%C',    # City where published. This is the publishers address
        'T0425' => '%D',    # Date of publication
        'T0424' => '%D',    # Date of publication
#        '11'    => '%O',    # Other information which is printed after the reference
#        '12'    => '%K',    # Keywords used by refer to help locate the reference
#        '13'    => '%L',    # Label used to number references when the -k flag of refer is used
        'T0540' => '%X',    # Abstract. This is not normally printed in a reference
        'T0543' => '%X',    # Abstract. This is not normally printed in a reference
        'T0750' => '%X',    # Abstract. This is not normally printed in a reference
#        '15'    => '%W',    # Where the item can be found (physical location of item)
        'T0433' => '%Z',    # Pages in the entire document. Tib reserves this for special use
        'T0403' => '%7',    # Edition
#        '17'    => '%Y',    # Series Editor
    };

    my $endnote_ref=[];

    # Titelkategorien
    foreach my $category (keys %{$endnote_category_map_ref}) {
        if (exists $self->{_fields}{$category}) {
            foreach my $content_ref (@{$self->{_fields}{$category}}){                
                my $content = $endnote_category_map_ref->{$category}." ".$content_ref->{content};
                
                if ($category eq "T0331" && exists $self->{_fields}{"T0335"}){
                    $content.=" : ".$self->{_fields}{"T0335"}[0]{content};
                }
                
                push @{$endnote_ref}, $content;
            }
        }
    }

    # Exemplardaten
    my @holdingnormset = @{$self->{_holding}};

    if ($#holdingnormset > 0){
        foreach my $holding_ref (@holdingnormset){
            push @{$endnote_ref}, '%W '.$holding_ref->{"X4000"}{content}{full}." / ".$holding_ref->{"X0016"}{content}." / ".$holding_ref->{"X0014"}{content};
        }
    }
    
    return join("\n",@$endnote_ref);
}


sub to_bibsonomy_post {
    my ($self,$arg_ref) = @_;

    # Set defaults
    my $utf8               = exists $arg_ref->{utf8}
        ? $arg_ref->{utf8}               : 0;

    my $doc = XML::LibXML::Document->new();
    my $root = $doc->createElement('bibsonomy');
    $doc->setDocumentElement($root);
    my $post = $doc->createElement('post');
    $root->appendChild($post);
    my $bibtex = $doc->createElement('bibtex');
    
    # Verfasser und Herausgeber konstruieren
    my $authors_ref=[];
    my $editors_ref=[];
    foreach my $category (qw/T0100 T0101/){
        next if (!exists $self->{_fields}->{$category});
        foreach my $part_ref (@{$self->{_fields}->{$category}}){
            if ($part_ref->{supplement} =~ /Hrsg/){
                push @$editors_ref, utf2bibtex($part_ref->{content},$utf8);
            }
            else {
                push @$authors_ref, utf2bibtex($part_ref->{content},$utf8);
            }
        }
    }
    my $author = join(' and ',@$authors_ref);
    my $editor = join(' and ',@$editors_ref);

    # Schlagworte
    my $keywords_ref=[];
    foreach my $category (qw/T0710 T0902 T0907 T0912 T0917 T0922 T0927 T0932 T0937 T0942 T0947/){
        next if (!exists $self->{_fields}->{$category});
        foreach my $part_ref (@{$self->{_fields}->{$category}}){
            push @$keywords_ref, utf2bibtex($part_ref->{content},$utf8);
        }
    }
    my $keyword = join(' ; ',@$keywords_ref);
    
    # Auflage
    my $edition   = (exists $self->{_fields}->{T0403})?utf2bibtex($self->{_fields}->{T0403}[0]{content},$utf8):'';

    # Verleger
    my $publisher = (exists $self->{_fields}->{T0412})?utf2bibtex($self->{_fields}->{T0412}[0]{content},$utf8):'';

    # Verlagsort
    my $address   = (exists $self->{_fields}->{T0410})?utf2bibtex($self->{_fields}->{T0410}[0]{content},$utf8):'';

    # Titel
    my $title     = (exists $self->{_fields}->{T0331})?utf2bibtex($self->{_fields}->{T0331}[0]{content},$utf8):'';

    # Zusatz zum Titel
    my $titlesup  = (exists $self->{_fields}->{T0335})?utf2bibtex($self->{_fields}->{T0335}[0]{content},$utf8):'';

    #    Folgende Erweiterung um titlesup ist nuetzlich, laeuft aber der
    #    Bibkey-Bildung entgegen

#    if ($title && $titlesup){
#        $title = "$title : $titlesup";
#    }

    # Jahr
    my $year      = (exists $self->{_fields}->{T0425})?utf2bibtex($self->{_fields}->{T0425}[0]{content},$utf8):'';

    # ISBN
    my $isbn      = (exists $self->{_fields}->{T0540})?utf2bibtex($self->{_fields}->{T0540}[0]{content},$utf8):'';

    # ISSN
    my $issn      = (exists $self->{_fields}->{T0543})?utf2bibtex($self->{_fields}->{T0543}[0]{content},$utf8):'';

    # Sprache
    my $language  = (exists $self->{_fields}->{T0516})?utf2bibtex($self->{_fields}->{T0516}[0]{content},$utf8):'';

    # Abstract
    my $abstract  = (exists $self->{_fields}->{T0750})?utf2bibtex($self->{_fields}->{T0750}[0]{content},$utf8):'';

    # URL
    my $url       = (exists $self->{_fields}->{T0662})?utf2bibtex($self->{_fields}->{T0662}[0]{content},$utf8):'';

    # Origin
    my $origin    = (exists $self->{_fields}->{T0590})?utf2bibtex($self->{_fields}->{T0590}[0]{content},$utf8):'';

    if ($author){
        $bibtex->setAttribute("author",$author);
    }
    if ($editor){
        $bibtex->setAttribute("editor",$editor);
    }
    if ($edition){
        $bibtex->setAttribute("edition",$edition);
    }
    if ($publisher){
        $bibtex->setAttribute("publisher",$publisher);
    }
    if ($address){
        $bibtex->setAttribute("address",$address);
    }
    if ($title){
        $bibtex->setAttribute("title",$title);
    }
    if ($year){
        $bibtex->setAttribute("year",$year);
    }
    if ($isbn){
        $bibtex->setAttribute("misc",'ISBN = {'.$isbn.'}');
    }
    if ($issn){
        $bibtex->setAttribute("misc",'ISSN = {'.$issn.'}');
    }
    if ($keyword){
        $bibtex->setAttribute("keywords",$keyword);
    }
    if ($url){
        $bibtex->setAttribute("url",$url);
    }
    if ($language){
        $bibtex->setAttribute("language",$language);
    }
    if ($abstract){
        $bibtex->setAttribute("abstract",$abstract);
    }

    if ($origin){
        # Pages
        if ($origin=~/ ; (S\. *\d+.*)$/){
            $bibtex->setAttribute("pages",$1);
        }
        elsif ($origin=~/, (S\. *\d+.*)$/){
            $bibtex->setAttribute("pages",$1);
        }

        # Journal and/or Volume
        if ($origin=~/^(.+?) ; (.*?) ; S\. *\d+.*$/){
            my $journal = $1;
            my $volume  = $2;

            $journal =~ s/ \/ .*$//;
            $bibtex->setAttribute("journal",$journal);
            $bibtex->setAttribute("volume",$volume);
        }
        elsif ($origin=~/^(.+?)\. (.*?), (\d\d\d\d), S\. *\d+.*$/){
            my $journal = $1;
            my $volume  = $2;
            my $year    = $3;

            $journal =~ s/ \/ .*$//;
            $bibtex->setAttribute("journal",$journal);
            $bibtex->setAttribute("volume",$volume);
        }
        elsif ($origin=~/^(.+?)\. (.*?), S\. *\d+.*$/){
            my $journal = $1;
            my $volume  = $2;

            $journal =~ s/ \/ .*$//;
            $bibtex->setAttribute("journal",$journal);
            $bibtex->setAttribute("volume",$volume);
        }
        elsif ($origin=~/^(.+?) ; (.*?), S\. *\d+.*$/){
            my $journal = $1;
            my $volume  = $2;

            $journal =~ s/ \/ .*$//;
            $bibtex->setAttribute("journal",$journal);
            $bibtex->setAttribute("volume",$volume);
        }
        elsif ($origin=~/^(.*?) ; S\. *\d+.*$/){
            my $journal = $1;

            $journal =~ s/ \/ .*$//;
            $bibtex->setAttribute("journal",$journal);
        }
    }

    my $identifier=substr($author,0,4).substr($title,0,4).$year;
    $identifier=~s/[^A-Za-z0-9]//g;

    $bibtex->setAttribute("bibtexKey",$identifier);

    if ($origin){
        $bibtex->setAttribute("entrytype",'article');
    }
    elsif ($isbn){
        $bibtex->setAttribute("entrytype",'book');
    }
    else {
        $bibtex->setAttribute("entrytype",'book');
    }

    $post->appendChild($bibtex);
    
    return $doc->toString();
}

sub to_bibtex {
    my ($self,$arg_ref) = @_;

    # Set defaults
    my $utf8               = exists $arg_ref->{utf8}
        ? $arg_ref->{utf8}               : 0;

    my $bibtex_ref=[];

    # Verfasser und Herausgeber konstruieren
    my $authors_ref=[];
    my $editors_ref=[];
    foreach my $category (qw/T0100 T0101/){
        next if (!exists $self->{_fields}->{$category});
        foreach my $part_ref (@{$self->{_fields}->{$category}}){
            if ($part_ref->{supplement} =~ /Hrsg/){
                push @$editors_ref, utf2bibtex($part_ref->{content},$utf8);
            }
            else {
                push @$authors_ref, utf2bibtex($part_ref->{content},$utf8);
            }
        }
    }
    my $author = join(' and ',@$authors_ref);
    my $editor = join(' and ',@$editors_ref);

    # Schlagworte
    my $keywords_ref=[];
    foreach my $category (qw/T0710 T0902 T0907 T0912 T0917 T0922 T0927 T0932 T0937 T0942 T0947/){
        next if (!exists $self->{_fields}->{$category});
        foreach my $part_ref (@{$self->{_fields}->{$category}}){
            push @$keywords_ref, utf2bibtex($part_ref->{content},$utf8);
        }
    }
    my $keyword = join(' ; ',@$keywords_ref);
    
    # Auflage
    my $edition   = (exists $self->{_fields}->{T0403})?utf2bibtex($self->{_fields}->{T0403}[0]{content},$utf8):'';

    # Verleger
    my $publisher = (exists $self->{_fields}->{T0412})?utf2bibtex($self->{_fields}->{T0412}[0]{content},$utf8):'';

    # Verlagsort
    my $address   = (exists $self->{_fields}->{T0410})?utf2bibtex($self->{_fields}->{T0410}[0]{content},$utf8):'';

    # Titel
    my $title     = (exists $self->{_fields}->{T0331})?utf2bibtex($self->{_fields}->{T0331}[0]{content},$utf8):'';

    # Zusatz zum Titel
    my $titlesup  = (exists $self->{_fields}->{T0335})?utf2bibtex($self->{_fields}->{T0335}[0]{content},$utf8):'';
#    Folgende Erweiterung um titlesup ist nuetzlich, laeuft aber der
#    Bibkey-Bildung entgegen
#    if ($title && $titlesup){
#        $title = "$title : $titlesup";
#    }

    # Jahr
    my $year      = (exists $self->{_fields}->{T0425})?utf2bibtex($self->{_fields}->{T0425}[0]{content},$utf8):'';

    # ISBN
    my $isbn      = (exists $self->{_fields}->{T0540})?utf2bibtex($self->{_fields}->{T0540}[0]{content},$utf8):'';

    # ISSN
    my $issn      = (exists $self->{_fields}->{T0543})?utf2bibtex($self->{_fields}->{T0543}[0]{content},$utf8):'';

    # Sprache
    my $language  = (exists $self->{_fields}->{T0516})?utf2bibtex($self->{_fields}->{T0516}[0]{content},$utf8):'';

    # URL
    my $url       = (exists $self->{_fields}->{T0662})?utf2bibtex($self->{_fields}->{T0662}[0]{content},$utf8):'';

    # Abstract
    my $abstract  = (exists $self->{_fields}->{T0750})?utf2bibtex($self->{_fields}->{T0750}[0]{content},$utf8):'';

    # Origin
    my $origin    = (exists $self->{_fields}->{T0590})?utf2bibtex($self->{_fields}->{T0590}[0]{content},$utf8):'';

    if ($author){
        push @$bibtex_ref, "author    = \"$author\"";
    }
    if ($editor){
        push @$bibtex_ref, "editor    = \"$editor\"";
    }
    if ($edition){
        push @$bibtex_ref, "edition   = \"$edition\"";
    }
    if ($publisher){
        push @$bibtex_ref, "publisher = \"$publisher\"";
    }
    if ($address){
        push @$bibtex_ref, "address   = \"$address\"";
    }
    if ($title){
        push @$bibtex_ref, "title     = \"$title\"";
    }
    if ($year){
        push @$bibtex_ref, "year      = \"$year\"";
    }
    if ($isbn){
        push @$bibtex_ref, "ISBN      = \"$isbn\"";
    }
    if ($issn){
        push @$bibtex_ref, "ISSN      = \"$issn\"";
    }
    if ($keyword){
        push @$bibtex_ref, "keywords  = \"$keyword\"";
    }
    if ($url){
        push @$bibtex_ref, "url       = \"$url\"";
    }
    if ($language){
        push @$bibtex_ref, "language  = \"$language\"";
    }
    if ($abstract){
        push @$bibtex_ref, "abstract  = \"$abstract\"";
    }

    if ($origin){
        # Pages
        if ($origin=~/ ; (S\. *\d+.*)$/){
            push @$bibtex_ref, "pages     = \"$1\"";
        }
        elsif ($origin=~/, (S\. *\d+.*)$/){
            push @$bibtex_ref, "pages     = \"$1\"";
        }

        # Journal and/or Volume
        if ($origin=~/^(.+?) ; (.*?) ; S\. *\d+.*$/){
            my $journal = $1;
            my $volume  = $2;

            $journal =~ s/ \/ .*$//;
            push @$bibtex_ref, "journal   = \"$journal\"";
            push @$bibtex_ref, "volume    = \"$volume\"";
        }
        elsif ($origin=~/^(.+?)\. (.*?), (\d\d\d\d), S\. *\d+.*$/){
            my $journal = $1;
            my $volume  = $2;
            my $year    = $3;

            $journal =~ s/ \/ .*$//;
            push @$bibtex_ref, "journal   = \"$journal\"";
            push @$bibtex_ref, "volume    = \"$volume\"";
        }
        elsif ($origin=~/^(.+?)\. (.*?), S\. *\d+.*$/){
            my $journal = $1;
            my $volume  = $2;

            $journal =~ s/ \/ .*$//;
            push @$bibtex_ref, "journal   = \"$journal\"";
            push @$bibtex_ref, "volume    = \"$volume\"";
        }
        elsif ($origin=~/^(.+?) ; (.*?), S\. *\d+.*$/){
            my $journal = $1;
            my $volume  = $2;

            $journal =~ s/ \/ .*$//;
            push @$bibtex_ref, "journal   = \"$journal\"";
            push @$bibtex_ref, "volume    = \"$volume\"";
        }
        elsif ($origin=~/^(.*?) ; S\. *\d+.*$/){
            my $journal = $1;

            $journal =~ s/ \/ .*$//;
            push @$bibtex_ref, "journal   = \"$journal\"";
        }
    }

    my $identifier=substr($author,0,4).substr($title,0,4).$year;
    $identifier=~s/[^A-Za-z0-9]//g;

    my $bibtex="";

    if ($origin){
        unshift @$bibtex_ref, "\@article {$identifier";
        $bibtex=join(",\n",@$bibtex_ref);
        $bibtex="$bibtex}";
    }
    elsif ($isbn){
        unshift @$bibtex_ref, "\@book {$identifier";
        $bibtex=join(",\n",@$bibtex_ref);
        $bibtex="$bibtex}";
    }
    else {
        unshift @$bibtex_ref, "\@book {$identifier";
        $bibtex=join(",\n",@$bibtex_ref);
        $bibtex="$bibtex}";
    }

    
    return $bibtex;
}

sub to_tags {
    my ($self) = @_;

    # Schlagworte
    my $keywords_ref=[];
    foreach my $category (qw/T0710 T0902 T0907 T0912 T0917 T0922 T0927 T0932 T0937 T0942 T0947/){
        next if (!exists $self->{_fields}->{$category});
        foreach my $part_ref (@{$self->{_fields}->{$category}}){
            foreach my $content_part (split('\s+',$part_ref->{content})){
                push @$keywords_ref, OpenBib::Common::Util::normalize({
                    tagging => 1,
                    content => $content_part,
                });
            }
        }
    }
    my $keyword = join(' ',@$keywords_ref);

    return $keyword;
}

sub utf2bibtex {
    my ($string,$utf8)=@_;

    return "" if (!defined $string);
    
    # {} werden von BibTeX verwendet und haben in den Originalinhalten
    # nichts zu suchen
    $string=~s/\{//g;
    $string=~s/\}//g;
    # Ausfiltern nicht akzeptierter Zeichen (Positivliste)
    $string=~s/[^-+\p{Alphabetic}0-9\n\/&;#: '()@<>\\,.="^*[]]//g;
    $string=~s/&lt;/</g;
    $string=~s/&gt;/>/g;
    $string=~s/&amp;/&/g;

    # Wenn utf8 ausgegeben werden soll, dann sind wir hier fertig
    return $string if ($utf8);

    # ... ansonsten muessen weitere Sonderzeichen umgesetzt werden.
    $string=~s/&#172;//g;
    $string=~s/&#228;/{\\"a}/g;
    $string=~s/&#252;/{\\"u}/g;
    $string=~s/&#246;/{\\"o}/g;
    $string=~s/&#223;/{\\"s}/g;
    $string=~s/&#214;/{\\"O}/g;
    $string=~s/&#220;/{\\"U}/g;
    $string=~s/&#196;/{\\"A}/g;
    $string=~s/&auml;/{\\"a}/g;
    $string=~s/&ouml;/{\\"o}/g;
    $string=~s/&uuml;/{\\"u}/g;
    $string=~s/&Auml;/{\\"A}/g;
    $string=~s/&Ouml;/{\\"O}/g;
    $string=~s/&Uuml;/{\\"U}/g;
    $string=~s/&szlig;/{\\"s}/g;
    $string=~s/ä/{\\"a}/g;
    $string=~s/ö/{\\"o}/g;
    $string=~s/ü/{\\"u}/g;
    $string=~s/Ä/{\\"A}/g;
    $string=~s/Ö/{\\"O}/g;
    $string=~s/Ü/{\\"U}/g;
    $string=~s/ß/{\\ss}/g;

    return $string;
}

sub to_rawdata {
    my ($self) = @_;

    return ($self->{_fields},$self->{_holding},$self->{_circulation});
}

sub to_hash {
    my ($self) = @_;
    
    my $hash_ref = {
        'id'          => $self->{id},
        'database'    => $self->{database},
        'fields'      => $self->{_fields},
        'items'       => $self->{_holding},
        'circulation' => $self->{_circulation},
    };

    return $hash_ref;
}

sub from_hash {
    my ($self,$hash_ref)=@_;
    
    $self->set_id($hash_ref->{id});
    $self->set_database($hash_ref->{database});
    
    $self->set_fields($hash_ref->{fields});
    $self->set_holding($hash_ref->{items});
    $self->set_circulation($hash_ref->{circulation});

    return $self;
}
    

sub record_exists {
    my ($self) = @_;

    my @categories = grep { /^[TX]/ } keys %{$self->{_fields}};
    
    return (@categories)?1:0;
}

sub set_record_exists {
    my ($self) = @_;

    $self->{_exists} = 1;

    return $self;
}

sub to_drilldown_term {
    my ($self,$term)=@_;

    my $config = OpenBib::Config->instance;

    $term = OpenBib::Common::Util::normalize({
        content   => $term,
        searchreq => 1,
    });

    $term=~s/\W/_/g;

    if (length($term) > $config->{xapian_option}{max_key_length}){
        $term=substr($term,0,$config->{xapian_option}{max_key_length}-2); # 2 wegen Prefix
    }

    return $term;
}

sub to_json ($){
    my ($self)=@_;

    return encode_json $self->to_hash;
}

sub from_json ($){
    my ($self,$json)=@_;

    # Log4perl logger erzeugen
    my $logger = get_logger();

    eval {
        my $json_ref = decode_json $json;

        $self->from_hash($json_ref);
    };

    if ($@){
        $logger->error($@);
    }
        
    return $self;
}

sub set_id {
    my ($self,$id) = @_;

    $self->{id}           = $id;
    $self->{_normset}{id} = $id;

    return $self;
}

sub set_database {
    my ($self,$database) = @_;

    $self->{database}           = $database;
    $self->{_normset}{database} = $database;

    return $self;
}

sub get_id {
    my ($self) = @_;

    return $self->{id};
}

sub get_database {
    my ($self) = @_;

    return $self->{database};
}

sub set_from_apache_request {
    my ($self,$r) = @_;

    # Log4perl logger erzeugen
    my $logger = get_logger();

    my $config = OpenBib::Config->instance;
    
    my $query = Apache2::Request->new($r);

    my $set_categories_ref = [];

    foreach my $category_arg ($query->param){
        next unless ($category_arg=~m/^[TX]\d\d\d\d/); 

        if ($query->param($category_arg)){
            if ($category_arg=~m/^T/){
                $self->set_field({ field => $category_arg, subfield => '', mult => 1, content => $query->param($category_arg) });
            }
            elsif ($category_arg=~m/^X/){
                $self->set_holding_field({ field => $category_arg, subfield => '', mult => 1, content => $query->param($category_arg) });
            }
        } 
    } 

    $logger->debug(YAML::Dump($self->{_fields}));
    return $self;
}

# sub store {
#     my ($self,$arg_ref) = @_;

#     # Set defaults
#     my $dbh               = exists $arg_ref->{dbh}
#         ? $arg_ref->{dbh}               : undef;

#     # Log4perl logger erzeugen
#     my $logger = get_logger();

#     my $config = OpenBib::Config->instance;

#     my $is_new = (exists $self->{id})?1:0;

#     my $local_dbh = 0;
#     if (!defined $dbh){
#         # Kein Spooling von DB-Handles!
#         $dbh = DBI->connect("DBI:$config->{dbimodule}:dbname=$self->{database};host=$config->{dbhost};port=$config->{dbport}", $config->{dbuser}, $config->{dbpasswd})
#             or $logger->error_die($DBI::errstr);
#         $local_dbh = 1;
#     }

#     if ($is_new){

#     # Titelkategorien
#     {
#         # Neue ID bestimmen
#         my $request = $dbh->prepare("select max(id)+1 as nextid from title");
#         $request->execute();
#         my $result=$request->fetchrow_hashref;

#         $self->set_id($result->{nextid});

#         # Kategorien eintragen
#         my ($atime,$btime,$timeall)=(0,0,0);
        
#         if ($config->{benchmark}) {
#             $atime=new Benchmark;
#         }
        
#         my $reqstring="insert into title (id,category,indicator,content) values(?,?,?,?)";
#         $request=$dbh->prepare($reqstring) or $logger->error($DBI::errstr);

#         foreach my $category (keys %{$self->{_fields}}){
#             $category=~s/^T//;

#             # Hierarchieverknuepfung
#             if ($category eq "0004"){
#                 my $reqstring2 = "insert into conn (category,sourceid,sourcetype,targetid,targettype) values ('0004',?,1,?,1);where targetid=? and sourcetype=1 and targettype=1";
#                 my $request2 = $dbh->prepare($reqstring2);
#                 foreach my $item (@{$self->{_fields}->{$category}}){
#                     $request2->execute($item->{content},$self->{id});
#                 }
#                 $request2->finish;
#             }
#             # oder 'normale' Kategorie
#             else {
#                 foreach my $item (@{$self->{_fields}->{$category}}){
#                     $request->execute($self->{id},$category,$item->{indicator},$item->{content});
#                 }
#             }
#         }
        
#         $request->finish();

#         if ($config->{benchmark}) {
#             $btime=new Benchmark;
#             $timeall=timediff($btime,$atime);
#             $logger->info("Zeit fuer : $reqstring : ist ".timestr($timeall));
#         }
#     }
    
# #     # Verknuepfte Normdaten
# #     {
# #         my ($atime,$btime,$timeall)=(0,0,0);
        
# #         if ($config->{benchmark}) {
# #             $atime=new Benchmark;
# #         }
        
# #         my $reqstring="select category,targetid,targettype,supplement from conn where sourceid=? and sourcetype=1 and targettype IN (2,3,4,5)";
# #         my $request=$dbh->prepare($reqstring) or $logger->error($DBI::errstr);
# #         $request->execute($id) or $logger->error("Request: $reqstring - ".$DBI::errstr);
        
# #         while (my $res=$request->fetchrow_hashref) {
# #             my $category   = "T".sprintf "%04d",$res->{category };
# #             my $targetid   =        decode_utf8($res->{targetid  });
# #             my $targettype =                    $res->{targettype};
# #             my $supplement =        decode_utf8($res->{supplement});
            
# # 	    # Korrektes UTF-8 Encoding Flag wird in get_*_ans_*
# # 	    # vorgenommen
            
# #             my $recordclass    =
# #                 ($targettype == 2 )?"OpenBib::Record::Person":
# #                     ($targettype == 3 )?"OpenBib::Record::CorporateBody":
# #                         ($targettype == 4 )?"OpenBib::Record::Subject":
# #                             ($targettype == 5 )?"OpenBib::Record::Classification":undef;
            
# #             my $content = "";
# #             if (defined $recordclass){
# #                 my $record=$recordclass->new({database=>$self->{database}});
# #                 $record->load_name({dbh => $dbh, id=>$targetid});
# #                 $content=$record->name_as_string;
# #             }
            
# #             push @{$fields_ref->{$category}}, {
# #                 id         => $targetid,
# #                 content    => $content,
# #                 supplement => $supplement,
# #             };
# #         }
# #         $request->finish();
        
# #         if ($config->{benchmark}) {
# #             $btime=new Benchmark;
# #             $timeall=timediff($btime,$atime);
# #             $logger->info("Zeit fuer : $reqstring : ist ".timestr($timeall));
# #         }
#     }
#     else {
#         $self->_delete_from_rdbms;
#         $self->_delete_from_searchengine;
#     }
    
#     return $self;
# }

# sub _delete_from_rdbms {
#     my ($self,$arg_ref) = @_;
    
#     # Set defaults
#     my $dbh               = exists $arg_ref->{dbh}
#         ? $arg_ref->{dbh}               : undef;

#     # Log4perl logger erzeugen
#     my $logger = get_logger();

#     my $config = OpenBib::Config->instance;

#     my $local_dbh = 0;
#     if (!defined $dbh){
#         # Kein Spooling von DB-Handles!
#         $dbh = DBI->connect("DBI:$config->{dbimodule}:dbname=$self->{database};host=$config->{dbhost};port=$config->{dbport}", $config->{dbuser}, $config->{dbpasswd})
#             or $logger->error_die($DBI::errstr);
#         $local_dbh = 1;
#     }

#     my $request = $dbh->prepare("delete from title where id=?");
#     $request->execute($self->get_id);
    
#     $request = $dbh->prepare("delete from conn where sourcetype=1 and sourceid=?");
#     $request->execute($self->get_id);
#     $request = $dbh->prepare("delete from titlelistitem where id=?");
#     $request->execute($self->get_id);
    
#     return $self;
# }

# sub _store_into_rdbms {
#     my ($self,$arg_ref) = @_;
    
#     # Set defaults
#     my $dbh               = exists $arg_ref->{dbh}
#         ? $arg_ref->{dbh}               : undef;

#     # Log4perl logger erzeugen
#     my $logger = get_logger();

#     my $config = OpenBib::Config->instance;

#     my $local_dbh = 0;
#     if (!defined $dbh){
#         # Kein Spooling von DB-Handles!
#         $dbh = DBI->connect("DBI:$config->{dbimodule}:dbname=$self->{database};host=$config->{dbhost};port=$config->{dbport}", $config->{dbuser}, $config->{dbpasswd})
#             or $logger->error_die($DBI::errstr);
#         $local_dbh = 1;
#     }

#     my $request = $dbh->prepare("delete from title where id=?");
#     $request->execute($self->get_id);
    
#     $request = $dbh->prepare("delete from conn where sourcetype=1 and sourceid=?");
#     $request->execute($self->get_id);
#     $request = $dbh->prepare("delete from titlelistitem where id=?");
#     $request->execute($self->get_id);
    
#     return $self;
# }

# sub _delete_from_searchengine {
#     my $self = shift;

    
#     return $self;
# }

sub enrich_cdm {
    my ($self,$id,$url)=@_;

    # Log4perl logger erzeugen
    my $logger = get_logger();

    my $config = OpenBib::Config->instance;
    
    # Wenn kein URI, dann Default-URI
    $url = $config->{cdm_base}.$config->{cdm_path} unless ($url);

    $url.=$id;

    $logger->debug("CDM-URL: $url ");
    
    my $ua = new LWP::UserAgent;
    $ua->agent("OpenBib/1.0");
    $ua->timeout(1);
    my $request = new HTTP::Request('GET', $url);
    my $response = $ua->request($request);

    my $content = $response->content;

    my $enrich_data_ref = {};
    
    if ($content){
        $content=~s/<!--.+?-->//g;
        $logger->debug("CDM: Result for ID $id: ".$content);
        $enrich_data_ref = decode_json($content);
    }

    return $enrich_data_ref;
}

sub to_indexable_document {
    my $self = shift;
    my $database = shift;

    my $config      = OpenBib::Config->instance;
    my $conv_config = new OpenBib::Conv::Config({dbname => $database});

    my $doc = new OpenBib::Index::Document({ database => $self->{_database}, id => $self->{_id} });
    
    my $titlecache_ref   = {}; # Inhalte fuer den Titel-Cache
    my $searchengine_ref = {}; # Inhalte fuer die Suchmaschinen

}

1;
