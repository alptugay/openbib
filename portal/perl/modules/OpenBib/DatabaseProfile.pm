####################################################################
#
#  OpenBib::DatabaseProfile
#
#  Dieses File ist (C) 2005 Oliver Flimm <flimm@openbib.org>
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

package OpenBib::DatabaseProfile;

use strict;
use warnings;
no warnings 'redefine';
use utf8;

use Apache::Constants qw(:common);
use Apache::Request ();
use DBI;
use Encode 'decode_utf8';
use Log::Log4perl qw(get_logger :levels);
use Template;

use OpenBib::Common::Util;
use OpenBib::Config;

# Importieren der Konfigurationsdaten als Globale Variablen
# in diesem Namespace

use vars qw(%config);

*config=\%OpenBib::Config::config;

sub handler {
    my $r=shift;

    # Log4perl logger erzeugen
    my $logger = get_logger();

    my $query=Apache::Request->new($r);

    my $status=$query->parse;

    if ($status) {
        $logger->error("Cannot parse Arguments - ".$query->notes("error-notes"));
    }
  
    my $stylesheet=OpenBib::Common::Util::get_css_by_browsertype($r);
  
    # CGI-Uebergabe
    my $sessionID  = ($query->param('sessionID'))?$query->param('sessionID'):'';
    my @databases  = ($query->param('database'))?$query->param('database'):();
    my $action     = ($query->param('action'))?$query->param('action'):'';
    my $newprofile = $query->param('newprofile') || '';
    my $profilid   = $query->param('profilid')   || '';

    my %checkeddb;
  
    #####################################################################
    # Verbindung zur SQL-Datenbank herstellen
  
    my $sessiondbh
        = DBI->connect("DBI:$config{dbimodule}:dbname=$config{sessiondbname};host=$config{sessiondbhost};port=$config{sessiondbport}", $config{sessiondbuser}, $config{sessiondbpasswd})
            or $logger->error_die($DBI::errstr);
  
    my $userdbh
        = DBI->connect("DBI:$config{dbimodule}:dbname=$config{userdbname};host=$config{userdbhost};port=$config{userdbport}", $config{userdbuser}, $config{userdbpasswd})
            or $logger->error_die($DBI::errstr);
  
    unless (OpenBib::Common::Util::session_is_valid($sessiondbh,$sessionID)){
        OpenBib::Common::Util::print_warning("Ungültige Session",$r);
        $sessiondbh->disconnect();
        $userdbh->disconnect();
        return OK;
    }

    my $view="";

    if ($query->param('view')) {
        $view=$query->param('view');
    }
    else {
        $view=OpenBib::Common::Util::get_viewname_of_session($sessiondbh,$sessionID);
    }

    # Authorisierte Session?
    my $userid=OpenBib::Common::Util::get_userid_of_session($userdbh,$sessionID);
  
    unless($userid){
        OpenBib::Common::Util::print_warning("Sie haben sich nicht authentifiziert.",$r);
        $sessiondbh->disconnect();
        $userdbh->disconnect();
        return OK;
    }

    my $idnresult="";

    #####################################################################   
    # Anzeigen der Profilmanagement-Seite
    #####################################################################   

    if ($action eq "show" || $action eq "Profil anzeigen") {
        my $profilname="";
    
        if ($profilid) {
      
            # Zuerst Profil-Description zur ID holen
            $idnresult=$userdbh->prepare("select profilename from userdbprofile where profilid = ?") or $logger->error($DBI::errstr);
            $idnresult->execute($profilid) or $logger->error($DBI::errstr);
      
            my $result=$idnresult->fetchrow_hashref();
      
            $profilname = decode_utf8($result->{'profilename'});
      
            $idnresult=$userdbh->prepare("select dbname from profildb where profilid = ?") or $logger->error($DBI::errstr);
            $idnresult->execute($profilid) or $logger->error($DBI::errstr);
            while (my $result=$idnresult->fetchrow_hashref()) {
                my $dbname = decode_utf8($result->{'dbname'});
                $checkeddb{$dbname}="checked";
            }
            $idnresult->finish();
        }
    
        my @userdbprofiles=();

        {
            my $profilresult=$userdbh->prepare("select profilid, profilename from userdbprofile where userid = ? order by profilename") or $logger->error($DBI::errstr);
            $profilresult->execute($userid) or $logger->error($DBI::errstr);
            while (my $res=$profilresult->fetchrow_hashref()) {
                push @userdbprofiles, {
                    profilid    => decode_utf8($res->{'profilid'}),
                    profilename => decode_utf8($res->{'profilename'}),
                };
            } 
            $profilresult->finish();
        }

        my $targettype=OpenBib::Common::Util::get_targettype_of_session($userdbh,$sessionID);

        $idnresult=$sessiondbh->prepare("select dbname from dbchoice where sessionid = ?") or $logger->error($DBI::errstr);
        $idnresult->execute($sessionID) or $logger->error($DBI::errstr);
        while (my $result=$idnresult->fetchrow_hashref()) {
            my $dbname = decode_utf8($result->{'dbname'});
            $checkeddb{$dbname}="checked=\"checked\"";
        }
        $idnresult->finish();
    
        my $lastcategory="";
        my $count=0;
    
        my $maxcolumn=$config{databasechoice_maxcolumn};
    
        $idnresult=$sessiondbh->prepare("select * from dbinfo where active=1 order by orgunit ASC, description ASC") or $logger->error($DBI::errstr);
        $idnresult->execute() or $logger->error($DBI::errstr);
    
        my @catdb=();
    
        while (my $result=$idnresult->fetchrow_hashref) {
            my $category   = decode_utf8($result->{'orgunit'});
            my $name       = decode_utf8($result->{'description'});
            my $systemtype = decode_utf8($result->{'system'});
            my $pool       = decode_utf8($result->{'dbname'});
            my $url        = decode_utf8($result->{'url'});
            my $sigel      = decode_utf8($result->{'sigel'});
      
            my $rcolumn;
      
            if ($category ne $lastcategory) {
                while ($count % $maxcolumn != 0) {
                    $rcolumn=($count % $maxcolumn)+1;

                    # 'Leereintrag erzeugen'
                    push @catdb, {
			column     => $rcolumn,
			category   => $lastcategory,
			db         => '',
			name       => '',
			systemtype => '',
			sigel      => '',
			url        => '',
                    };
                    $count++;
                }
	
                $count=0;
            }

            $lastcategory=$category;
      
            $rcolumn=($count % $maxcolumn)+1;
      
            my $checked="";
            if (defined $checkeddb{$pool}) {
                $checked="checked=\"checked\"";
            }
      
            push @catdb, { 
                column     => $rcolumn,
                category   => $category,
                db         => $pool,
                name       => $name,
                systemtype => $systemtype,
                sigel      => $sigel,
                url        => $url,
                checked    => $checked,
            };
            $count++;
        }

        # TT-Data erzeugen
        my $colspan=$maxcolumn*3;
    
        my $ttdata={
            view           => $view,
            stylesheet     => $stylesheet,
            sessionID      => $sessionID,
            targettype     => $targettype,
            profilname     => $profilname,
            userdbprofiles => \@userdbprofiles,
            maxcolumn      => $maxcolumn,
            colspan        => $colspan,
            catdb          => \@catdb,
            show_foot_banner      => 1,
            show_corporate_banner => 0,
            show_testsystem_info  => 0,
            config         => \%config,
        };
    
        OpenBib::Common::Util::print_page($config{tt_databaseprofile_tname},$ttdata,$r);
        return OK;
    }

    #####################################################################   
    # Abspeichern eines Profils
    #####################################################################   

    elsif ($action eq "Profil speichern") {
    
        # Wurde ueberhaupt ein Profilname eingegeben?
        if (!$newprofile) {
            OpenBib::Common::Util::print_warning("Sie haben keinen Profilnamen eingegeben!",$r);
            return OK;
        }

        my $profilresult=$userdbh->prepare("select profilid,count(profilid) as rowcount from userdbprofile where userid = ? and profilename = ?") or $logger->error($DBI::errstr);
        $profilresult->execute($userid,$newprofile) or $logger->error($DBI::errstr);
        my $res=$profilresult->fetchrow_hashref();
        
        my $numrows=$res->{rowcount};
    
        my $profilid="";

        if ($numrows > 0){
            $profilid = decode_utf8($res->{'profilid'});
        }
        # Wenn noch keine Profilid (=kein Profil diesen Namens)
        # existiert, dann wird eins erzeugt.
        else {
            my $profilresult2=$userdbh->prepare("insert into userdbprofile values (NULL,?,?)") or $logger->error($DBI::errstr);
      
            $profilresult2->execute($newprofile,$userid) or $logger->error($DBI::errstr);
            $profilresult2=$userdbh->prepare("select profilid from userdbprofile where userid = ? and profilename = ?") or $logger->error($DBI::errstr);
      
            $profilresult2->execute($userid,$newprofile) or $logger->error($DBI::errstr);
            my $res=$profilresult2->fetchrow_hashref();
            $profilid = decode_utf8($res->{'profilid'});
      
            $profilresult2->finish();
        }
    
        # Jetzt habe ich eine profilid und kann Eintragen
        # Auswahl wird immer durch aktuelle ueberschrieben.
        # Daher erst potentiell loeschen
        $profilresult=$userdbh->prepare("delete from profildb where profilid = ?") or $logger->error($DBI::errstr);
        $profilresult->execute($profilid) or $logger->error($DBI::errstr);
    
        foreach my $database (@databases) {
            # ... und dann eintragen
      
            my $profilresult=$userdbh->prepare("insert into profildb (profilid,dbname) values (?,?)") or $logger->error($DBI::errstr);
            $profilresult->execute($profilid,$database) or $logger->error($DBI::errstr);
            $profilresult->finish();
        }
        $r->internal_redirect("http://$config{servername}$config{databaseprofile_loc}?sessionID=$sessionID&action=show");
    }
    # Loeschen eines Profils
    elsif ($action eq "Profil löschen") {
        my $profilresult=$userdbh->prepare("delete from userdbprofile where userid = ? and profilid = ?") or $logger->error($DBI::errstr);
        $profilresult->execute($userid,$profilid) or $logger->error($DBI::errstr);
    
        $profilresult=$userdbh->prepare("delete from profildb where profilid = ?") or $logger->error($DBI::errstr);
        $profilresult->execute($profilid) or $logger->error($DBI::errstr);
    
        $profilresult->finish();

        $r->internal_redirect("http://$config{servername}$config{databaseprofile_loc}?sessionID=$sessionID&action=show");
    }
    # ... andere Aktionen sind nicht erlaubt
    else {
        OpenBib::Common::Util::print_warning("Keine gültige Aktion",$r);
    }

    $sessiondbh->disconnect();
    $userdbh->disconnect();
  
    return OK;
}

1;
