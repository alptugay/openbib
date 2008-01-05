#####################################################################
#
#  OpenBib::Record::Title.pm
#
#  Titel
#
#  Dieses File ist (C) 2007 Oliver Flimm <flimm@openbib.org>
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

use Apache::Reload;
use Benchmark ':hireswallclock';
use DBI;
use Encode 'decode_utf8';
use Log::Log4perl qw(get_logger :levels);
use SOAP::Lite;
use Storable;
use YAML ();

use OpenBib::Common::Util;
use OpenBib::Record::Person;
use OpenBib::Record::CorporateBody;
use OpenBib::Record::Subject;
use OpenBib::Record::Classification;
use OpenBib::Search::Util;

sub new {
    my ($class,$arg_ref) = @_;

    # Set defaults
    my $database  = exists $arg_ref->{database}
        ? $arg_ref->{database}       : undef;

    # Log4perl logger erzeugen
    my $logger = get_logger();

    my $config = new OpenBib::Config();
    
    my $self = { };

    bless ($self, $class);

    $self->{config}         = $config;
    $self->{targetdbinfo}   = $self->{config}->get_targetdbinfo();
    $self->{targetcircinfo} = $self->{config}->get_targetcircinfo();

    if (defined $database){
        $self->{database} = $database;

        my $dbh = DBI->connect("DBI:$config->{dbimodule}:dbname=$database;host=$config->{dbhost};port=$config->{dbport}", $config->{dbuser}, $config->{dbpasswd})
            or $logger->error_die($DBI::errstr);
        $self->{dbh} = $dbh;
    }

    $logger->debug("Title-Record-Object created: ".YAML::Dump($self));
    return $self;
}

sub get_full_record {
    my ($self,$arg_ref) = @_;

    # Set defaults
    my $id                = exists $arg_ref->{id}
        ? $arg_ref->{id}                : undef;

    # Log4perl logger erzeugen
    my $logger = get_logger();

    # (Re-)Initialisierung
    delete $self->{normset}       if (exists $self->{normset});
    delete $self->{mexset}        if (exists $self->{mexset});
    delete $self->{circset}       if (exists $self->{circset});
    delete $self->{brief_normset} if (exists $self->{brief_normset});

    my $normset_ref={};

    $self->{id      }        = $id;
    $normset_ref->{id      } = $id;
    $normset_ref->{database} = $self->{database};

    # Titelkategorien
    {
        
        my ($atime,$btime,$timeall)=(0,0,0);
        
        if ($self->{config}->{benchmark}) {
            $atime=new Benchmark;
        }
        
        my $reqstring="select * from tit where id = ?";
        my $request=$self->{dbh}->prepare($reqstring) or $logger->error($DBI::errstr);
        $request->execute($id) or $logger->error("Request: $reqstring - ".$DBI::errstr);
        
        while (my $res=$request->fetchrow_hashref) {
            my $category  = "T".sprintf "%04d",$res->{category };
            my $indicator =        decode_utf8($res->{indicator});
            my $content   =        decode_utf8($res->{content  });

            push @{$normset_ref->{$category}}, {
                indicator => $indicator,
                content   => $content,
            };
        }
        $request->finish();

        if ($self->{config}->{benchmark}) {
            $btime=new Benchmark;
            $timeall=timediff($btime,$atime);
            $logger->info("Zeit fuer : $reqstring : ist ".timestr($timeall));
        }
    }
    
    # Verknuepfte Normdaten
    {
        my ($atime,$btime,$timeall)=(0,0,0);
        
        if ($self->{config}->{benchmark}) {
            $atime=new Benchmark;
        }
        
        my $reqstring="select category,targetid,targettype,supplement from conn where sourceid=? and sourcetype=1 and targettype IN (2,3,4,5)";
        my $request=$self->{dbh}->prepare($reqstring) or $logger->error($DBI::errstr);
        $request->execute($id) or $logger->error("Request: $reqstring - ".$DBI::errstr);
        
        while (my $res=$request->fetchrow_hashref) {
            my $category   = "T".sprintf "%04d",$res->{category };
            my $targetid   =        decode_utf8($res->{targetid  });
            my $targettype =                    $res->{targettype};
            my $supplement =        decode_utf8($res->{supplement});
            
	    # Korrektes UTF-8 Encoding Flag wird in get_*_ans_*
	    # vorgenommen
            
            my $recordclass    =
                ($targettype == 2 )?"OpenBib::Record::Person":
                    ($targettype == 3 )?"OpenBib::Record::CorporateBody":
                        ($targettype == 4 )?"OpenBib::Record::Subject":
                            ($targettype == 5 )?"OpenBib::Record::Classification":undef;
            
            my $content = "";
            if (defined $recordclass){
                my $record=$recordclass->new({database=>$self->{database}});
                $record->get_name({id=>$targetid});
                $content=$record->name_as_string;
            }
            
            push @{$normset_ref->{$category}}, {
                id         => $targetid,
                content    => $content,
                supplement => $supplement,
            };
        }
        $request->finish();
        
        if ($self->{config}->{benchmark}) {
            $btime=new Benchmark;
            $timeall=timediff($btime,$atime);
            $logger->info("Zeit fuer : $reqstring : ist ".timestr($timeall));
        }
    }
    
    # Verknuepfte Titel
    {
        my ($atime,$btime,$timeall)=(0,0,0);
        
        my $reqstring;
        my $request;
        my $res;
        
        # Unterordnungen
        if ($self->{config}->{benchmark}) {
            $atime=new Benchmark;
        }
        
        $reqstring="select count(distinct targetid) as conncount from conn where sourceid=? and sourcetype=1 and targettype=1";
        $request=$self->{dbh}->prepare($reqstring) or $logger->error($DBI::errstr);
        $request->execute($id) or $logger->error("Request: $reqstring - ".$DBI::errstr);
        
        $res=$request->fetchrow_hashref;

        if ($res->{conncount} > 0){
            push @{$normset_ref->{T5001}}, {
                content => $res->{conncount},
            };
        }
        
        if ($self->{config}->{benchmark}) {
            $btime=new Benchmark;
            $timeall=timediff($btime,$atime);
            $logger->info("Zeit fuer : $reqstring : ist ".timestr($timeall));
        }

        # Ueberordnungen
        if ($self->{config}->{benchmark}) {
            $atime=new Benchmark;
        }

        $reqstring="select count(distinct sourceid) as conncount from conn where targetid=? and sourcetype=1 and targettype=1";
        $request=$self->{dbh}->prepare($reqstring) or $logger->error($DBI::errstr);
        $request->execute($id) or $logger->error("Request: $reqstring - ".$DBI::errstr);
        
        $res=$request->fetchrow_hashref;

        if ($res->{conncount} > 0){
            push @{$normset_ref->{T5002}}, {
                content => $res->{conncount},
            };
        }
        
        if ($self->{config}->{benchmark}) {
            $btime=new Benchmark;
            $timeall=timediff($btime,$atime);
            $logger->info("Zeit fuer : $reqstring : ist ".timestr($timeall));
        }


        $request->finish();
    }

    # Exemplardaten
    my $mexnormset_ref=[];
    {
        
        my $reqstring="select distinct targetid from conn where sourceid= ? and sourcetype=1 and targettype=6";
        my $request=$self->{dbh}->prepare($reqstring) or $logger->error($DBI::errstr);
        $request->execute($id) or $logger->error("Request: $reqstring - ".$DBI::errstr);
        
        my @verknmex=();
        while (my $res=$request->fetchrow_hashref){
            push @verknmex, decode_utf8($res->{targetid});
        }
        $request->finish();
        
        if ($#verknmex >= 0) {
            foreach my $mexid (@verknmex) {
                push @$mexnormset_ref, $self->_get_mex_set_by_idn({
                    id             => $mexid,
                });
            }
        }

    }

    # Ausleihinformationen der Exemplare
    my @circexemplarliste = ();
    {
        my $circexlist=undef;

        if (exists $self->{targetcircinfo}->{$self->{database}}{circ}) {

            my $circid=(exists $normset_ref->{'T0001'}[0]{content} && $normset_ref->{'T0001'}[0]{content} > 0 && $normset_ref->{'T0001'}[0]{content} != $id )?$normset_ref->{'T0001'}[0]{content}:$id;

            $logger->debug("Katkey: $id - Circ-ID: $circid");

            eval {
                my $soap = SOAP::Lite
                    -> uri("urn:/MediaStatus")
                        -> proxy($self->{targetcircinfo}->{$self->{database}}{circcheckurl});
                my $result = $soap->get_mediastatus(
                SOAP::Data->name(parameter  =>\SOAP::Data->value(
                    SOAP::Data->name(katkey   => $circid)->type('string'),
                    SOAP::Data->name(database => $self->{targetcircinfo}->{$self->{database}}{circdb})->type('string'))));
                
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
            @circexemplarliste = @{$circexlist};
        }
        
        if (exists $self->{targetcircinfo}->{$self->{database}}{circ}
                && $#circexemplarliste >= 0) {
            for (my $i=0; $i <= $#circexemplarliste; $i++) {
                
                my $bibliothek="-";
                my $sigel=$self->{targetdbinfo}->{dbases}{$self->{database}};
                
                if (length($sigel)>0) {
                    if (exists $self->{targetdbinfo}->{sigel}{$sigel}) {
                        $bibliothek=$self->{targetdbinfo}->{sigel}{$sigel};
                    }
                    else {
                        $bibliothek="($sigel)";
                    }
                }
                else {
                    if (exists $self->{targetdbinfo}->{sigel}{$self->{targetdbinfo}->{dbases}{$self->{database}}}) {
                        $bibliothek=$self->{targetdbinfo}->{sigel}{
                            $self->{targetdbinfo}->{dbases}{$self->{database}}};
                    }
                }
                
                my $bibinfourl=$self->{targetdbinfo}->{bibinfo}{
                    $self->{targetdbinfo}->{dbases}{$self->{database}}};
                
                $circexemplarliste[$i]{'Bibliothek'} = $bibliothek;
                $circexemplarliste[$i]{'Bibinfourl'} = $bibinfourl;
                $circexemplarliste[$i]{'Ausleihurl'} = $self->{targetcircinfo}->{$self->{database}}{circurl};
            }
        }
        else {
            @circexemplarliste=();
        }
    }

    # Anreicherung mit zentralen Enrichmentdaten
    {
        my ($atime,$btime,$timeall);
        
        if ($self->{config}->{benchmark}) {
            $atime=new Benchmark;
        }
        
        # Verbindung zur SQL-Datenbank herstellen
        my $enrichdbh
            = DBI->connect("DBI:$self->{config}->{dbimodule}:dbname=$self->{config}->{enrichmntdbname};host=$self->{config}->{enrichmntdbhost};port=$self->{config}->{enrichmntdbport}", $self->{config}->{enrichmntdbuser}, $self->{config}->{enrichmntdbpasswd})
                or $logger->error_die($DBI::errstr);
        
        if (exists $normset_ref->{T0540}){
            foreach my $isbn_ref (@{$normset_ref->{T0540}}){

                my $isbn=$isbn_ref->{content};
            
                $isbn =~s/ //g;
                $isbn =~s/-//g;
                $isbn=~s/([A-Z])/\l$1/g;
                        
                my $reqstring="select category,content from normdata where isbn=? order by category,indicator";
                my $request=$enrichdbh->prepare($reqstring) or $logger->error($DBI::errstr);
                $request->execute($isbn) or $logger->error("Request: $reqstring - ".$DBI::errstr);
            
                while (my $res=$request->fetchrow_hashref) {
                    my $category   = "T".sprintf "%04d",$res->{category };
                    my $content    =        decode_utf8($res->{content});
                
                    push @{$normset_ref->{$category}}, {
                        content    => $content,
                    };
                }
                $request->finish();
                $logger->debug("Enrich: $isbn -> $reqstring");
            }
        }

        $enrichdbh->disconnect();

        if ($self->{config}->{benchmark}) {
            $btime=new Benchmark;
            $timeall=timediff($btime,$atime);
            $logger->info("Zeit fuer : Bestimmung von Enrich-Normdateninformationen ist ".timestr($timeall));
            undef $atime;
            undef $btime;
            undef $timeall;
        }
    }

    $logger->debug(YAML::Dump($normset_ref));
    ($self->{normset},$self->{mexset},$self->{circset})=($normset_ref,$mexnormset_ref,\@circexemplarliste);

    return $self;
}

sub get_brief_record {
    my ($self,$arg_ref) = @_;

    # Set defaults
    my $id                = exists $arg_ref->{id}
        ? $arg_ref->{id}                : undef;

    # Log4perl logger erzeugen
    my $logger = get_logger();

    # (Re-)Initialisierung
    delete $self->{normset}       if (exists $self->{normset});
    delete $self->{mexset}        if (exists $self->{mexset});
    delete $self->{circset}       if (exists $self->{circset});
    delete $self->{brief_normset} if (exists $self->{brief_normset});
    
    my $listitem_ref={};
    
    # Titel-ID und zugehoerige Datenbank setzen

    $self->{id    }           = $id;
    $listitem_ref->{id      } = $id;
    $listitem_ref->{database} = $self->{database};
    
    my ($atime,$btime,$timeall)=(0,0,0);
    
    if ($self->{config}->{benchmark}) {
        $atime  = new Benchmark;
    }

    if ($self->{config}->{use_titlistitem_table}) {
        # Bestimmung des Satzes
        my $request=$self->{dbh}->prepare("select listitem from titlistitem where id = ?") or $logger->error($DBI::errstr);
        $request->execute($id);
        
        if (my $res=$request->fetchrow_hashref){
            my $titlistitem     = $res->{listitem};
            
            $logger->debug("Storable::listitem: $titlistitem");

            my $encoding_type="hex";

            if    ($encoding_type eq "base64"){
                $titlistitem = MIME::Base64::decode($titlistitem);
            }
            elsif ($encoding_type eq "hex"){
                $titlistitem = pack "H*",$titlistitem;
            }
            elsif ($encoding_type eq "uu"){
                $titlistitem = unpack "u",$titlistitem;
            }

            my %titlistitem = %{ Storable::thaw($titlistitem) };
            
            $logger->debug("TitlistitemYAML: ".YAML::Dump(\%titlistitem));
            %$listitem_ref=(%$listitem_ref,%titlistitem);

        }
    }
    else {
        my ($atime,$btime,$timeall)=(0,0,0);
        
        if ($self->{config}->{benchmark}) {
            $atime  = new Benchmark;
        }

        # Bestimmung der Titelinformationen
        my $request=$self->{dbh}->prepare("select category,indicator,content from tit where id = ? and category in (0310,0331,0403,0412,0424,0425,0451,0455,1203,0089)") or $logger->error($DBI::errstr);
        #    my $request=$self->{dbh}->prepare("select category,indicator,content from tit where id = ? ") or $logger->error($DBI::errstr);
        $request->execute($id);
        
        while (my $res=$request->fetchrow_hashref){
            my $category  = "T".sprintf "%04d",$res->{category };
            my $indicator =        decode_utf8($res->{indicator});
            my $content   =        decode_utf8($res->{content  });
            
            push @{$listitem_ref->{$category}}, {
                indicator => $indicator,
                content   => $content,
            };
        }
        
        $logger->debug("Titel: ".YAML::Dump($listitem_ref));
        
        if ($self->{config}->{benchmark}) {
            $btime=new Benchmark;
            $timeall=timediff($btime,$atime);
            $logger->info("Zeit fuer : Bestimmung der Titelinformationen : ist ".timestr($timeall));
        }
        
        
        if ($self->{config}->{benchmark}) {
            $atime=new Benchmark;
        }
        
        # Bestimmung der Exemplarinformationen
        $request=$self->{dbh}->prepare("select mex.category,mex.indicator,mex.content from mex,conn where conn.sourceid = ? and conn.targetid=mex.id and conn.sourcetype=1 and conn.targettype=6 and mex.category=0014") or $logger->error($DBI::errstr);
        $request->execute($id);
        
        while (my $res=$request->fetchrow_hashref){
            my $category  = "X".sprintf "%04d",$res->{category };
            my $indicator =        decode_utf8($res->{indicator});
            my $content   =        decode_utf8($res->{content  });
            
            push @{$listitem_ref->{$category}}, {
                indicator => $indicator,
                content   => $content,
            };
        }
        
        
        if ($self->{config}->{benchmark}) {
            $btime=new Benchmark;
            $timeall=timediff($btime,$atime);
            $logger->info("Zeit fuer : Bestimmung der Exemplarinformationen : ist ".timestr($timeall));
        }
        
        
        if ($self->{config}->{benchmark}) {
            $atime=new Benchmark;
        }
        
        my @autkor=();
        
        # Bestimmung der Verfasser, Personen
        #
        # Bemerkung zur Performance: Mit Profiling (Devel::SmallProf) wurde
        # festgestellt, dass die Bestimmung der Information ueber conn
        # und get_*_ans_by_idn durchschnittlich ungefaehr um den Faktor 30-50
        # schneller ist als ein join ueber conn und aut (!)
        $request=$self->{dbh}->prepare("select targetid,category,supplement from conn where sourceid=? and sourcetype=1 and targettype=2") or $logger->error($DBI::errstr);
        $request->execute($id);
        
        while (my $res=$request->fetchrow_hashref){
            my $category  = "P".sprintf "%04d",$res->{category };
            my $indicator =        decode_utf8($res->{indicator});
            my $targetid  =        decode_utf8($res->{targetid});
            
            my $supplement="";
            if ($res->{supplement}){
                $supplement=" ".decode_utf8($res->{supplement});
            }

            my $content=OpenBib::Record::Person->new({database => $self->{database}})->get_name({id => $targetid})->name_as_string.$supplement;

            # Kategorieweise Abspeichern
            push @{$listitem_ref->{$category}}, {
                id      => $targetid,
                type    => 'aut',
                content => $content,
            };
            
            # Gemeinsam Abspeichern
            push @autkor, $content;
        }
        
        if ($self->{config}->{benchmark}) {
            $btime=new Benchmark;
            $timeall=timediff($btime,$atime);
            $logger->info("Zeit fuer : Bestimmung der Verfasserinformationen : ist ".timestr($timeall));
        }
        
        if ($self->{config}->{benchmark}) {
            $atime=new Benchmark;
        }    
        
        # Bestimmung der Urheber, Koerperschaften
        $request=$self->{dbh}->prepare("select targetid,category,supplement from conn where sourceid=? and sourcetype=1 and targettype=3") or $logger->error($DBI::errstr);
        $request->execute($id);
        
        while (my $res=$request->fetchrow_hashref){
            my $category  = "C".sprintf "%04d",$res->{category };
            my $indicator =        decode_utf8($res->{indicator});
            my $targetid  =        decode_utf8($res->{targetid});
            
            my $supplement="";
            if ($res->{supplement}){
                $supplement.=" ".decode_utf8($res->{supplement});
            }

            my $content=OpenBib::Record::CorporateBody->new({database => $self->{database}})->get_name({id => $targetid})->name_as_string.$supplement;
            
            # Kategorieweise Abspeichern
            push @{$listitem_ref->{$category}}, {
                id      => $targetid,
                type    => 'kor',
                content => $content,
            };
            
            # Gemeinsam Abspeichern
            push @autkor, $content;
        }
        
        if ($self->{config}->{benchmark}) {
            $btime=new Benchmark;
            $timeall=timediff($btime,$atime);
            $logger->info("Zeit fuer : Bestimmung der Koerperschaftsinformationen : ist ".timestr($timeall));
        }
        
        # Zusammenfassen von autkor fuer die Sortierung
        
        push @{$listitem_ref->{'PC0001'}}, {
            content   => join(" ; ",@autkor),
        };
        
        if ($self->{config}->{benchmark}) {
            $atime=new Benchmark;
        }    
        
        
        $request->finish();
        
        $logger->debug("Vor Sonderbehandlung: ".YAML::Dump($listitem_ref));

        # Konzeptionelle Vorgehensweise fuer die korrekte Anzeige eines Titel in
        # der Kurztitelliste:
        #
        # 1. Fall: Es existiert ein HST
        #
        # Dann:
        #
        # Ist nichts zu tun
        #
        # 2. Fall: Es existiert kein HST(331)
        #
        # Dann:
        #
        # Unterfall 2.1: Es existiert eine (erste) Bandzahl(089)
        #
        # Dann: Verwende diese Bandzahl
        #
        # Unterfall 2.2: Es existiert keine Bandzahl(089), aber eine (erste)
        #                Bandzahl(455)
        #
        # Dann: Verwende diese Bandzahl
        #
        # Unterfall 2.3: Es existieren keine Bandzahlen, aber ein (erster)
        #                Gesamttitel(451)
        #
        # Dann: Verwende diesen GT
        #
        # Unterfall 2.4: Es existieren keine Bandzahlen, kein Gesamttitel(451),
        #                aber eine Zeitschriftensignatur(1203/USB-spezifisch)
        #
        # Dann: Verwende diese Zeitschriftensignatur
        #

        if (!exists $listitem_ref->{T0331}) {
            # UnterFall 2.1:
            if (exists $listitem_ref->{'T0089'}) {
                $listitem_ref->{T0331}[0]{content}=$listitem_ref->{T0089}[0]{content};
            }
            # Unterfall 2.2:
            elsif (exists $listitem_ref->{T0455}) {
                $listitem_ref->{T0331}[0]{content}=$listitem_ref->{T0455}[0]{content};
            }
            # Unterfall 2.3:
            elsif (exists $listitem_ref->{T0451}) {
                $listitem_ref->{T0331}[0]{content}=$listitem_ref->{T0451}[0]{content};
            }
            # Unterfall 2.4:
            elsif (exists $listitem_ref->{T1203}) {
                $listitem_ref->{T0331}[0]{content}=$listitem_ref->{T1203}[0]{content};
            } else {
                $listitem_ref->{T0331}[0]{content}="Kein HST/AST vorhanden";
            }
        }

        # Bestimmung der Zaehlung

        # Fall 1: Es existiert eine (erste) Bandzahl(089)
        #
        # Dann: Setze diese Bandzahl
        #
        # Fall 2: Es existiert keine Bandzahl(089), aber eine (erste)
        #                Bandzahl(455)
        #
        # Dann: Setze diese Bandzahl

        # Fall 1:
        if (exists $listitem_ref->{'T0089'}) {
            $listitem_ref->{T5100}= [
                {
                    content => $listitem_ref->{T0089}[0]{content}
                }
            ];
        }
        # Fall 2:
        elsif (exists $listitem_ref->{T0455}) {
            $listitem_ref->{T5100}= [
                {
                    content => $listitem_ref->{T0455}[0]{content}
                }
            ];
        }
                
        if ($self->{config}->{benchmark}) {
            $btime=new Benchmark;
            $timeall=timediff($btime,$atime);
            $logger->info("Zeit fuer : Bestimmung der HST-Ueberordnungsinformationen : ist ".timestr($timeall));
        }

        if ($self->{config}->{benchmark}) {
            $atime=new Benchmark;
        }    
        
        # Bestimmung der Popularitaet des Titels
        $request=$self->{dbh}->prepare("select idcount from popularity where id=?") or $logger->error($DBI::errstr);
        $request->execute($id);
        
        while (my $res=$request->fetchrow_hashref){
            $listitem_ref->{popularity} = $res->{idcount};
        }
        
        if ($self->{config}->{benchmark}) {
            $btime=new Benchmark;
            $timeall=timediff($btime,$atime);
            $logger->info("Zeit fuer : Bestimmung der Popularitaetsinformation : ist ".timestr($timeall));
        }

    }

    if ($self->{config}->{benchmark}) {
        $btime=new Benchmark;
        $timeall=timediff($btime,$atime);
        my $timeall=timediff($btime,$atime);
        $logger->info("Zeit fuer : Bestimmung der gesamten Informationen         : ist ".timestr($timeall));
    }

    $logger->debug(YAML::Dump($listitem_ref));

    $self->{brief_normset}=$listitem_ref;

    return $self;


}

sub print_to_handler {
    my ($self,$arg_ref)=@_;

    my $session            = exists $arg_ref->{session}
        ? $arg_ref->{session}            : undef;
    my $queryoptions_ref   = exists $arg_ref->{queryoptions_ref}
        ? $arg_ref->{queryoptions_ref}   : undef;
    my $searchquery_ref    = exists $arg_ref->{searchquery_ref}
        ? $arg_ref->{searchquery_ref}    : undef;
    my $queryid            = exists $arg_ref->{queryid}
        ? $arg_ref->{queryid}            : undef;
    my $r                  = exists $arg_ref->{apachereq}
        ? $arg_ref->{apachereq}          : undef;
    my $stylesheet         = exists $arg_ref->{stylesheet}
        ? $arg_ref->{stylesheet}         : undef;
    my $view               = exists $arg_ref->{view}
        ? $arg_ref->{view}               : undef;
    my $msg                = exists $arg_ref->{msg}
        ? $arg_ref->{msg}                : undef;
    my $no_log             = exists $arg_ref->{no_log}
        ? $arg_ref->{no_log}             : 0;

    # Log4perl logger erzeugen
    my $logger = get_logger();

    my $user   = new OpenBib::User({sessionID => $session->{ID}});

    my $loginname     = $user->get_username();
    my $logintargetdb = $user->get_targetdb_of_session($session->{ID});

    my ($prevurl,$nexturl)=OpenBib::Search::Util::get_result_navigation({
        sessiondbh => $session->{dbh},
        database   => $self->{database},
        titidn     => $self->{id},
        sessionID  => $session->{ID},
    });

    my $poolname=$self->{targetdbinfo}->{dbnames}{$self->{database}};

    # Literaturlisten finden

    my $litlists_ref = $user->get_litlists_of_tit({titid => $self->{id}, titdb => $self->{database}});
    
    # TT-Data erzeugen
    my $ttdata={
        view        => $view,
        stylesheet  => $stylesheet,
        database    => $self->{database},
        poolname    => $poolname,
        prevurl     => $prevurl,
        nexturl     => $nexturl,
        qopts       => $queryoptions_ref,
        queryid     => $queryid,
        sessionID   => $session->{ID},
        titidn      => $self->{id},
        normset     => $self->{normset},
        mexnormset  => $self->{mexnormset},
        circset     => $self->{circset},
        searchquery => $searchquery_ref,
        activefeed  => $self->{config}->get_activefeeds_of_db($self->{database}),

        user          => $user,
        loginname     => $loginname,
        logintargetdb => $logintargetdb,

        litlists     => $litlists_ref,
        highlightquery    => \&highlightquery,
        normset2bibtex    => \&OpenBib::Common::Util::normset2bibtex,
        normset2bibsonomy => \&OpenBib::Common::Util::normset2bibsonomy,

        record      => $self,
        config      => $self->{config},
        
        msg         => $msg,
    };

    OpenBib::Common::Util::print_page($self->{config}->{tt_search_showtitset_tname},$ttdata,$r);

    # Log Event

    my $isbn;

    if (exists $self->{normset}->{T0540}[0]{content}){
        $isbn = $self->{normset}->{T0540}[0]{content};
        $isbn =~s/ //g;
        $isbn =~s/-//g;
        $isbn =~s/X/x/g;
    }

    if (!$no_log){
        $session->log_event({
            type      => 10,
            content   => {
                id       => $self->{id},
                database => $self->{database},
                isbn     => $isbn,
            },
            serialize => 1,
        });
    }
    
    return;
}

sub _get_mex_set_by_idn {
    my ($self,$arg_ref) = @_;

    # Set defaults
    my $id                = exists $arg_ref->{id}
        ? $arg_ref->{id}               : undef;

    # Log4perl logger erzeugen
    my $logger = get_logger();

    my $normset_ref={};

    # Defaultwerte setzen
    $normset_ref->{X0005}{content}="-";
    $normset_ref->{X0014}{content}="-";
    $normset_ref->{X0016}{content}="-";
    $normset_ref->{X1204}{content}="-";
    $normset_ref->{X4000}{content}="-";
    $normset_ref->{X4001}{content}="";

    my ($atime,$btime,$timeall);
    if ($self->{config}->{benchmark}) {
	$atime=new Benchmark;
    }

    my $sqlrequest="select category,content,indicator from mex where id = ?";
    my $result=$self->{dbh}->prepare($sqlrequest) or $logger->error($DBI::errstr);
    $result->execute($id);

    while (my $res=$result->fetchrow_hashref){
        my $category  = "X".sprintf "%04d",$res->{category };
        my $indicator =        decode_utf8($res->{indicator});
        my $content   =        decode_utf8($res->{content  });
        
        # Exemplar-Normdaten werden als nicht multipel angenommen
        # und dementsprechend vereinfacht in einer Datenstruktur
        # abgelegt
        $normset_ref->{$category} = {
            indicator => $indicator,
            content   => $content,
        };
    }

    if ($self->{config}->{benchmark}) {
	$btime=new Benchmark;
	$timeall=timediff($btime,$atime);
	$logger->info("Zeit fuer : $sqlrequest : ist ".timestr($timeall));
	undef $atime;
	undef $btime;
	undef $timeall;
    }

    my $sigel      = "";
    # Bestimmung des Bibliotheksnamens
    # Ein im Exemplar-Datensatz gefundenes Sigel geht vor
    if (exists $normset_ref->{X3300}{content}) {
        $sigel=$normset_ref->{X3300}{content};
        if (exists $self->{targetdbinfo}->{sigel}{$sigel}) {
            $normset_ref->{X4000}{content}=$self->{targetdbinfo}->{sigel}{$sigel};
        }
        else {
            $normset_ref->{X4000}{content}= {
					     full  => "($sigel)",
					     short => "($sigel)",
					    };
        }
    }
    # sonst wird der Datenbankname zur Findung des Sigels herangezogen
    else {
        $sigel=$self->{targetdbinfo}->{dbases}{$self->{database}};
        if (exists $self->{targetdbinfo}->{sigel}{$sigel}) {
            $normset_ref->{X4000}{content}=$self->{targetdbinfo}->{sigel}{$sigel};
        }
    }

    my $bibinfourl="";

    # Bestimmung der Bibinfo-Url
    if (exists $self->{targetdbinfo}->{bibinfo}{$sigel}) {
        $normset_ref->{X4001}{content}=$self->{targetdbinfo}->{bibinfo}{$sigel};
    }

    return $normset_ref;
}

sub highlightquery {
    my ($searchquery_ref,$content) = @_;

    # Log4perl logger erzeugen
    my $logger = get_logger();
    
    # Highlight Query

    my $term_ref = OpenBib::Common::Util::get_searchterms({
        searchquery_ref => $searchquery_ref,
    });

    return $content if (scalar(@$term_ref) <= 0);

    $logger->debug("Terms: ".YAML::Dump($term_ref));

    my $terms = join("|", grep /^\w{3,}/ ,@$term_ref);

    return $content if (!$terms);
    
    $logger->debug("Term_ref: ".YAML::Dump($term_ref)."\nTerms: $terms");
    $logger->debug("Content vor: ".$content);
    
    $content=~s/\b($terms)/<span class="queryhighlight">$1<\/span>/ig unless ($content=~/http/);

    $logger->debug("Content nach: ".$content);

    return $content;
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
        next if (!exists $self->{normset}->{$category});
        foreach my $part_ref (@{$self->{normset}->{$category}}){
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
        next if (!exists $self->{normset}->{$category});
        foreach my $part_ref (@{$self->{normset}->{$category}}){
            push @$keywords_ref, utf2bibtex($part_ref->{content},$utf8);
        }
    }
    my $keyword = join(' ; ',@$keywords_ref);
    
    # Auflage
    my $edition   = (exists $self->{normset}->{T0403})?utf2bibtex($self->{normset}->{T0403}[0]{content},$utf8):'';

    # Verleger
    my $publisher = (exists $self->{normset}->{T0412})?utf2bibtex($self->{normset}->{T0412}[0]{content},$utf8):'';

    # Verlagsort
    my $address   = (exists $self->{normset}->{T0410})?utf2bibtex($self->{normset}->{T0410}[0]{content},$utf8):'';

    # Titel
    my $title     = (exists $self->{normset}->{T0331})?utf2bibtex($self->{normset}->{T0331}[0]{content},$utf8):'';

    # Zusatz zum Titel
    my $titlesup  = (exists $self->{normset}->{T0335})?utf2bibtex($self->{normset}->{T0335}[0]{content},$utf8):'';

    if ($title && $titlesup){
        $title = "$title : $titlesup";
    }

    # Jahr
    my $year      = (exists $self->{normset}->{T0425})?utf2bibtex($self->{normset}->{T0425}[0]{content},$utf8):'';

    # ISBN
    my $isbn      = (exists $self->{normset}->{T0540})?utf2bibtex($self->{normset}->{T0540}[0]{content},$utf8):'';

    # ISSN
    my $issn      = (exists $self->{normset}->{T0543})?utf2bibtex($self->{normset}->{T0543}[0]{content},$utf8):'';

    # Sprache
    my $language  = (exists $self->{normset}->{T0516})?utf2bibtex($self->{normset}->{T0516}[0]{content},$utf8):'';

    # Abstract
    my $abstract  = (exists $self->{normset}->{T0750})?utf2bibtex($self->{normset}->{T0750}[0]{content},$utf8):'';

    # Origin
    my $origin    = (exists $self->{normset}->{T0590})?utf2bibtex($self->{normset}->{T0590}[0]{content},$utf8):'';

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
    $string=~s/ß/{\\"s}/g;

    return $string;
}

sub to_rawdata {
    my ($self) = @_;

    if (exists $self->{brief_normset}){
        return $self->{brief_normset};
    }
    else {
        return ($self->{normset},$self->{mexset},$self->{circset});
    }
}

sub DESTROY {
    my $self = shift;
    $self->{dbh}->disconnect();

    return;
}

1;
