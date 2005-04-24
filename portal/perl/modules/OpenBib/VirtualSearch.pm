####################################################################
#
#  OpenBib::VirtualSearch.pm
#
#  Dieses File ist (C) 1997-2004 Oliver Flimm <flimm@openbib.org>
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

package OpenBib::VirtualSearch;

use Apache::Constants qw(:common);

use strict;
use warnings;

use Apache::Request();      # CGI-Handling (or require)

use Log::Log4perl qw(get_logger :levels);

use LWP::UserAgent;
use HTTP::Request;
use HTTP::Response;

use POSIX;

use Digest::MD5;
use DBI;
use Email::Valid;                           # EMail-Adressen testen

use OpenBib::VirtualSearch::Util;

use OpenBib::Common::Util;
use OpenBib::Common::Stopwords;

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
  
  my $stylesheet=OpenBib::Common::Util::get_css_by_browsertype($r);
  
  #####################################################################
  # Verbindung zur SQL-Datenbank herstellen
  
  my $sessiondbh=DBI->connect("DBI:$config{dbimodule}:dbname=$config{sessiondbname};host=$config{sessiondbhost};port=$config{sessiondbport}", $config{sessiondbuser}, $config{sessiondbpasswd}) or $logger->error_die($DBI::errstr);
  
  my $userdbh=DBI->connect("DBI:$config{dbimodule}:dbname=$config{userdbname};host=$config{userdbhost};port=$config{userdbport}", $config{userdbuser}, $config{userdbpasswd}) or $logger->error_die($DBI::errstr);
  
  # Standardwerte festlegen
  
  my $befehlsurl="http://$config{servername}$config{search_loc}";
  
  my $searchmode=2;
  my $searchall=1;
  my $search="Suche";
  my $dbmode=1;
  
  # CGI-Input auslesen
  
  my $fs=$query->param('fs') || '';
  my $verf=$query->param('verf') || '';
  my $hst=$query->param('hst') || '';
  my $hststring=$query->param('hststring') || '';
  my $swt=$query->param('swt') || '';
  my $kor=$query->param('kor') || '';
  my $sign=$query->param('sign') || '';
  my $isbn=$query->param('isbn') || '';
  my $issn=$query->param('issn') || '';
  my $mart=$query->param('mart') || '';
  my $notation=$query->param('notation') || '';
  my $ejahr=$query->param('ejahr') || '';
  my $ejahrop=$query->param('ejahrop') || '';
  my $verknuepfung=$query->param('verknuepfung') || '';
  my $bool1=$query->param('bool1') || '';
  my $bool2=$query->param('bool2') || '';
  my $bool3=$query->param('bool3') || '';
  my $bool4=$query->param('bool4') || '';
  my $bool5=$query->param('bool5') || '';
  my $bool6=$query->param('bool6') || '';
  my $bool7=$query->param('bool7') || '';
  my $bool8=$query->param('bool8') || '';
  my $bool9=$query->param('bool9') || '';
  my $bool10=$query->param('bool10') || '';
  my $bool11=$query->param('bool11') || '';
  my $bool12=$query->param('bool12') || '';
  my @databases=($query->param('database'))?$query->param('database'):();
  my $starthit=($query->param('starthit'))?$query->param('starthit'):1;
  my $hitrange=($query->param('hitrange'))?$query->param('hitrange'):20;
  my $maxhits=($query->param('maxhits'))?$query->param('maxhits'):500;
  my $sorttype=($query->param('sorttype'))?$query->param('sorttype'):"author";
  my $sortall=($query->param('sortall'))?$query->param('sortall'):'0';
  my $sortorder=($query->param('sortorder'))?$query->param('sortorder'):'up';
  my $tosearch=$query->param('tosearch') || '';
  my $swtindexall=$query->param('swtindexall') || '';
  my $profil=$query->param('profil') || '';
  my $trefferliste=$query->param('trefferliste') || '';
  my $autoplus=$query->param('autoplus') || '';
  my $queryid=$query->param('queryid') || '';
  my $view=$query->param('view') || '';
  
  # Filter: ISBN und ISSN
  
  # Entfernung der Minus-Zeichen bei der ISBN
  $fs=~s/(\d)-*(\d)-*(\d)-*(\d)-*(\d)-*(\d)-*(\d)-*(\d)-*(\d)-*(\S)/$1$2$3$4$5$6$7$8$9$10/g;
  $isbn=~s/(\d)-*(\d)-*(\d)-*(\d)-*(\d)-*(\d)-*(\d)-*(\d)-*(\d)-*(\S)/$1$2$3$4$5$6$7$8$9$10/g;
  
  # Entfernung der Minus-Zeichen bei der ISSN
  $fs=~s/(\d)-*(\d)-*(\d)-*(\d)-*(\d)-*(\d)-*(\d)-*(\d)/$1$2$3$4$5$6$7$8/g;
  $issn=~s/(\d)-*(\d)-*(\d)-*(\d)-*(\d)-*(\d)-*(\d)-*(\d)/$1$2$3$4$5$6$7$8/g;
  
  $fs=OpenBib::VirtualSearch::Util::cleansearchterm($fs);
  
  # Filter Rest
  
  $verf=OpenBib::VirtualSearch::Util::cleansearchterm($verf);
  $hst=OpenBib::VirtualSearch::Util::cleansearchterm($hst);
  $hststring=OpenBib::VirtualSearch::Util::cleansearchterm($hststring);

  # Bei hststring zusaetzlich normieren durch Weglassung des ersten
  # Stopwortes

  $hststring=OpenBib::Common::Stopwords::strip_first_stopword($hststring);

  $swt=OpenBib::VirtualSearch::Util::cleansearchterm($swt);
  $kor=OpenBib::VirtualSearch::Util::cleansearchterm($kor);
  $sign=OpenBib::VirtualSearch::Util::cleansearchterm($sign);
  $isbn=OpenBib::VirtualSearch::Util::cleansearchterm($isbn);
  $issn=OpenBib::VirtualSearch::Util::cleansearchterm($issn);
  $mart=OpenBib::VirtualSearch::Util::cleansearchterm($mart);
  $notation=OpenBib::VirtualSearch::Util::cleansearchterm($notation);
  $ejahr=OpenBib::VirtualSearch::Util::cleansearchterm($ejahr);
  $ejahrop=OpenBib::VirtualSearch::Util::cleansearchterm($ejahrop);
  
  
  # Umwandlung impliziter ODER-Verknuepfung in UND-Verknuepfung
  
  if ($autoplus eq "1"){
    
    $fs=OpenBib::VirtualSearch::Util::conv2autoplus($fs) if ($fs);
    $verf=OpenBib::VirtualSearch::Util::conv2autoplus($verf) if ($verf);
    $hst=OpenBib::VirtualSearch::Util::conv2autoplus($hst) if ($hst);
    $kor=OpenBib::VirtualSearch::Util::conv2autoplus($kor) if ($kor);
    $swt=OpenBib::VirtualSearch::Util::conv2autoplus($swt) if ($swt);
    $isbn=OpenBib::VirtualSearch::Util::conv2autoplus($isbn) if ($isbn);
    $issn=OpenBib::VirtualSearch::Util::conv2autoplus($issn) if ($issn);
    
  }
  
  if ($hitrange eq "alles"){
    $hitrange=-1;
  }

  # Verweis: Datenbankname -> Informationen zum zugeh"origen Institut/Seminar
  
  my $dbinforesult=$sessiondbh->prepare("select dbname,url,description from dbinfo") or $logger->error($DBI::errstr);
  $dbinforesult->execute() or $logger->error($DBI::errstr);
  
  my %dbases=();
  my %dbnames=();
  
  while (my $result=$dbinforesult->fetchrow_hashref()){
    my $dbname=$result->{'dbname'};
    my $url=$result->{'url'};
    my $description=$result->{'description'};
    
    # Wenn ein URL fuer die Datenbankinformation definiert ist, dann wird
    # damit verlinkt
    
    if ($url ne ""){
      $dbases{"$dbname"}="<a href=\"$url\" target=_blank>$description</a>";
    }
    else {
      $dbases{"$dbname"}="$description";
    }
    $dbnames{"$dbname"}=$description;
  }
  
  $dbinforesult->finish();
  
  my %fakultaeten=(
		   '0ungeb' => '1',
		   '1wiso' => '1',
		   '2recht' => '1',
		   '3ezwheil' => '1',
		   '4phil' => '1',
		   '5matnat' => '1'
		  );
  
  $profil="" if ((!defined $fakultaeten{$profil}) && $profil ne "dbauswahl" && !$profil=~/^user/);
  
  my $sessionID=($query->param('sessionID'))?$query->param('sessionID'):'';
  
  unless (OpenBib::Common::Util::session_is_valid($sessiondbh,$sessionID)){
    OpenBib::Common::Util::print_warning("Ung&uuml;ltige Session",$r);
    goto LEAVEPROG;
  }
  
  # Authorisierter user?
  
  my $userid=OpenBib::Common::Util::get_userid_of_session($userdbh,$sessionID);

  $logger->info("Authorization: ", $sessionID, " ", ($userid)?$userid:'none');
  
  # BEGIN Trefferliste
  #
  ####################################################################
  # Wenn die Trefferlistenfunktion ausgewaehlt wurde, dann ...
  ####################################################################
  
  if ($trefferliste){
    my $idnresult=$sessiondbh->prepare("select sessionid from searchresults where sessionid = ?") or $logger->error($DBI::errstr);
    $idnresult->execute($sessionID) or $logger->error($DBI::errstr);
    
    if ($idnresult->rows <= 0){
      OpenBib::Common::Util::print_warning("Derzeit existiert (noch) keine Trefferliste",$r);
      $idnresult->finish();
      goto LEAVEPROG;
    }
    
    ####################################################################
    # ... falls die Auswahlseite angezeigt werden soll
    ####################################################################
    
    if ($trefferliste eq "choice"){
      
      my @queryids=();
      my @querystrings=();
      my @queryhits=();
      
      $idnresult=$sessiondbh->prepare("select distinct searchresults.queryid,queries.query,queries.hits from searchresults,queries where searchresults.sessionid = ? and searchresults.queryid=queries.queryid order by queryid desc") or $logger->error($DBI::errstr);
      $idnresult->execute($sessionID) or $logger->error($DBI::errstr);
      
      while (my @res=$idnresult->fetchrow){
	push @queryids, $res[0];
	push @querystrings, $res[1];
	push @queryhits, $res[2];
      }
      
      my $thisqueryid="";
      my $thisqueryidx=0;
      
      if ($queryid eq ""){
	$thisqueryid=$queryids[0];
      }
      else{
	my $i=0;
	while ($i <= $#queryids){
	  if ($queryids[$i] eq "$queryid"){
	    $thisqueryidx=$i;
	  }
	  $i++
	}	
	$thisqueryid=$queryid;
      }
      
      ($fs,$verf,$hst,$swt,$kor,$sign,$isbn,$issn,$notation,$mart,$ejahr,$hststring,$bool1,$bool2,$bool3,$bool4,$bool5,$bool6,$bool7,$bool8,$bool9,$bool10,$bool11,$bool12)=split('\|\|',$querystrings[$thisqueryidx]);
      
      $idnresult=$sessiondbh->prepare("select dbname,hits from searchresults where sessionid = ? and queryid = ? order by hits desc") or $logger->error($DBI::errstr);
      $idnresult->execute($sessionID,$thisqueryid) or $logger->error($DBI::errstr);
      
      # Header mit allen Elementen ausgeben
      
      OpenBib::Common::Util::print_simple_header("Such-Client des Virtuellen Katalogs",$r);
      
      print << "HEADER";
<FORM METHOD="GET">

<ul id="tabbingmenu">
   <li><a class="active" href="$config{virtualsearch_loc}?sessionID=$sessionID;trefferliste=choice;view=$view">Trefferliste</a></li>
</ul>

<div id="content">

<p>
HEADER
      
      #      print "<h1>Direkt aus dem Cache</h1>";
      
      print "<table width=\"100%\"><tr>";
      
      #    print "Lastqueryid: $lastqueryid<p>";
      if ($queryid eq ""){
	print "<th>Aktuelle Recherche</th>";
      }   
      else {
	print "<th>Ausgew&auml;hlte Recherche</th>";
      }
      
      print "</tr><td class=\"boxedclear\"><table><tr><td colspan=\"2\">";
      
      print "(";
      print "&nbsp;FS: $fs " if ($fs);
      print "&nbsp;AUT: $verf " if ($verf);
      print "&nbsp;HST: $hst " if ($hst);
      print "&nbsp;SWT: $swt " if ($swt);
      print "&nbsp;KOR: $kor " if ($kor);
      print "&nbsp;NOT: $notation " if ($notation);
      print "&nbsp;SIG: $sign " if ($sign);
      print "&nbsp;EJAHR: $ejahr " if ($ejahr);
      print "&nbsp;ISBN: $isbn " if ($isbn);
      print "&nbsp;ISSN: $issn " if ($issn);
      print "&nbsp;MART: $mart " if ($mart);
      print "&nbsp;HSTR: $hststring " if ($hststring);
      
      #    print "= Treffer: $hits" if ($hits);
      print ")</td></tr><tr><td colspan=\"2\"></td></tr>";
      
      
      my $linecolor="aliceblue";
      my $hitcount=0;
      
      my $resultrow="";
      while (my @res=$idnresult->fetchrow){
	
	$resultrow.="<tr><td bgcolor=\"$linecolor\"><a href=\"$config{virtualsearch_loc}?sessionID=$sessionID&trefferliste=$res[0]&queryid=$thisqueryid\"><b>$dbnames{$res[0]}</b></a></td><td align=right>$res[1]</td></tr>\n";
	
	if ($linecolor eq "white"){
	  $linecolor="aliceblue";
	}
	else {
	  $linecolor="white";
	}
	$hitcount+=$res[1];
      }
      
      
      print "<tr><td>Katalog</td><td>Treffer</td></tr>\n";
      
      print "<tr><td bgcolor=\"aliceblue\"><a href=\"$config{virtualsearch_loc}?sessionID=$sessionID&trefferliste=all&sortall=0&sorttype=author&queryid=$thisqueryid\"><b>Alle Treffer</b></a></td><td align=right>$hitcount</td></tr>\n";
      
      print "<tr><td bgcolor=\"white\">&nbsp;</td><td align=right>&nbsp;</td></tr>\n";
      
      print $resultrow;
      
      print "</table></td></tr></table>\n";
      
      $idnresult->finish();
      
      
      if ($queryid eq ""){

	# Weitere Trefferlisten zu alten Recherchen vorhanden?
	
	if ($#queryids > 0){
	  
	  
	  print "<form method=\"get\" action=\"$config{virtualsearch_loc}\">";
	  print "<input type=\"hidden\" name=\"sessionID\" value=\"$sessionID\">";
	  print "<input type=\"hidden\" name=\"trefferliste\" value=\"choice\">";
	  
	  print "<p><table width=\"100%\"><tr>";
	  print "<th>&Auml;ltere Recherchen</th></tr><tr><td class=\"boxedclear\">";
	  
	  print "<select name=\"queryid\">";
	  
	  my $i=1;
	  
	  while ($i <= $#queryids){
	    
	    my ($fs,$verf,$hst,$swt,$kor,$sign,$isbn,$issn,$notation,$mart,$ejahr,$hststring,$bool1,$bool2,$bool3,$bool4,$bool5,$bool6,$bool7,$bool8,$bool9,$bool10,$bool11,$bool12)=split('\|\|',$querystrings[$i]);
	    
	    print "<OPTION value=\"".$queryids[$i]."\">";
	    print "(";
	    print "&nbsp;FS: $fs " if ($fs);
	    print "&nbsp;AUT: $verf " if ($verf);
	    print "&nbsp;HST: $hst " if ($hst);
	    print "&nbsp;SWT: $swt " if ($swt);
	    print "&nbsp;KOR: $kor " if ($kor);
	    print "&nbsp;NOT: $notation " if ($notation);
	    print "&nbsp;SIG: $sign " if ($sign);
	    print "&nbsp;EJAHR: $ejahr " if ($ejahr);
	    print "&nbsp;ISBN: $isbn " if ($isbn);
	    print "&nbsp;ISSN: $issn " if ($issn);
	    print "&nbsp;MART: $mart " if ($mart);
	    print "&nbsp;HSTR: $hststring " if ($hststring);
	    print "= Treffer: $queryhits[$i])" if ($queryhits[$i]);
	    print "</OPTION>\n";
	    
	    $i++;
	  }
	  print "</select>\n";
	  print "<input type=submit value=\"Auswahl\"></td></tr></table></form>";
	}
      }
      print "</table></div><p />";
      OpenBib::Common::Util::print_footer();
      
      goto LEAVEPROG;
      
    }
    
    ####################################################################
    # ... falls alle Treffer zu einer queryid angezeigt werden sollen
    ####################################################################
    
    elsif ($trefferliste eq "all"){
      
      # Erst am Ende der Anfangsrecherche wird die queryid erzeugt. Damit ist
      # sie noch nicht vorhanden, wenn am Anfang der Seite die Sortierungs-
      # funktionalitaet bereitgestellt wird. Wenn dann ohne queryid
      # die Trefferliste sortiert werden soll, dann muss zuerst die 
      # queryid bestimmt werden. Die betreffende ist die letzte zur aktuellen
      # sessionid
      
      if ($queryid eq ""){
	
	$idnresult=$sessiondbh->prepare("select max(queryid) from queries where sessionid = ?") or $logger->error($DBI::errstr);
	$idnresult->execute($sessionID) or $logger->error($DBI::errstr);
	
	my @res=$idnresult->fetchrow;
	$queryid=$res[0];
      }
      
      
      $idnresult=$sessiondbh->prepare("select searchresults.searchresult from searchresults, dbinfo where searchresults.dbname=dbinfo.dbname and sessionid = ? and queryid = ? order by dbinfo.faculty,searchresults.dbname") or $logger->error($DBI::errstr);
      $idnresult->execute($sessionID,$queryid) or $logger->error($DBI::errstr);
      
      # Header mit allen Elementen ausgeben
      
      OpenBib::Common::Util::print_simple_header("Such-Client des Virtuellen Katalogs",$r);
      
      print << "HEADER";

<ul id="tabbingmenu">
   <li><a class="active" href="$config{virtualsearch_loc}?sessionID=$sessionID;trefferliste=choice;view=$view">Trefferliste</a></li>
</ul>

<div id="content">

<FORM METHOD="GET">
<p>
HEADER
      
      OpenBib::Common::Util::print_sort_nav($r,'sortboth',1);      
      
      
      #print "<h1>Direkt aus dem Cache</h1>";
      print "<table>";
      
      #open(RES,">/tmp/res.dat");
      
      my @resultset=();
      
      if ($sortall == 1){
	
	my $idx=0;
	my @outputbuffer=();
	while (my @res=$idnresult->fetchrow){
	  my @splitresult=split("\n",$res[0]);
	  my $j=0;
	  
	  my $institut="";
	  
	  while ($j <= $#splitresult){
	    my $thisline=$splitresult[$j];
	    
	    if ($thisline =~/<tr bgcolor="lightblue"><td>&nbsp;<\/td><td>(<a.+?>.+?<\/a>)<\/td>/){
	      $institut=$1;
	    }
	    elsif ($thisline =~/<tr bgcolor="lightblue"><td>&nbsp;<\/td><td>(.+?)<\/td>/){
	      $institut=$1;
	    }
	    elsif ($thisline =~/<tr bgcolor="white"><td bgcolor="lightblue"><strong>\d+<\/strong><\/td><td colspan=2>(.+<\/td><\/tr>)/){
	      my $line=$1;
	      $outputbuffer[$idx++]="<td bgcolor=\"lightblue\">".$institut."</td><td>".$line; 	  
	      #print RES $outputbuffer[$idx-1];
	    }
	    elsif ($thisline =~/<tr bgcolor="aliceblue"><td bgcolor="lightblue"><strong>\d+<\/strong><\/td><td colspan=2>(.+<\/td><\/tr>)/){
	      my $line=$1;
	      $outputbuffer[$idx++]="<td bgcolor=\"lightblue\">".$institut."</td><td>".$line; 	  
	      #print RES $outputbuffer[$idx-1];
	    }
	    else {
	      #print RES $thisline."\n"; 
	    }
	    
	    $j++;
	  }
	  
	}
	
	my @sortedoutputbuffer=();
	
	OpenBib::Common::Util::sort_buffer($sorttype,$sortorder,\@outputbuffer,\@sortedoutputbuffer);
	
	my $i=0;
	my $bgcolor="white";
	while ($i <= $#sortedoutputbuffer){
	  print "<tr bgcolor=\"$bgcolor\"><td bgcolor=\"lightblue\"><strong>".($i+1)."</strong></td>".$sortedoutputbuffer[$i]."\n";
	  
	  # Eintraege merken fuer Lastresultset
	  
	  my ($katkey)=$sortedoutputbuffer[$i]=~/searchsingletit=(\d+)/;
	  my ($resdatabase)=$sortedoutputbuffer[$i]=~/database=(\w+)/;
	  push @resultset, "$resdatabase:$katkey";
	  
	  $i++;
	  
	  if ($bgcolor eq "white"){
	    $bgcolor="aliceblue";
	  }
	  else {
	    $bgcolor="white";
	  }
	  
	}
	#close(RES);
	
      }
      elsif ($sortall == 0) {
	
	# Katalogoriertierte Sortierung
	
	#      open(RES,">/tmp/res.dat");
	while (my @res=$idnresult->fetchrow){
	  my @splitresult=split("\n",$res[0]);
	  my $j=0;
	  my $idx=0;
	  my @outputbuffer=();
	  while ($j <= $#splitresult){
	    my $thisline=$splitresult[$j];
	    
	    if ($thisline =~/<tr bgcolor="white"><td bgcolor="lightblue"><strong>\d+<\/strong><\/td>(<td colspan=2>.+<\/td><\/tr>)/){
	      my $line=$1;
	      $outputbuffer[$idx++]=$line; 	  
	      #	    print RES $outputbuffer[$idx-1];
	    }
	    elsif ($thisline =~/<tr bgcolor="aliceblue"><td bgcolor="lightblue"><strong>\d+<\/strong><\/td>(<td colspan=2>.+<\/td><\/tr>)/){
	      my $line=$1;
	      $outputbuffer[$idx++]=$line; 	  
	      #	    print RES $outputbuffer[$idx-1];
	    }
	    elsif ($thisline =~/<tr bgcolor="lightblue"><td>&nbsp;/){
	      print $thisline;
	    }
	    else {
	      #	    print RES $thisline."\n"; 
	    }
	    
	    
	    $j++;
	  }
	  
	  # Sortierung
	  
	  my @sortedoutputbuffer=();
	  
	  OpenBib::Common::Util::sort_buffer($sorttype,$sortorder,\@outputbuffer,\@sortedoutputbuffer);
	  
	  my $i=0;
	  my $bgcolor="white";
	  while ($i <= $#sortedoutputbuffer){
	    print "<tr bgcolor=\"$bgcolor\"><td bgcolor=\"lightblue\"><strong>".($i+1)."</strong></td>".$sortedoutputbuffer[$i]."\n";
	    
	    # Eintraege merken fuer Lastresultset
	    
	    my ($katkey)=$sortedoutputbuffer[$i]=~/searchsingletit=(\d+)/;
	    my ($resdatabase)=$sortedoutputbuffer[$i]=~/database=(\w+)/;
	    push @resultset, "$resdatabase:$katkey";
	    
	    
	    $i++;
	    
	    if ($bgcolor eq "white"){
	      $bgcolor="aliceblue";
	    }
	    else {
	      $bgcolor="white";
	    }
	    
	  }
	  
	  print "<tr><td colspan=3>&nbsp;<td></tr>\n";
	  
	}
	
	#      close(RES);
	
      }
      
      OpenBib::Common::Util::updatelastresultset($sessiondbh,$sessionID,\@resultset);
      
      
      $idnresult->finish();
      
      print "</table></div><p>";    
      OpenBib::Common::Util::print_footer();
      
      goto LEAVEPROG;
      
    }
    
    ####################################################################
    # ... falls die Treffer zu einer queryid aus einer Datenbank 
    # angezeigt werden sollen
    ####################################################################
    
    elsif ($dbases{$trefferliste} ne "") {
      
      my @resultset=();
      
      $idnresult=$sessiondbh->prepare("select searchresult from searchresults where sessionid = ? and dbname = ? and queryid = ?") or $logger->error($DBI::errstr);
      $idnresult->execute($sessionID,$trefferliste,$queryid) or $logger->error($DBI::errstr);
      
      # Header mit allen Elementen ausgeben
      
      OpenBib::Common::Util::print_simple_header("Such-Client des Virtuellen Katalogs",$r);
      
      print << "HEADER";
<ul id="tabbingmenu">
   <li><a class="active" href="$config{virtualsearch_loc}?sessionID=$sessionID;trefferliste=choice;view=$view">Trefferliste</a></li>
</ul>

<div id="content">

<FORM METHOD="GET">

<p>
HEADER
      
      OpenBib::Common::Util::print_sort_nav($r,'sortsingle',1);
      
      #  print "<h1>Direkt aus dem Cache</h1>";
      print "<table>";
      
      # Katalogoriertierte Sortierung
      
      while (my @res=$idnresult->fetchrow){
	my @splitresult=split("\n",$res[0]);
	my $j=0;
	my $idx=0;
	my @outputbuffer=();
	while ($j <= $#splitresult){
	  my $thisline=$splitresult[$j];
	  
	  if ($thisline =~/<tr bgcolor="white"><td bgcolor="lightblue"><strong>\d+<\/strong><\/td>(<td colspan=2>.+<\/td><\/tr>)/){
	    my $line=$1;
	    $outputbuffer[$idx++]=$line; 	  
	    #	    print RES $outputbuffer[$idx-1];
	  }
	  elsif ($thisline =~/<tr bgcolor="aliceblue"><td bgcolor="lightblue"><strong>\d+<\/strong><\/td>(<td colspan=2>.+<\/td><\/tr>)/){
	    my $line=$1;
	    $outputbuffer[$idx++]=$line; 	  
	    #	    print RES $outputbuffer[$idx-1];
	  }
	  elsif ($thisline =~/<tr bgcolor="lightblue"><td>&nbsp;/){
	    print $thisline;
	  }
	  else {
	    #	    print RES $thisline."\n"; 
	  }
	  
	  
	  $j++;
	}
	
	# Sortierung
	
	my @sortedoutputbuffer=();
	
	OpenBib::Common::Util::sort_buffer($sorttype,$sortorder,\@outputbuffer,\@sortedoutputbuffer);
	
	my $i=0;
	my $bgcolor="white";
	while ($i <= $#sortedoutputbuffer){
	  print "<tr bgcolor=\"$bgcolor\"><td bgcolor=\"lightblue\"><strong>".($i+1)."</strong></td>".$sortedoutputbuffer[$i]."\n";
	  
	  # Eintraege merken fuer Lastresultset
	  
	  my ($katkey)=$sortedoutputbuffer[$i]=~/searchsingletit=(\d+)/;
	  my ($resdatabase)=$sortedoutputbuffer[$i]=~/database=(\w+)/;
	  push @resultset, "$resdatabase:$katkey";
	  
	  $i++;
	  if ($bgcolor eq "white"){
	    $bgcolor="aliceblue";
	  }
	  else {
	    $bgcolor="white";
	  }
	  
	}
	
	print "<tr><td colspan=3>&nbsp;<td></tr>\n";
	
      }
      
      #    while (my @res=$idnresult->fetchrow){
      #      print $res[0]; 
      #    }
      
      OpenBib::Common::Util::updatelastresultset($sessiondbh,$sessionID,\@resultset);
      
      $idnresult->finish();
      
      print "</table></div><p>";    
      OpenBib::Common::Util::print_footer();
      
      goto LEAVEPROG;
    }
    
  }
  
  ####################################################################
  # ENDE Trefferliste
  #

  # BEGIN Schlagworte
  # (derzeit nicht unterstuetzt)
  ####################################################################
  # Wenn ein kataloguebergreifender Schlagwortindex ausgewaehlt wurde
  ####################################################################
  
  my $ua=new LWP::UserAgent;
  my $item;
  my $alldbs;
  
  if ($swtindexall){
    if ($#databases < 0){
      OpenBib::Common::Util::print_warning("Es wurden keine <a href=\"$config{databasechoice_loc}?sessionID=$sessionID\" target=\"body\">einzelnen Kataloge</a> ausgew&auml;hlt. Aufgrund der hohen Zahl der Schlagworte in der Gesamtheit der Kataloge ist die Schlagwortindexfunktion auf einzeln auszuw&auml;hlende Kataloge beschr&auml;nkt. W&auml;hlen Sie bitte die gew&uuml;nschten Kataloge aus und bet&auml;tigen Sie wieder 'Schlagwortindex'",$r);
    }
    else {
      print $r->send_http_header("text/html");
      
      print "<HTML><HEAD>$stylesheet<TITLE>Such-Client des Virtuellen Katalogs</title>";
      
      print "</HEAD><BODY BGCOLOR=\"#ffffff\"><FORM METHOD=\"GET\">\n";
      my $database;
      my @katalog;
      my @ergebnisse;
      my $ergidx;
      
      foreach $database (@databases){
	my $suchstring="swtindexall=Schlagwortindex&fs=$fs&verf=$verf&hst=$hst&hststring=$hststring&swt=$swt&kor=$kor&isbn=$isbn&issn=$issn&mart=$mart&sign=$sign&verknuepfung=$verknuepfung&ejahr=$ejahr&ejahrop=$ejahrop&searchmode=$searchmode&maxhits=$maxhits&hitrange=-1&searchall=$searchall&dbmode=$dbmode&database=$database";
	
	my $request=new HTTP::Request GET => "$befehlsurl?$suchstring";

	$logger->debug("Sending ",$suchstring," to ",$befehlsurl);

	my $response=$ua->request($request);

	if ($response->is_success) {
	  $logger->debug("Getting ", $response->content);
	}
	else {
	  $logger->error("Getting ", $response->status_line);
	}

	$ergebnisse[$ergidx]=$response->content();
	$katalog[$ergidx]=$dbases{"$database"};
	$ergidx++;
      }
      
      print "<table>\n";
      print "<tr><td bgcolor=\"lightblue\">Katalog</td><td bgcolor=\"lightblue\">Schlagwort</td><td bgcolor=\"lightblue\">Titelzahl</td><td bgcolor=\"lightblue\">Schlagwort</td><td bgcolor=\"lightblue\">Titelzahl</td><td bgcolor=\"lightblue\">Schlagwort</td><td bgcolor=\"lightblue\">Titelzahl</td></tr>\n";
      
      my $residx;
      $residx=0;
      while ($residx < $ergidx){
	my $result=$ergebnisse[$residx];
	my $swtnr=OpenBib::VirtualSearch::Util::number_of_swts($result);
	
	# Wenn kein Schlagwort gefunden wurde, dann springe zur n"achsten
	# Ergebnisseite einer anderen Datenbank
	
	if ($swtnr == 0){
	  next;
	}
	else {
	  my @swtlines=OpenBib::VirtualSearch::Util::extract_swtlines($result);
	  my $swt;
	  foreach $swt (@swtlines){
	    #	    print $tit."\n";
	    print "<tr><td bgcolor=lightblue>".$katalog[$residx]."</td>$swt</tr>\n";
	  } 
	}
	if ($residx < $ergidx-1){
	  print "<tr><td bgcolor=yellow>&nbsp;</td><td bgcolor=yellow>&nbsp;</td><td bgcolor=yellow>&nbsp;</td><td bgcolor=yellow>&nbsp;</td><td bgcolor=yellow>&nbsp;</td><td bgcolor=yellow>&nbsp;</td><td bgcolor=yellow>&nbsp;</td></tr>\n";
	}
	$residx++;
      }
      print "</table>\n";
    }  
    goto LEAVEPROG;
  }

  ####################################################################
  # ENDE Schlagworte
  #


  # Ueber view koennen bei Direkteinsprung in VirtualSearch die
  # entsprechenden Kataloge vorausgewaehlt werden

  if ($view && $#databases == -1){
    my $idnresult=$sessiondbh->prepare("select dbname from viewdbs where viewname = ?") or $logger->error($DBI::errstr);
    $idnresult->execute($view) or $logger->error($DBI::errstr);
    
    @databases=();
    my @idnres;
    while (@idnres=$idnresult->fetchrow){	    
      push @databases, $idnres[0];
    }
    $idnresult->finish();

  }

  if ($tosearch eq "In allen Katalogen suchen"){
    
    my $idnresult=$sessiondbh->prepare("select dbname,description from dbinfo where active=1 order by faculty,description") or $logger->error($DBI::errstr);
    $idnresult->execute() or $logger->error($DBI::errstr);
    
    @databases=();
    my @idnres;
    while (@idnres=$idnresult->fetchrow){	    
      push @databases, $idnres[0];
    }
    $idnresult->finish();
    
  }
  elsif (($tosearch eq "In ausgewählten Katalogen suchen")&&(($#databases == -1) && ($profil eq ""))){
    OpenBib::Common::Util::print_warning("Sie haben \"In ausgew&auml;hlten Katalogen suchen\" angeklickt, obwohl sie keine <a href=\"$config{databasechoice_loc}?sessionID=$sessionID\" target=\"body\">Kataloge</a> oder Suchprofile ausgew&auml;hlt haben. Bitte w&auml;hlen Sie die gew&uuml;nschten Kataloge/Suchprofile aus oder bet&auml;tigen Sie \"In allen Katalogen suchen\".",$r);
    goto LEAVEPROG;
  }
  
  if ($profil ne "" && $profil ne "dbauswahl"){
    @databases=();
    
    if ($profil=~/^user(\d+)/){
      my $profilid=$1;
      
      my $profilresult=$userdbh->prepare("select profildb.dbname from profildb,userdbprofile where userdbprofile.userid = ? and userdbprofile.profilid = ? and userdbprofile.profilid=profildb.profilid order by dbname") or $logger->error($DBI::errstr);
      $profilresult->execute($userid,$profilid) or $logger->error($DBI::errstr);
      
      my @poolres;
      while (@poolres=$profilresult->fetchrow){	    
	push @databases, $poolres[0];
      }
      $profilresult->finish();
      
    }
    else {
      my $idnresult=$sessiondbh->prepare("select dbname from dbinfo where active=1 and faculty = ? order by faculty,dbname") or $logger->error($DBI::errstr);
      $idnresult->execute($profil) or $logger->error($DBI::errstr);
      
      my @idnres;
      while (@idnres=$idnresult->fetchrow){	    
	push @databases, $idnres[0];
      }
      $idnresult->finish();
    }
  }
  
  # Wenn Profil aufgerufen wurde, dann abspeichern fuer Recherchemaske

  if ($profil){
      my $idnresult=$sessiondbh->prepare("delete from sessionprofile where sessionid = ? ") or $logger->error($DBI::errstr);
      $idnresult->execute($sessionID) or $logger->error($DBI::errstr);

      $idnresult=$sessiondbh->prepare("insert into sessionprofile values (?,?) ") or $logger->error($DBI::errstr);
      $idnresult->execute($sessionID,$profil) or $logger->error($DBI::errstr);
    
      $idnresult->finish();
  }

  # Folgende nicht erlaubte Anfragen werden sofort ausgesondert 
  
  my $firstsql;
  if ($fs){
    $firstsql=1;
  }
  if ($verf){
    $firstsql=1;
  }
  if ($kor){
    $firstsql=1;
  }
  if ($hst){
    $firstsql=1;
  }
  if ($swt){
    $firstsql=1;
  }
  if ($notation){
    $firstsql=1;
  }
  
  if ($sign){
    $firstsql=1;
  }
  
  if ($isbn){
    $firstsql=1;
  }
  
  if ($issn){
    $firstsql=1;
  }
  
  if ($mart){
    $firstsql=1;
  }

  if ($hststring){
    $firstsql=1;
  }
  
  if ($ejahr){
    my ($ejtest)=$ejahr=~/.*(\d\d\d\d).*/;
    if (!$ejtest){
      OpenBib::Common::Util::print_warning("Bitte geben Sie als Erscheinungsjahr eine vierstellige Zahl ein.",$r);
      goto LEAVEPROG;
      
    }        
  }
  
  if ($bool7 eq "OR"){
    if ($ejahr){
      OpenBib::Common::Util::print_warning("Das Suchkriterium Jahr ist nur in Verbindung mit der
UND-Verkn&uuml;pfung und mindestens einem weiteren angegebenen Suchbegriff m&ouml;glich, da sonst die Teffermengen zu gro&szlig; werden. Wir bitten um Verst&auml;ndnis f&uuml;r diese Einschr&auml;nkung.",$r);
      goto LEAVEPROG;
    }
  }
  
  if ($bool7 eq "AND"){
    if ($ejahr){
      if (!$firstsql){
	OpenBib::Common::Util::print_warning("Das Suchkriterium Jahr ist nur in Verbindung mit der
UND-Verkn&uuml;pfung und mindestens einem weiteren angegebenen Suchbegriff m&ouml;glich, da sonst die Teffermengen zu gro&szlig; werden. Wir bitten um Verst&auml;ndnis f&uuml;r diese Einschr&auml;nkung.",$r);
	goto LEAVEPROG;
      }
    }
  }
  
  if (!$firstsql){
    OpenBib::Common::Util::print_warning("Es wurde kein Suchkriterium eingegeben.",$r);
    goto LEAVEPROG;
  }
  
  
  my @ergebnisse;
  
  my $ergidx;
  
  my %trefferpage=();
  my %dbhits=();
  
  # Header mit allen Elementen ausgeben
  
  OpenBib::Common::Util::print_simple_header("Such-Client des Virtuellen Katalogs",$r);
  
  print << "HEADER";
<ul id="tabbingmenu">
   <li><a class="active" href="$config{virtualsearch_loc}?sessionID=$sessionID;trefferliste=choice;view=$view">Trefferliste</a></li>
</ul>

<div id="content">

<FORM METHOD="GET">
<p>
HEADER
  
  # Suchhinweis Digibib
  
  OpenBib::VirtualSearch::Util::print_recherche_hinweis($hst,$verf,$kor,$ejahr,$issn,$isbn,$userdbh,$sessionID);
  
  OpenBib::Common::Util::print_sort_nav($r,'sortboth',1);        
  
  # Bisherigen Header ausgeben
  
  $r->rflush();
  
  
  print"<table>\n";
  
  # Plus-Zeichen nicht verlieren...!
  
  $fs=~s/\+/%2B/g;
  $verf=~s/\+/%2B/g;
  $hst=~s/\+/%2B/g;
  $swt=~s/\+/%2B/g;
  $kor=~s/\+/%2B/g;
  $notation=~s/\+/%2B/g;
  $sign=~s/\+/%2B/g;
  $isbn=~s/\+/%2B/g;
  $issn=~s/\+/%2B/g;
  $ejahr=~s/\+/%2B/g;
  
  
  my $gesamttreffer=0;
  my $database;
  
  # BEGIN Anfrage an Datenbanken schicken und Ergebnisse einsammeln
  #
  ######################################################################
  # Schleife ueber alle Datenbanken 
  ######################################################################
  
  my @resultset=();
  
  foreach $database (@databases){


    my $suchstring="sessionID=$sessionID&search=$search&fs=$fs&verf=$verf&hst=$hst&hststring=$hststring&swt=$swt&kor=$kor&sign=$sign&isbn=$isbn&issn=$issn&mart=$mart&notation=$notation&verknuepfung=$verknuepfung&ejahr=$ejahr&ejahrop=$ejahrop&searchmode=$searchmode&maxhits=$maxhits&hitrange=-1&searchall=$searchall&dbmode=$dbmode&bool1=$bool1&bool2=$bool2&bool3=$bool3&bool4=$bool4&bool5=$bool5&bool6=$bool6&bool7=$bool7&bool8=$bool8&bool9=$bool9&bool10=$bool10&bool11=$bool11&bool12=$bool12&sorttype=$sorttype&database=$database";

    my $request=new HTTP::Request GET => "$befehlsurl?$suchstring";
    
    $logger->debug("Sending ",$suchstring," to ",$befehlsurl);
    
    my $response=$ua->request($request);
    
    if ($response->is_success) {
      $logger->debug("Getting ", $response->content);
    }
    else {
      $logger->error("Getting ", $response->status_line);
    }
    
    my $ergebnis=$response->content();
    
    my $multiple=OpenBib::VirtualSearch::Util::is_multiple_tit($ergebnis);
    my $single=OpenBib::VirtualSearch::Util::is_single_tit($ergebnis,$befehlsurl,$database,$hitrange,$sessionID,$sorttype);
    
    my $outputbuffer="";
    my $treffer=0;
    
    my $linecolor="aliceblue";
    
    if ($multiple){
      my @titel=OpenBib::VirtualSearch::Util::extract_singletit_from_multiple($ergebnis,$hitrange,\%dbases,$sorttype);
      my $tit;
      foreach $tit (@titel){
	
	# Wenn wir keinen leeren Titel in der Trefferzeile haben, dann...
	if (!($tit=~/<span id=.rltitle.> <.span>/)){
	  $treffer++;
	  $outputbuffer.="<tr bgcolor=\"$linecolor\"><td bgcolor=\"lightblue\"><strong>$treffer</strong></td>".$tit."\n";
	  
	  my $katkey="";
	  
	  ($katkey)=$tit=~/searchsingletit=(\d+)/;
	  push @resultset, "$database:$katkey";
	  
	}
	# .. ansonsten wird ein generischer Text als HST gesetzt
	else {
	  $treffer++;
	  $tit=~s/<span id=.rltitle.> <.span>/<strong>&lt;Kein HST\/AST\/EST vorhanden&gt;<\/strong>/;
	  $outputbuffer.="<tr bgcolor=\"$linecolor\"><td bgcolor=\"lightblue\"><strong>$treffer</strong></td>".$tit."\n";
	  
	}
	
	if ($linecolor eq "white"){
	  $linecolor="aliceblue";
	}
	else {
	  $linecolor="white";
	}
      } 
    }
    
    if ($single ne "none"){
      if (!($single=~/<strong> <.strong><.a>,/)){
	$treffer++;
	$outputbuffer.="<tr bgcolor=\"aliceblue\"><td bgcolor=\"lightblue\"><strong>$treffer</strong></td>".$single."</td></tr>\n";
	my ($katkey)=$single=~/searchsingletit=(\d+)/;
	
	push @resultset, "$database:$katkey";
	
      }
      else {
	$treffer++;
	$single=~s/<strong> <.strong>/<strong>&lt;Kein HST\/AST\/EST vorhanden&gt;<\/strong>/;
	$outputbuffer.="<tr bgcolor=\"aliceblue\"><td bgcolor=\"lightblue\"><strong>$treffer</strong></td>".$single."</td></tr>\n";
      }
    }
    
    
    if ($treffer != 0){
      my $tmp="<tr bgcolor=\"lightblue\"><td>&nbsp;</td><td>".$dbases{"$database"}."</td><td align=right colspan=3><strong>$treffer Treffer</strong></td></tr>\n$outputbuffer<tr>\n<td colspan=3>&nbsp;<td></tr>\n";
      print $tmp;
      $r->rflush();
      $trefferpage{$database}=$tmp;
      $dbhits{$database}=$treffer;
    }
    
    $gesamttreffer+=$treffer;
    $ergidx++;
  }
  
  ######################################################################
  #
  # ENDE Anfrage an Datenbanken schicken und Ergebnisse einsammeln

  $logger->info("InitialSearch: ", $sessionID, " ", $gesamttreffer, " fs=(", $fs, ") verf=(", $bool9, "#", $verf, ") hst=(", $bool1, "#", $hst, ") hststring=(", $bool12, "#", $hststring, ") swt=(", $bool2, "#", $swt, ") kor=(", $bool3, "#", $kor, ") sign=(", $bool6, "#", $sign, ") isbn=(", $bool5, "#", $isbn, ") issn=(", $bool8, "#", $issn, ") mart=(", $bool11, "#", $mart, ") notation=(", $bool4, "#", $notation, ") ejahr=(", $bool7, "#", $ejahr, ") ejahrop=(", $ejahrop, ") databases=(",join(' ',sort @databases),") ");

  # Wenn nichts gefunden wurde, dann entsprechende Information
  
  if ($gesamttreffer == 0) {
    my $tmp="<tr><td colspan=3><strong>Es wurden keine Treffer gefunden</strong></td></tr>\n";
    print $tmp;
  }
  # Ansonsten kann ein Resultset eingetragen werden
  else {
    OpenBib::Common::Util::updatelastresultset($sessiondbh,$sessionID,\@resultset);
  }
  ######################################################################
  # Bei einer SessionID von -1 wird effektiv keine Session verwendet
  ######################################################################
  
  if ($sessionID ne "-1"){
    
    # Jetzt update der Trefferinformationen
    
    # Plus-Zeichen fuer Abspeicherung wieder hinzufuegen...!
    
    $fs=~s/%2B/\+/g;
    $verf=~s/%2B/\+/g;
    $hst=~s/%2B/\+/g;
    $swt=~s/%2B/\+/g;
    $kor=~s/%2B/\+/g;
    $notation=~s/%2B/\+/g;
    $sign=~s/%2B/\+/g;
    $isbn=~s/%2B/\+/g;
    $issn=~s/%2B/\+/g;
    $ejahr=~s/%2B/\+/g;
    
    
    my $dbasesstring=join("||",@databases);

    my $thisquerystring="$fs||$verf||$hst||$swt||$kor||$sign||$isbn||$issn||$notation||$mart||$ejahr||$hststring||$bool1||$bool2||$bool3||$bool4||$bool5||$bool6||$bool7||$bool8||$bool9||$bool10||$bool11||$bool12";
    my $idnresult=$sessiondbh->prepare("select * from queries where query = ? and sessionid = ? and dbases = ?") or $logger->error($DBI::errstr);
    $idnresult->execute($thisquerystring,$sessionID,$dbasesstring) or $logger->error($DBI::errstr);
    
    my $queryalreadyexists=0;
    
    # Neuer Query
    if ($idnresult->rows <= 0){
      $idnresult=$sessiondbh->prepare("insert into queries (queryid,sessionid,query,hits,dbases) values (NULL,?,?,?,?)") or $logger->error($DBI::errstr);
      $idnresult->execute($sessionID,$thisquerystring,$gesamttreffer,$dbasesstring) or $logger->error($DBI::errstr);
    }
    
    # Query existiert schon
    else {
      $queryalreadyexists=1;
    }
    
    
    $idnresult=$sessiondbh->prepare("select queryid from queries where query = ? and sessionid = ? and dbases = ?") or $logger->error($DBI::errstr);
    $idnresult->execute($thisquerystring,$sessionID,$dbasesstring) or $logger->error($DBI::errstr);
    
    my @idnres;
    my $queryid;
    while (@idnres=$idnresult->fetchrow){	    
      $queryid=$idnres[0];
    }
    
    if ($queryalreadyexists == 0){
      
      my $db="";
      
      $idnresult=$sessiondbh->prepare("insert into searchresults values (?,?,?,?,?)") or $logger->error($DBI::errstr);
      
      foreach $db (keys %trefferpage){
	my $res=$trefferpage{$db};
	my $num=$dbhits{$db};
	$idnresult->execute($sessionID,$db,$res,$num,$queryid) or $logger->error($DBI::errstr);
      }
    }
    
    $idnresult->finish();
    
  }
  
  print "</table></div><p>";
  OpenBib::Common::Util::print_footer();
  
LEAVEPROG: sleep 0;
  
  $sessiondbh->disconnect();
  $userdbh->disconnect();
  
  return OK;
}

1;
