#####################################################################
#
#  OpenBib::Search::Backend::DBIS.pm
#
#  Objektorientiertes Interface zum DBIS XML-API
#
#  Dieses File ist (C) 2008-2012 Oliver Flimm <flimm@openbib.org>
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

package OpenBib::Search::Backend::DBIS;

use strict;
use warnings;
no warnings 'redefine';
use utf8;

use Apache2::Reload;
use Benchmark ':hireswallclock';
use DBI;
use LWP;
use Encode qw(decode decode_utf8);
use Log::Log4perl qw(get_logger :levels);
use Storable;
use XML::LibXML;
use YAML ();

use OpenBib::Common::Util;
use OpenBib::Config;
use OpenBib::Record::Title;

sub new {
    my ($class,$arg_ref) = @_;

    # Set defaults
    my $bibid     = exists $arg_ref->{bibid}
        ? $arg_ref->{bibid}       : undef;

    my $client_ip = exists $arg_ref->{client_ip}
        ? $arg_ref->{client_ip}   : undef;

    my $colors    = exists $arg_ref->{colors}
        ? $arg_ref->{colors}      : undef;

    my $ocolors   = exists $arg_ref->{ocolors}
        ? $arg_ref->{ocolors}     : undef;

    my $lang      = exists $arg_ref->{lang}
        ? $arg_ref->{lang}        : undef;

    my $database        = exists $arg_ref->{database}
        ? $arg_ref->{database}                : undef;

    # Log4perl logger erzeugen
    my $logger = get_logger();

    my $config = OpenBib::Config->instance;
    
    my $self = { };

    bless ($self, $class);

    $logger->debug("Initializing with colors = ".(defined $colors || '')." and lang = ".(defined $lang || ''));

    $self->{bibid}      = (defined $bibid)?$bibid:(defined $config->{ezb_bibid})?$config->{ezb_bibid}:undef;
    $self->{colors}     = (defined $colors)?$colors:(defined $config->{ezb_colors})?$config->{ezb_colors}:undef;
    $self->{ocolors}    = (defined $ocolors)?$ocolors:(defined $config->{dbis_ocolors})?$config->{dbis_ocolors}:undef;
    $self->{client_ip}  = (defined $client_ip )?$client_ip:undef;
    $self->{lang}       = (defined $lang )?$lang:undef;

    $self->{client}     = LWP::UserAgent->new;            # HTTP client
    $self->{_database}  = $database if ($database);

    return $self;
}

sub get_subjects {
    my ($self) = @_;

    # Log4perl logger erzeugen
    my $logger = get_logger();

    my $url="http://rzblx10.uni-regensburg.de/dbinfo/fachliste.php?colors=".((defined $self->{colors})?$self->{colors}:"")."&ocolors=".((defined $self->{ocolors})?$self->{ocolors}:"")."&bib_id=".((defined $self->{bibid})?$self->{bibid}:"")."&lett=l&lang=".((defined $self->{lang})?$self->{lang}:"")."&xmloutput=1";

    my $subjects_ref = [];
    
    $logger->debug("Request: $url");

    my $response = $self->{client}->get($url)->decoded_content(charset => 'utf8');

    $logger->debug("Response: $response");
    
    my $parser = XML::LibXML->new();
    my $tree   = $parser->parse_string($response);
    my $root   = $tree->getDocumentElement;

    my $maxcount=0;
    my $mincount=999999999;

    foreach my $subject_node ($root->findnodes('/dbis_page/list_subjects_collections/list_subjects_collections_item')) {
        my $singlesubject_ref = {} ;

        $singlesubject_ref->{notation}   = $subject_node->findvalue('@notation');
        $singlesubject_ref->{count}      = $subject_node->findvalue('@number');
        $singlesubject_ref->{lett}      = $subject_node->findvalue('@lett');
        $singlesubject_ref->{desc}       = decode_utf8($subject_node->textContent());

        if ($maxcount < $singlesubject_ref->{count}){
            $maxcount = $singlesubject_ref->{count};
        }
        
        if ($mincount > $singlesubject_ref->{count}){
            $mincount = $singlesubject_ref->{count};
        }

        push @{$subjects_ref}, $singlesubject_ref;
    }

    $subjects_ref = OpenBib::Common::Util::gen_cloud_class({
        items => $subjects_ref, 
        min   => $mincount, 
        max   => $maxcount, 
        type  => 'log'});

    $logger->debug(YAML::Dump($subjects_ref));

    return $subjects_ref;
}

sub get_journals {
    my ($self,$arg_ref) = @_;

    # Set defaults
    my $notation = exists $arg_ref->{notation}
        ? $arg_ref->{notation}     : '';

    my $sc       = exists $arg_ref->{sc}
        ? $arg_ref->{sc}           : '';
    
    my $lc       = exists $arg_ref->{lc}
        ? $arg_ref->{lc}           : '';

    my $sindex   = exists $arg_ref->{sindex}
        ? $arg_ref->{sindex}       : 0;

    # Log4perl logger erzeugen
    my $logger = get_logger();

    my $url="http://rzblx1.uni-regensburg.de/ezeit/fl.phtml?notation=$notation&colors=".((defined $self->{colors})?$self->{colors}:"")."&bibid=".((defined $self->{bibid})?$self->{bibid}:"")."&sc=$sc&lc=$lc&sindex=$sindex&lang=".((defined $self->{lang})?$self->{lang}:"")."&xmloutput=1";
    
    my $titles_ref = [];
    
    $logger->debug("Request: $url");

    my $response = $self->{client}->get($url)->content; # decoded_content(charset => 'latin1');

    $logger->debug("Response: $response");
    
    my $parser = XML::LibXML->new();
    my $tree   = $parser->parse_string($response);
    my $root   = $tree->getDocumentElement;

    my $current_page_ref = {};
    
    foreach my $nav_node ($root->findnodes('/ezb_page/page_vars')) {        
        $current_page_ref->{sc}   = $nav_node->findvalue('sc/@value');
        $current_page_ref->{lc}   = $nav_node->findvalue('lc/@value');
        $current_page_ref->{sindex}   = $nav_node->findvalue('sindex/@value');
        $current_page_ref->{sindex}   = $nav_node->findvalue('sindex/@value');
    }
    
    my $subjectinfo_ref = {};

    $subjectinfo_ref->{notation} = decode_utf8($root->findvalue('/ezb_page/ezb_alphabetical_list/subject/@notation'));
    $subjectinfo_ref->{desc}     = decode_utf8($root->findvalue('/ezb_page/ezb_alphabetical_list/subject'));

    my $nav_ref = [];

    my @first_nodes = $root->findnodes('/ezb_page/ezb_alphabetical_list/first_fifty');
    if (@first_nodes){
        foreach my $nav_node (@first_nodes){
            my $current_nav_ref = {};
            $current_nav_ref->{sc}     = $nav_node->findvalue('@sc');
            $current_nav_ref->{lc}     = $nav_node->findvalue('@lc');
            $current_nav_ref->{sindex} = $nav_node->findvalue('@sindex');
            push @{$nav_ref}, $current_nav_ref;
        }
        push @{$nav_ref}, {
            sc     => $current_page_ref->{sc},
            lc     => $current_page_ref->{lc},
            sindex => $current_page_ref->{sindex},
        };

    }
    else {
        push @{$nav_ref}, {
            sc     => $current_page_ref->{sc},
            lc     => $current_page_ref->{lc},
            sindex => $current_page_ref->{sindex},
        };
    }

    my @next_nodes = $root->findnodes('/ezb_page/ezb_alphabetical_list/next_fifty');
    if (@next_nodes){
        foreach my $nav_node (@next_nodes){
            my $current_nav_ref = {};
            $current_nav_ref->{sc}     = $nav_node->findvalue('@sc');
            $current_nav_ref->{lc}     = $nav_node->findvalue('@lc');
            $current_nav_ref->{sindex} = $nav_node->findvalue('@sindex');
            push @{$nav_ref}, $current_nav_ref;
        }
    }

    my $alphabetical_nav_ref = [];

    foreach my $nav_node ($root->findnodes('/ezb_page/ezb_alphabetical_list/navlist/current_page')) {        
        $current_page_ref->{desc}   = decode_utf8($nav_node->textContent);
    }

    my @nav_nodes = $root->findnodes('/ezb_page/ezb_alphabetical_list/navlist');
    if (@nav_nodes){
        foreach my $this_node ($nav_nodes[0]->childNodes){
            my $singlenav_ref = {} ;
            
            $logger->debug($this_node->toString);
            $singlenav_ref->{sc}   = $this_node->findvalue('@sc');
            $singlenav_ref->{lc}   = $this_node->findvalue('@lc');
            $singlenav_ref->{desc} = $this_node->textContent;
            
            push @{$alphabetical_nav_ref}, $singlenav_ref if ($singlenav_ref->{desc} && $singlenav_ref->{desc} ne "\n");
        }
    }
    my $journals_ref = [];

    foreach my $journal_node ($root->findnodes('/ezb_page/ezb_alphabetical_list/alphabetical_order/journals/journal')) {
        
        my $singlejournal_ref = {} ;
        
        $singlejournal_ref->{id}          = $journal_node->findvalue('@jourid');
        $singlejournal_ref->{title}       = decode_utf8($journal_node->findvalue('title'));
        $singlejournal_ref->{color}{code} = $journal_node->findvalue('journal_color/@color_code');
        $singlejournal_ref->{color}{desc} = $journal_node->findvalue('journal_color/@color');

        push @{$journals_ref}, $singlejournal_ref;
    }

    return {
        nav            => $nav_ref,
        subject        => $subjectinfo_ref,
        journals       => $journals_ref,
        current_page   => $current_page_ref,
        other_pages    => $alphabetical_nav_ref,
    };
}

sub search {
    my ($self,$arg_ref) = @_;

    # Set defaults
    my $colors   = exists $arg_ref->{colors}
        ? $arg_ref->{colors}       : '';

    my $ocolors  = exists $arg_ref->{ocolors}
        ? $arg_ref->{ocolors}      : '';

    my $bibid    = exists $arg_ref->{bibid}
        ? $arg_ref->{bibid}        : 'usb_k';

    my $sc       = exists $arg_ref->{sc}
        ? $arg_ref->{sc}           : '';
    
    my $lc       = exists $arg_ref->{lc}
        ? $arg_ref->{lc}           : '';

    my $sindex   = exists $arg_ref->{sindex}
        ? $arg_ref->{sindex}       : 0;

    # Log4perl logger erzeugen
    my $logger = get_logger();

    my $config       = OpenBib::Config->instance;
    my $searchquery  = OpenBib::SearchQuery->instance;
    my $queryoptions = OpenBib::QueryOptions->instance;

    # Pagination parameters
    my $page              = $queryoptions->get_option('page');
    my $num               = $queryoptions->get_option('num');

    my $offset            = $page*$num-$num;

#     my ($atime,$btime,$timeall);
  
#     if ($config->{benchmark}) {
#         $atime=new Benchmark;
#     }

    $self->parse_query($searchquery);

    my $url="http://rzblx10.uni-regensburg.de/dbinfo/dbliste.php?bib_id=$bibid&colors=$colors&ocolors=$ocolors&lett=k&".$self->querystring."&hits_per_page=$num&offset=$offset&lang=".((defined $self->{lang})?$self->{lang}:"de")."&xmloutput=1";
    
    my $titles_ref = [];
    
    $logger->debug("Request: $url");

    my $response = $self->{client}->get($url)->decoded_content(charset => 'latin1');

    $logger->debug("Response: $response");
    
    my $parser = XML::LibXML->new();
    my $tree   = $parser->parse_string($response);
    my $root   = $tree->getDocumentElement;

    my $access_info_ref = {};

    my @access_info_nodes = $root->findnodes('/dbis_page/list_dbs/db_access_infos/db_access_info');

    foreach my $access_info_node (@access_info_nodes){
        my $id                              = $access_info_node->findvalue('@access_id');
        $access_info_ref->{$id}{icon_url}   = $access_info_node->findvalue('@access_icon');
        $access_info_ref->{$id}{desc_short} = $access_info_node->findvalue('db_access');
        $access_info_ref->{$id}{desc}       = $access_info_node->findvalue('db_access_short_text');
    }

    my $db_type_ref = {};
    my @db_type_nodes = $root->findnodes('/dbis_page/list_dbs/db_type_infos/db_type_info');
    foreach my $db_type_node (@db_type_nodes){
        my $id                          = $db_type_node->findvalue('@db_type_id');
        $db_type_ref->{$id}{desc}       = $db_type_node->findvalue('db_type_long_text');
        $db_type_ref->{$id}{desc_short} = $db_type_node->findvalue('db_type');
        $db_type_ref->{$id}{desc}=~s/\|/<br\/>/g;
    }

    my $db_group_ref             = {};
    my $dbs_ref                  = [];
    my $have_group_ref           = {};
    $db_group_ref->{group_order} = [];

    my $search_count = 0;
    foreach my $dbs_node ($root->findnodes('/dbis_page/list_dbs/dbs')) {
        $search_count = $dbs_node->findvalue('@db_count');
        my $i=0;
        foreach my $db_node ($dbs_node->findnodes('db')) {
            $i++;
            # DBIS-Suche verfuegt ueber kein Paging
            next if ($i <= $offset || $i > $offset+$page*$num);
            
            my $single_db_ref = {};

            $single_db_ref->{id}       = $db_node->findvalue('@title_id');
            $single_db_ref->{access}   = $db_node->findvalue('@access_ref');
            my @types = split(" ",$db_node->findvalue('@db_type_refs'));

            $single_db_ref->{db_types} = \@types;
            $single_db_ref->{title}     = decode_utf8($db_node->textContent);

            push @{$dbs_ref}, $single_db_ref;
        }
    }

#     foreach my $db_group_node ($root->findnodes('/dbis_page/list_dbs/dbs')) {
#         my $db_type                 = $db_group_node->findvalue('@db_type_ref');
#         my $topdb                   = $db_group_node->findvalue('@top_db') || 0;

#         $db_type = "topdb" if (!$db_type && $topdb);
#         $db_type = "all" if (!$db_type && !$topdb);

#         push @{$db_group_ref->{group_order}}, $db_type unless $have_group_ref->{$db_type};
#         $have_group_ref->{$db_type} = 1;

#         $db_group_ref->{$db_type}{count} = decode_utf8($db_group_node->findvalue('@db_count'));
#         $db_group_ref->{$db_type}{dbs} = [];
        
#         foreach my $db_node ($db_group_node->findnodes('db')) {
#             my $single_db_ref = {};

#             $single_db_ref->{id}       = $db_node->findvalue('@title_id');
#             $single_db_ref->{access}   = $db_node->findvalue('@access_ref');
#             my @types = split(" ",$db_node->findvalue('@db_type_refs'));

#             $single_db_ref->{db_types} = \@types;
#             $single_db_ref->{title}     = decode_utf8($db_node->textContent);

#             push @{$db_group_ref->{$db_type}{dbs}}, $single_db_ref;
#         }
#     }
    
#     $btime       = new Benchmark;
#     $timeall     = timediff($btime,$atime);
#     $logger->debug("Time: ".timestr($timeall,"nop"));

    $self->{resultcount}   = $search_count;
    $self->{_access_info}  = $access_info_ref;
    $self->{_db_type}      = $db_type_ref;
    $self->{_matches}      = $dbs_ref;
    
    return $self;
}

sub get_records {
    my $self=shift;

    # Log4perl logger erzeugen
    my $logger = get_logger();

    my $config     = OpenBib::Config->instance;

    my $recordlist = new OpenBib::RecordList::Title();

    my @matches = $self->matches;

    foreach my $match_ref (@matches) {        
        $logger->debug("Record: ".$match_ref );

        my $access_info = $self->{_access_info}{$match_ref->{access}};
        
        my $record = new OpenBib::Record::Title({id => $match_ref->{id}, database => 'dbis', generic_attributes => { access => $access_info }});

        $logger->debug("Title is ".$match_ref->{title});
        
        $record->set_field({field => 'T0331', subfield => '', mult => 1, content => $match_ref->{title}});

        my $mult = 1;
        if (defined $match_ref->{db_types}){
            foreach my $type (@{$match_ref->{db_types}}){
                my $dbtype       =  $self->{_db_type}{$type}{desc};
                my $dbtype_short =  $self->{_db_type}{$type}{desc_short}; 
                $record->set_field({field => 'T0517', subfield => '', mult => $mult, content => $dbtype});
                $record->set_field({field => 'T0800', subfield => '', mult => $mult, content => $dbtype_short});
                $mult++;
            }
        }
        
        $logger->debug("Adding Record with ".YAML::Dump($record->get_normdata));
        $recordlist->add($record);
    }

    return $recordlist;
}

sub get_nav {
    my $self = shift;

    return $self->{_nav};
}

sub get_current_page {
    my $self = shift;

    return $self->{_current_page};
}
sub get_other_pages {
    my $self = shift;

    return $self->{_other_pages};
}

sub matches {
    my $self=shift;

    # Log4perl logger erzeugen
    my $logger = get_logger();

    $logger->debug(YAML::Dump($self->{_matches}));
    return @{$self->{_matches}};
}

sub querystring {
    my $self=shift;
    return $self->{_querystring};
}

sub have_results {
    my $self = shift;
    return ($self->{resultcount})?$self->{resultcount}:0;
}

sub get_resultcount {
    my $self = shift;
    return $self->{resultcount};
}

sub parse_query {
    my ($self,$searchquery)=@_;

    # Log4perl logger erzeugen
    my $logger = get_logger();

    my $config = OpenBib::Config->instance;

    my @searchterms = ();
    foreach my $field (keys %{$config->{searchfield}}){
        my $searchtermstring = (defined $searchquery->get_searchfield($field)->{norm})?$searchquery->get_searchfield($field)->{norm}:'';
#        my $searchtermop     = (defined $searchquery->get_searchfield($field)->{bool} && defined $ops_ref->{$searchquery->get_searchfield($field)->{bool}})?$ops_ref->{$searchquery->get_searchfield($field)->{bool}}:'';
        if ($searchtermstring) {
            # Freie Suche einfach uebernehmen
            if    ($field eq "freesearch" && $searchtermstring) {
                push @searchterms, {
                    field   => 'AL',
                    content => $searchtermstring
                };
            }
            elsif    ($field eq "title" && $searchtermstring) {
                push @searchterms, {
                    field   => 'KT',
                    content => $searchtermstring
                };
            }
            elsif ($field eq "titlestring" && $searchtermstring) {
                push @searchterms, {
                    field   => 'KS',
                    content => $searchtermstring
                };
            }
            elsif ($field eq "subject" && $searchtermstring) {
                push @searchterms, {
                    field   => 'KW',
                    content => $searchtermstring
                };
            }
            elsif ($field eq "content" && $searchtermstring) {
                push @searchterms, {
                    field   => 'CO',
                    content => $searchtermstring
                };
            }
            elsif ($field eq "publisher" && $searchtermstring) {
                push @searchterms, {
                    field   => 'PU',
                    content => $searchtermstring
                };
            }
        }
    }

    my @searchstrings = ();
    my $i = 1;
    foreach my $search_ref (@searchterms){
        last if ($i > 4);

        if ($search_ref->{field} && $search_ref->{content}){
            push @searchstrings, "jq_type${i}=$search_ref->{field}&jq_term${i}=$search_ref->{content}&jq_bool${i}=AND";
            $i++;
        }
    }
    
    if (defined $searchquery->get_searchfield('classification')->{val} && $searchquery->get_searchfield('classification')->{val}){
        push @searchstrings, "gebiete[]=".$searchquery->get_searchfield('classification')->{val};
    }
    else {
        push @searchstrings, "gebiete[]=all";
    }

    my $dbisquerystring = join("&",@searchstrings);
    $logger->debug("DBIS-Querystring: $dbisquerystring");
    $self->{_querystring} = $dbisquerystring;

    return $self;
}


sub DESTROY {
    my $self = shift;

    return;
}


sub get_journalinfo {
    my ($self,$arg_ref) = @_;

    # Set defaults
    my $id = exists $arg_ref->{id}
        ? $arg_ref->{id}     : '';

    # Log4perl logger erzeugen
    my $logger = get_logger();

    my $url="http://rzblx1.uni-regensburg.de/ezeit/detail.phtml?colors=".((defined $self->{colors})?$self->{colors}:"")."&bibid=".((defined $self->{bibid})?$self->{bibid}:"")."&lang=".((defined $self->{lang})?$self->{lang}:"")."&jour_id=$id&xmloutput=1";

    my $titles_ref = [];
    
    $logger->debug("Request: $url");

    my $response = $self->{client}->get($url)->content; # decoded_content(charset => 'latin1');

    $logger->debug("Response: $response");
    
    my $parser = XML::LibXML->new();
    my $tree   = $parser->parse_string($response);
    my $root   = $tree->getDocumentElement;

    my $title     =  decode_utf8($root->findvalue('/ezb_page/ezb_detail_about_journal/journal/title'));
    my $publisher =  decode_utf8($root->findvalue('/ezb_page/ezb_detail_about_journal/journal/detail/publisher'));
    my @zdb_nodes =  $root->findnodes('/ezb_page/ezb_detail_about_journal/journal/detail/ZDB_number');

    my $zdb_node_ref = {};
    
    foreach my $zdb_node (@zdb_nodes){
        $zdb_node_ref->{ZDB_number}{url} = $zdb_node->findvalue('@url');
        $zdb_node_ref->{ZDB_number}{content} = decode_utf8($zdb_node->textContent);
    }

    my @subjects_nodes =  $root->findnodes('/ezb_page/ezb_detail_about_journal/journal/detail/subjects/subject');

    my $subjects_ref = [];

    foreach my $subject_node (@subjects_nodes){
        push @{$subjects_ref}, decode_utf8($subject_node->textContent);
    }

    my @keywords_nodes =  $root->findnodes('/ezb_page/ezb_detail_about_journal/journal/detail/keywords/keyword');

    my $keywords_ref = [];

    foreach my $keyword_node (@keywords_nodes){
        push @{$keywords_ref}, decode_utf8($keyword_node->textContent);
    }

    my @homepages_nodes =  $root->findnodes('/ezb_page/ezb_detail_about_journal/journal/detail/hompages/homepage');

    my $homepages_ref = [];

    foreach my $homepage_node (@homepages_nodes){
        push @{$homepages_ref}, decode_utf8($homepage_node->textContent);
    }
    
    my $firstvolume =  decode_utf8($root->findvalue('/ezb_page/ezb_detail_about_journal/journal/detail/first_fulltext_issue/first_volume'));
    my $firstdate   =  decode_utf8($root->findvalue('/ezb_page/ezb_detail_about_journal/journal/detail/first_fulltext_issue/first_date'));
    my $appearence  =  decode_utf8($root->findvalue('/ezb_page/ezb_detail_about_journal/journal/detail/appearence'));
    my $costs       =  decode_utf8($root->findvalue('/ezb_page/ezb_detail_about_journal/journal/detail/costs'));
    my $remarks     =  decode_utf8($root->findvalue('/ezb_page/ezb_detail_about_journal/journal/detail/remarks'));

    return {
        id             => $id,
        title          => $title,
        publisher      => $publisher,
        ZDB_number     => $zdb_node_ref,
        subjects       => $subjects_ref,
        keywords       => $keywords_ref,
        firstvolume    => $firstvolume,
        firstdate      => $firstdate,
        appearence     => $appearence,
        costs          => $costs,
        homepages      => $homepages_ref,
        remarks        => $remarks,
    };
}

sub get_journalreadme {
    my ($self,$arg_ref) = @_;

    # Set defaults
    my $id = exists $arg_ref->{id}
        ? $arg_ref->{id}     : '';

    # Log4perl logger erzeugen
    my $logger = get_logger();

    my $url="http://rzblx1.uni-regensburg.de/ezeit/show_readme.phtml?colors=".((defined $self->{colors})?$self->{colors}:"")."&bibid=".((defined $self->{bibid})?$self->{bibid}:"")."&lang=".((defined $self->{lang})?$self->{lang}:"")."&jour_id=$id&xmloutput=1";

    $logger->debug("Request: $url");

    my $response = $self->{client}->get($url)->content; # decoded_content(charset => 'latin1');

    $logger->debug("Response: $response");

    # Fehlermeldungen im XML entfernen

    $response=~s/^.*?<\?xml/<?xml/smx;

    $logger->debug("gereinigte Response: $response");
    
    my $parser = XML::LibXML->new();
    $parser->recover(1);
    my $tree   = $parser->parse_string($response);
    my $root   = $tree->getDocumentElement;

    my $location =  $root->findvalue('/ezb_page/ezb_readme_page/location');

    if ($location){
        # Lokaler Link in der EZB
        unless ($location=~m/^http/){
            $location="http://rzblx1.uni-regensburg.de/ezeit/$location";
        }
        
        return {
            location => $location
        };
    }

    my $title    =  decode_utf8($root->findvalue('/ezb_page/ezb_readme_page/journal/title'));

    my @periods_nodes =  $root->findnodes('/ezb_page/ezb_readme_page/journal/periods/period');

    my $periods_ref = [];

    foreach my $period_node (@periods_nodes){
        my $this_period_ref = {};

        $this_period_ref->{color}       = decode_utf8($period_node->findvalue('journal_color/@color'));
        $this_period_ref->{label}       = decode_utf8($period_node->findvalue('label'));
        $this_period_ref->{readme_link} = decode_utf8($period_node->findvalue('readme_link/@url'));
        $this_period_ref->{warpto_link} = decode_utf8($period_node->findvalue('warpto_link/@url'));

        $logger->debug(YAML::Dump($this_period_ref));
        push @{$periods_ref}, $this_period_ref;
    }

    return {
        periods  => $periods_ref,
        title    => $title,
    };
}


1;
__END__

=head1 NAME

OpenBib::DBIS - Objektorientiertes Interface zum DBIS XML-API

=head1 DESCRIPTION

Mit diesem Objekt kann auf das XML-API des
Datenbankinformationssystems (DBIS) in Regensburg zugegriffen werden.

=head1 SYNOPSIS

 use OpenBib::DBIS;

 my $dbis = OpenBib::DBIS->new({});

=head1 METHODS

=over 4

=item new({ bibid => $bibid, client_ip => $client_ip, colors => $colors, ocolors => $ocolors, lang => $lang })

Erzeugung des DBIS Objektes. Dabei wird die DBIS-Kennung $bibid der
Bibliothek, die IP des aufrufenden Clients (zur Statistik), die
Sprachversion lang, sowie die Spezifikation der gewünschten
Zugriffsbedingungen color und ocolor benötigt.

=item get_subjects

Liefert eine Listenreferenz der vorhandenen Fachgruppen zurück mit
einer Hashreferenz auf die jeweilige Notation notation, der
Datenbankanzahl count, des Anfangbuchstabens lett sowie der
Beschreibung der Fachgruppe desc. Zusätzlich werden für eine
Wolkenanzeige die entsprechenden Klasseninformationen hinzugefügt.

=item search_dbs({ fs => $fs, notation => $notation })

Stellt die Suchanfrage $fs - optional eingeschränkt auf die Fachgruppe
$notation - an DBIS und liefert als Ergebnis verschiedene Informatinen
als Hashreferenz zurück.

Es sind dies die Informationen über die aktuelle Ergebnisseite
current_page (mit lett, colors, ocolors), die Fachgruppe subject, die
Kategorisierung von Datenbanken db_groups, die Zugriffsbedingungen
access_info sowie die jeweiligen Datenbanktypen db_type.

=item get_dbs({ notation => $notation, fs => $fs, lett => $lett, sc => $sc, lc => $lc, sindex => $sindex })

Liefert eine Liste mit Informationen über alle Datenbanken der
Fachgruppe $notation aus DBIS als Hashreferenz zurück.

Es sind dies die Informationen über die Fachgruppe subject, die
Kategorisierung von Datenbanken db_groups, die Zugriffsbedingungen
access_info sowie die jeweiligen Datenbanktypen db_type.

=item get_dbinfo({ id => $id })

Liefert Informationen über die Datenbank mit der Id $id als
Hashreferenz zurück. Es sind dies neben der Id $id auch Informationen
über den Titel title, hints, content, instructions, subjects,
keywords, appearance, access, access_info sowie db_type.

=item get_dbreadme({ id => $id })

Liefert zur Datenbank mit der Id $id generelle Nutzungsinformationen
als Hashreferenz zurück. Neben dem Titel title sind das Informationen
periods (color, label, readme_link, warpto_link) über alle
verschiedenen Zeiträume.

=back

=head1 EXPORT

Es werden keine Funktionen exportiert. Alle Funktionen muessen
vollqualifiziert verwendet werden.  Bei mod_perl bedeutet dieser
Verzicht auf den Exporter weniger Speicherverbrauch und mehr
Performance auf Kosten von etwas mehr Schreibarbeit.

=head1 AUTHOR

Oliver Flimm <flimm@openbib.org>

=cut
