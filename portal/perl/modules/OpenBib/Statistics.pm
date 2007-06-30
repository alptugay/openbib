#####################################################################
#
#  OpenBib::Statistics
#
#  Dieses File ist (C) 2006 Oliver Flimm <flimm@openbib.org>
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

package OpenBib::Statistics;

use strict;
use warnings;
no warnings 'redefine';
use utf8;

use Encode qw(decode_utf8 encode_utf8);
use Log::Log4perl qw(get_logger :levels);
use Storable ();

use OpenBib::Config;

sub new {
    my ($class) = @_;

    # Log4perl logger erzeugen
    my $logger = get_logger();

    my $config = new OpenBib::Config();
    
    my $self = { };

    bless ($self, $class);

    # Verbindung zur SQL-Datenbank herstellen
    my $dbh
        = DBI->connect("DBI:$config->{dbimodule}:dbname=$config->{statisticsdbname};host=$config->{statisticsdbhost};port=$config->{statisticsdbport}", $config->{statisticsdbuser}, $config->{statisticsdbpasswd})
            or $logger->error($DBI::errstr);

    $self->{dbh}       = $dbh;

    return $self;
}

sub store_relevance {
    my ($self,$arg_ref)=@_;

    # Set defaults
    my $tstamp            = exists $arg_ref->{tstamp}
        ? $arg_ref->{tstamp}        : undef;
    my $id                = exists $arg_ref->{id}
        ? $arg_ref->{id    }        : undef;
    my $isbn              = exists $arg_ref->{isbn}
        ? $arg_ref->{isbn  }        : undef;
    my $dbname            = exists $arg_ref->{dbname}
        ? $arg_ref->{dbname}        : undef;
    my $katkey            = exists $arg_ref->{katkey}
        ? $arg_ref->{katkey}        : undef;
    my $type              = exists $arg_ref->{type}
        ? $arg_ref->{type  }        : undef;

    # Log4perl logger erzeugen
    my $logger = get_logger();

    return undef unless (defined $id && defined $dbname && defined $katkey && defined $type && defined $self->{dbh});
    
    my $request=$self->{dbh}->prepare("insert into relevance values (?,?,?,?,?,?)") or $logger->error($DBI::errstr);
    $request->execute($tstamp,$id,$isbn,$dbname,$katkey,$type) or $logger->error($DBI::errstr);
    return;
}

sub store_result {
    my ($self,$arg_ref)=@_;

    # Set defaults
    my $id                = exists $arg_ref->{id}
        ? $arg_ref->{id           } : undef;
    my $type              = exists $arg_ref->{type}
        ? $arg_ref->{type  }        : undef;
    my $data_ref          = exists $arg_ref->{data}
        ? $arg_ref->{data  }        : undef;

    # Log4perl logger erzeugen
    my $logger = get_logger();

    return undef unless (defined $id && defined $type && defined $data_ref && defined $self->{dbh});
    
    my $request=$self->{dbh}->prepare("delete from result_data where id=? and type=?") or $logger->error($DBI::errstr);
    $request->execute($id,$type) or $logger->error($DBI::errstr);

    my $datastring=unpack "H*", Storable::freeze($data_ref);
    
    $request=$self->{dbh}->prepare("insert into result_data values (?,NULL,?,?)") or $logger->error($DBI::errstr);
    $request->execute($id,$type,$datastring) or $logger->error($DBI::errstr);

    return;
}

sub get_result {
    my ($self,$arg_ref)=@_;

    # Set defaults
    my $id                = exists $arg_ref->{id}
        ? $arg_ref->{id           } : undef;
    my $type              = exists $arg_ref->{type}
        ? $arg_ref->{type  }        : undef;

    # Log4perl logger erzeugen
    my $logger = get_logger();

    return undef unless (defined $id && defined $type);
    
    my $request=$self->{dbh}->prepare("select data from result_data where id=? and type=?") or $logger->error($DBI::errstr);
    $request->execute($id,$type) or $logger->error($DBI::errstr);

    my $data_ref;
    while (my $result=$request->fetchrow_hashref){
        my $datastring = $result->{data};
        
        $data_ref     = Storable::thaw(pack "H*",$datastring);
    }

    return $data_ref;
}

sub log_event {
    my ($self,$arg_ref)=@_;

    # Set defaults
    my $sessionID    = exists $arg_ref->{sessionID}
        ? $arg_ref->{sessionID}          : undef;

    my $tstamp       = exists $arg_ref->{tstamp}
        ? $arg_ref->{tstamp}             : undef;

    my $type         = exists $arg_ref->{type}
        ? $arg_ref->{type}               : undef;
    
    my $content      = exists $arg_ref->{content}
        ? $arg_ref->{content}            : undef;

    # Log4perl logger erzeugen
    my $logger = get_logger();

    # Moegliche Event-Typen
    #
    # Recherchen:
    #   1 => Recherche-Anfrage bei Virtueller Recherche
    #  10 => Eineltrefferanzeige
    #
    # Allgemeine Informationen
    # 100 => View
    # 101 => Browser
    # 102 => IP des Klienten
    # Redirects 
    # 500 => TOC / hbz-Server
    # 501 => TOC / ImageWaere-Server
    # 510 => BibSonomy
    # 520 => Wikipedia / Personen
    # 521 => Wikipedia / ISBN
    # 530 => EZB
    # 531 => DBIS
    # 532 => Kartenkatalog Philfak
    # 533 => MedPilot
    # 540 => HBZ-Monofernleihe
    # 541 => HBZ-Dokumentenlieferung
    # 550 => WebOPAC
    
    my $request=$self->{dbh}->prepare("insert into eventlog values (?,?,?,?)") or $logger->error($DBI::errstr);
    $request->execute($sessionID,$tstamp,$type,$content) or $logger->error($DBI::errstr);
    $request->finish;

    return;
}

sub get_number_of_event {
    my ($self,$arg_ref)=@_;

    # Set defaults
    my $tstamp       = exists $arg_ref->{tstamp}
        ? $arg_ref->{tstamp}             : undef;

    my $type         = exists $arg_ref->{type}
        ? $arg_ref->{type}               : undef;
    
    my $content      = exists $arg_ref->{content}
        ? $arg_ref->{content}            : undef;

    # Log4perl logger erzeugen
    my $logger = get_logger();

    my $sqlstring="select count(tstamp) as rowcount, min(tstamp) as mintstamp from eventlog";

    my @sqlwhere = ();
    my @sqlargs  = ();

    if ($type){
        push @sqlwhere, " type = ?";
	push @sqlargs,  $type;
    } 

    if ($content){
        push @sqlwhere, " content = ?";
	push @sqlargs,  $content;
    } 

    my $sqlwherestring  = join(" and ",@sqlwhere);

    if ($sqlwherestring){
      $sqlstring.=" where $sqlwherestring";
    }

    $logger->debug($sqlstring." ".join(" - ",@sqlargs));
    my $request=$self->{dbh}->prepare($sqlstring) or $logger->error($DBI::errstr);
    $request->execute(@sqlargs) or $logger->error($DBI::errstr);
    
    my $res        = $request->fetchrow_hashref;
    my $count      = $res->{rowcount};
    my $mintstamp  = $res->{mintstamp};


    $request->finish;

    return {
	    number => $count,
	    since  => $mintstamp,
	    }
}

sub get_ranking_of_event {
    my ($self,$arg_ref)=@_;

    # Set defaults
    my $tstamp       = exists $arg_ref->{tstamp}
        ? $arg_ref->{tstamp}             : undef;

    my $type         = exists $arg_ref->{type}
        ? $arg_ref->{type}               : undef;
    
    # Log4perl logger erzeugen
    my $logger = get_logger();

    my $sqlstring="select count(content) as rowcount, content, min(tstamp) as mintstamp from eventlog";

    my @sqlwhere = ();
    my @sqlargs  = ();

    if ($type){
        push @sqlwhere, " type = ?";
	push @sqlargs,  $type;
    } 

    my $sqlwherestring  = join(" and ",@sqlwhere);

    if ($sqlwherestring){
      $sqlstring.=" where $sqlwherestring";
    }

    $sqlstring.=" group by content order by rowcount DESC";

    $logger->debug($sqlstring." ".join(" - ",@sqlargs));
    my $request=$self->{dbh}->prepare($sqlstring) or $logger->error($DBI::errstr);
    $request->execute(@sqlargs) or $logger->error($DBI::errstr);

    my @ranking=();

    while (my $res = $request->fetchrow_hashref){
        my $count      = $res->{rowcount};
	my $content    = $res->{content};
	my $mintstamp  = $res->{mintstamp};

	push @ranking, {
			content   => $content,
			number    => $count,
			since     => $mintstamp,
		       };
    }
    $request->finish;

    $logger->debug(YAML::Dump(\@ranking));

    return @ranking;
}

sub log_query {
    my ($self,$arg_ref)=@_;

    my $tstamp       = exists $arg_ref->{tstamp}
        ? $arg_ref->{tstamp}             : undef;

    # Set defaults
    my $view            = exists $arg_ref->{view}
        ? $arg_ref->{view}               : undef;

    my $searchquery_ref = exists $arg_ref->{searchquery_ref}
        ? $arg_ref->{searchquery_ref}    : undef;

    # Log4perl logger erzeugen
    my $logger = get_logger();

    # Moegliche Queryterm-Typen
    #
    # 01 => fs
    # 02 => hst 
    # 03 => verf
    # 04 => kor
    # 05 => swt
    # 06 => notation
    # 07 => isbn
    # 08 => issn
    # 09 => sign
    # 10 => mart
    # 11 => hststring
    # 12 => gtquelle
    # 13 => ejahr

    my $cat2type_ref = {
			fs        => 1,
			hst       => 2,
			verf      => 3,
			kor       => 4,
			swt       => 5,
			notation  => 6,
			isbn      => 7,
			issn      => 8,
			sign      => 9,
			mart      => 10,
			hststring => 11,
			gtquelle  => 12,
			ejahr     => 13,
		       };

    my $used_category_ref = {
			fs        => 0,
			hst       => 0,
			verf      => 0,
			kor       => 0,
			swt       => 0,
			notation  => 0,
			isbn      => 0,
			issn      => 0,
			sign      => 0,
			mart      => 0,
			hststring => 0,
			gtquelle  => 0,
			ejahr     => 0,
			    };

    my $termrequest     = $self->{dbh}->prepare("insert into queryterm values (?,?,?,?)") or $logger->error($DBI::errstr);
    my $categoryrequest = $self->{dbh}->prepare("insert into querycategory values (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)") or $logger->error($DBI::errstr);

    foreach my $cat (keys %$cat2type_ref){
        my $thiscategory_terms = $searchquery_ref->{$cat}->{val};
	
	$thiscategory_terms    =~s/[^\p{Alphabetic}0-9 ]//g;

	# Genutzte Kategorie merken
	if ($thiscategory_terms){
	  $used_category_ref->{$cat} = 1;
	}

	my $tokenizer = String::Tokenizer->new();
	$tokenizer->tokenize($thiscategory_terms);
	
	my $i = $tokenizer->iterator();
	
	while ($i->hasNextToken()) {
	  my $next = $i->nextToken();
	  next if (!$next);
	  
	  $termrequest->execute($tstamp,$view,$cat2type_ref->{$cat},encode_utf8($next)) or $logger->error($DBI::errstr);
	}
    }
    
    $categoryrequest->execute($tstamp,$view,
			      $used_category_ref->{fs},
			      $used_category_ref->{hst},
			      $used_category_ref->{verf},
			      $used_category_ref->{kor},
			      $used_category_ref->{swt},
			      $used_category_ref->{notation},
			      $used_category_ref->{isbn},
			      $used_category_ref->{issn},
			      $used_category_ref->{sign},
			      $used_category_ref->{mart},
			      $used_category_ref->{hststring},
			      $used_category_ref->{gtquelle},
			      $used_category_ref->{ejahr}
			     ) or $logger->error($DBI::errstr);

    return;
}

sub DESTROY {
    my $self = shift;

    return if (!defined $self->{dbh});

    $self->{dbh}->disconnect();

    return;
}

1;
