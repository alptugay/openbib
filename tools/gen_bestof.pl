#!/usr/bin/perl
#####################################################################
#
#  gen_bestof.pl
#
#  Erzeugen von BestOf-Analysen aus Relevance-Statistik-Daten
#
#  Dieses File ist (C) 2006-2015 Oliver Flimm <flimm@openbib.org>
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

use strict;
use warnings;
no warnings 'redefine';
use utf8;

use Encode 'decode_utf8';
use Log::Log4perl qw(get_logger :levels);
use Benchmark ':hireswallclock';
use DBI;
use Getopt::Long;
use Unicode::Collate;
use YAML;

use OpenBib::Config;
use OpenBib::Catalog;
use OpenBib::Schema::Catalog;
use OpenBib::Schema::System;
use OpenBib::Statistics;
use OpenBib::Record::Title;
use OpenBib::Search::Util;
use OpenBib::User;

my ($type,$database,$profile,$field,$view,$help,$num,$logfile);

&GetOptions("type=s"          => \$type,
            "database=s"      => \$database,
            "profile=s"       => \$profile,
            "view=s"          => \$view,
            "profile=s"       => \$profile,
            "field=s"         => \$field,
            "num=s"           => \$num,
	    "help"            => \$help
	    );

if ($help){
    print_help();
}

$num=($num)?$num:200;

$logfile=($logfile)?$logfile:'/var/log/openbib/gen_bestof.log';

my $log4Perl_config = << "L4PCONF";
log4perl.rootLogger=INFO, LOGFILE, Screen
log4perl.appender.LOGFILE=Log::Log4perl::Appender::File
log4perl.appender.LOGFILE.filename=$logfile
log4perl.appender.LOGFILE.mode=append
log4perl.appender.LOGFILE.layout=Log::Log4perl::Layout::PatternLayout
log4perl.appender.LOGFILE.layout.ConversionPattern=%d [%c]: %m%n
log4perl.appender.Screen=Log::Dispatch::Screen
log4perl.appender.Screen.layout=Log::Log4perl::Layout::PatternLayout
log4perl.appender.Screen.layout.ConversionPattern=%d [%c]: %m%n
L4PCONF

Log::Log4perl::init(\$log4Perl_config);

# Log4perl logger erzeugen
my $logger = get_logger();

my $config     = OpenBib::Config->new;
my $user       = new OpenBib::User;
my $statistics = OpenBib::Statistics->instance;

# Verbindung zur SQL-Datenbank herstellen
my $statisticsdbh = DBI->connect("DBI:Pg:dbname=$config->{statisticsdbname};host=$config->{statisticsdbhost};port=$config->{statisticsdbport}", $config->{statisticsdbuser}, $config->{statisticsdbpasswd},{'pg_enable_utf8'    => 1})
    or $logger->error($DBI::errstr);

if (!$type){
  $logger->fatal("Kein Type mit --type= ausgewaehlt");
  exit;
}

# Typ 1 => Meistaufgerufene Titel pro Datenbank
if ($type == 1){
    my @databases = ();

    if ($database){
        push @databases, $database;
    }
    else {
        @databases=$config->get_active_databases();
    }
    
    foreach my $database (@databases){
        $logger->info("Generating Type 1 BestOf-Values for database $database");

        my $bestof_ref=[];

        # DBI "select id, count(sid) as sidcount from titleusage where origin=2 and dbname=? and DATE_SUB(CURDATE(),INTERVAL 6 MONTH) <= tstamp group by id order by idcount desc limit 20"
        my $titleusage = $statistics->get_schema->resultset('Titleusage')->search_rs(
            {
                dbname => $database,
                origin => 1,
#                tstamp => { '>' => 20110101000000 },
                tstamp => { '>' => \'CURRENT_TIMESTAMP - INTERVAL \'180 days\'' },
                
            },
            {
                select   => ['titleid', {'count' => 'sid'}],
                as       => ['titleid','sidcount'],
                group_by => ['titleid'],
                order_by => { -desc => \'count(sid)' },
                rows     => 20,
            }
        );
        foreach my $item ($titleusage->all){
            my $titleid  = $item->get_column('titleid');
            my $count    = $item->get_column('sidcount');

            $logger->debug("Got Title with id $titleid and Session-Count $count");
            
            my $item=OpenBib::Record::Title->new({database => $database, id => $titleid, config => $config})->load_brief_record->to_hash;

            push @$bestof_ref, {
                item  => $item,
                count => $count,
            };
        }

        $statistics->cache_data({
            type => 1,
            id   => $database,
            data => $bestof_ref,
        });
    }
}

# Typ 2 => Meistgenutzte Datenbanken
if ($type == 2){
    my @views = ();

    if ($view){
        push @views, $view;
    }
    else {
        @views=$config->get_active_views();
    }

    foreach my $view (sort @views){
        $logger->info("Generating Type 2 BestOf-Values for view $view");

        my $viewdb_ref = [];
        foreach my $dbname ($config->get_viewdbs($view)){
            push @$viewdb_ref, {dbname => $dbname };
        }

        next unless (@$viewdb_ref);
        
        my $bestof_ref=[];
        # DBI: "select dbname, count(katkey) as kcount from titleusage where origin=2 group by dbname order by kcount desc limit 20"
        my $databaseusage = $statistics->get_schema->resultset('Titleusage')->search_rs(
            {
                -or    => $viewdb_ref,
                origin => 1,
                #                tstamp => { '>' => 20110101000000 },
                tstamp => { '>' => \'CURRENT_TIMESTAMP - INTERVAL \'180 days\'' },
                
            },
            {
                select   => ['dbname', {'count' => 'titleid'}],
                as       => ['dbname','kcount'],
                group_by => ['dbname'],
                order_by => { -desc => \'count(titleid)' },
                rows     => 20,
            }
        );
        
        foreach my $item ($databaseusage->all){
            my $dbname = $item->get_column('dbname');
            my $count  = $item->get_column('kcount');
            
            push @$bestof_ref, {
                item  => $dbname,
                count => $count,
            };
        }
        
        $statistics->cache_data({
            type => 2,
            id   => $view,
            data => $bestof_ref,
        });
    }
}

# Typ 3 => Meistgenutzte Schlagworte
if ($type == 3){
    my @databases = ();

    if ($database){
        push @databases, $database;
    }
    else {
        @databases=$config->get_active_databases();
    }

    foreach my $database (@databases){
        $logger->info("Generating Type 3 BestOf-Values for database $database");

        my $maxcount=0;
	my $mincount=999999999;

        my $catalog = new OpenBib::Catalog({ database => $database });
        
        my $bestof_ref=[];

        # DBI: "select subject.content , count(distinct sourceid) as scount from conn, subject where sourcetype=1 and targettype=4 and subject.category=1 and subject.id=conn.targetid group by targetid order by scount desc limit 200"
        my $usage = $catalog->get_schema->resultset('Subject')->search_rs(
            {
                'subject_fields.field' => 800,
                'subject_fields.mult'  => 1,
            },
            {
                select   => ['subject_fields.content', {'count' => 'title_subjects.titleid'}],
                as       => ['thiscontent','titlecount'],
                join     => ['subject_fields','title_subjects'],
                group_by => ['title_subjects.subjectid','subject_fields.content'],
                order_by => { -desc => \'count(title_subjects.titleid)' },
                rows     => $num,
            }
        );

        foreach my $item ($usage->all){
            my $content = $item->get_column('thiscontent');
            my $count   = $item->get_column('titlecount');
            
            if ($maxcount < $count){
                $maxcount = $count;
            }
            
            if ($mincount > $count){
                $mincount = $count;
            }
            
            push @$bestof_ref, {
                item  => $content,
                count => $count,
            };
        }
        
	$bestof_ref = gen_cloud_class(
            {
                items => $bestof_ref, 
                min   => $mincount, 
                max   => $maxcount, 
                type  => $config->{best_of}{$type}{cloud}
            }
        );

        my $sortedbestof_ref ;
        my $collator = Unicode::Collate->new();
        
        @{$sortedbestof_ref} = map { $_->[0] }
            sort { $collator->cmp($a->[1],$b->[1]) }
                map { [$_, $_->{item}] }
                    @{$bestof_ref};
        
        $statistics->cache_data({
            type => 3,
            id   => $database,
            data => $sortedbestof_ref,
        });
    }
}

# Typ 4 => Meistgenutzte Notationen/Systematiken
if ($type == 4){
    my @databases = ();

    if ($database){
        push @databases, $database;
    }
    else {
        @databases=$config->get_active_databases();
    }

    foreach my $database (@databases){
        $logger->info("Generating Type 4 BestOf-Values for database $database");

        my $maxcount=0;
	my $mincount=999999999;

        my $catalog = new OpenBib::Catalog({ database => $database });

        my $bestof_ref=[];

        # DBI: "select classification.content , count(distinct sourceid) as scount from conn, classification where sourcetype=1 and targettype=5 and classification.category=1 and classification.id=conn.targetid group by targetid order by scount desc limit 200"
        my $usage = $catalog->get_schema->resultset('Classification')->search_rs(
            {
                'classification_fields.field' => 800,
            },
            {
                select   => ['classification_fields.content', {'count' => 'title_classifications.titleid'}],
                as       => ['thiscontent','titlecount'],
                join     => ['classification_fields','title_classifications'],
                group_by => ['title_classifications.classificationid','classification_fields.content'],
                order_by => { -desc => \'count(title_classifications.titleid)' },
                rows     => $num,
            }
        );

        foreach my $item ($usage->all){
            my $content = $item->get_column('thiscontent');
            my $count   = $item->get_column('titlecount');

            if ($maxcount < $count){
                $maxcount = $count;
            }

            if ($mincount > $count){
                $mincount = $count;
            }
            
            push @$bestof_ref, {
                item  => $content,
                count => $count,
            };
        }

	$bestof_ref = gen_cloud_class({
				       items => $bestof_ref, 
				       min   => $mincount, 
				       max   => $maxcount, 
				       type  => $config->{best_of}{$type}{cloud}});


        my $sortedbestof_ref ;
        my $collator = Unicode::Collate->new();
        
        @{$sortedbestof_ref} = map { $_->[0] }
            sort { $collator->cmp($a->[1],$b->[1]) }
                map { [$_, $_->{item}] }
                    @{$bestof_ref};
        
        $statistics->cache_data({
            type => 4,
            id   => $database,
            data => $sortedbestof_ref,
        });
    }
}

# Typ 5 => Meistgenutzte Koerperschaften/Urheber
if ($type == 5){
    my @databases = ();

    if ($database){
        push @databases, $database;
    }
    else {
        @databases=$config->get_active_databases();
    }

    foreach my $database (@databases){
        $logger->info("Generating Type 5 BestOf-Values for database $database");

        my $maxcount=0;
	my $mincount=999999999;

        my $catalog = new OpenBib::Catalog({ database => $database });

        my $bestof_ref=[];

        # DBI: "select corporatebody.content , count(distinct sourceid) as scount from conn, corporatebody where sourcetype=1 and targettype=3 and corporatebody.category=1 and corporatebody.id=conn.targetid group by targetid order by scount desc limit 200"
        my $usage = $catalog->get_schema->resultset('Corporatebody')->search_rs(
            {
                'corporatebody_fields.field' => 800,
            },
            {
                select   => ['corporatebody_fields.content', {'count' => 'title_corporatebodies.titleid'}],
                as       => ['thiscontent','titlecount'],
                join     => ['corporatebody_fields','title_corporatebodies'],
                group_by => ['title_corporatebodies.corporatebodyid','corporatebody_fields.content'],
                order_by => { -desc => \'count(title_corporatebodies.titleid)' },
                rows     => $num,
            }
        );

        foreach my $item ($usage->all){
            my $content = $item->get_column('thiscontent');
            my $count   = $item->get_column('titlecount');

            if ($maxcount < $count){
                $maxcount = $count;
            }

            if ($mincount > $count){
                $mincount = $count;
            }
            
            push @$bestof_ref, {
                item  => $content,
                count => $count,
            };
        }

	$bestof_ref = gen_cloud_class({
				       items => $bestof_ref, 
				       min   => $mincount, 
				       max   => $maxcount, 
				       type  => $config->{best_of}{$type}{cloud}});

        my $sortedbestof_ref ;
        my $collator = Unicode::Collate->new();
        
        @{$sortedbestof_ref} = map { $_->[0] }
            sort { $collator->cmp($a->[1],$b->[1]) }
                map { [$_, $_->{item}] }
                    @{$bestof_ref};
        
        $statistics->cache_data({
            type => 5,
            id   => $database,
            data => $sortedbestof_ref,
        });
    }
}

# Typ 6 => Meistgenutzte Verfasser/Personen
if ($type == 6){
    my @databases = ();

    if ($database){
        push @databases, $database;
    }
    else {
        @databases=$config->get_active_databases();
    }

    foreach my $database (@databases){
        $logger->info("Generating Type 6 BestOf-Values for database $database");

        my $maxcount=0;
	my $mincount=999999999;

        my $catalog = new OpenBib::Catalog({ database => $database });

        my $bestof_ref=[];

        # DBI: "select person.content , count(distinct sourceid) as scount from conn, person where sourcetype=1 and targettype=2 and person.category=1 and person.id=conn.targetid group by targetid order by scount desc limit 200"
        my $usage = $catalog->get_schema->resultset('Person')->search_rs(
            {
                'person_fields.field' => 800,
            },
            {
                select   => ['person_fields.content', {'count' => 'title_people.titleid'}],
                as       => ['thiscontent','titlecount'],
                join     => ['person_fields','title_people'],
                group_by => ['title_people.personid','person_fields.content'],
                order_by => { -desc => \'count(title_people.titleid)' },
                rows     => $num,
            }
        );

        while (my $item = $usage->next()){
#        foreach my $item ($usage->all){
            my $content = $item->get_column('thiscontent');
            my $count   = $item->get_column('titlecount');
        
            if ($maxcount < $count){
                $maxcount = $count;
            }

            if ($mincount > $count){
                $mincount = $count;
            }
            
            push @$bestof_ref, {
                item  => $content,
                count => $count,
            };
        }

	$bestof_ref = gen_cloud_class({
				       items => $bestof_ref, 
				       min   => $mincount, 
				       max   => $maxcount, 
				       type  => $config->{best_of}{$type}{cloud}});


        my $sortedbestof_ref ;
        my $collator = Unicode::Collate->new();
        
        @{$sortedbestof_ref} = map { $_->[0] }
            sort { $collator->cmp($a->[1],$b->[1]) }
                map { [$_, $_->{item}] }
                    @{$bestof_ref};

        $statistics->cache_data({
            type => 6,
            id   => $database,
            data => $sortedbestof_ref,
        });
    }
}

# Typ 7 => Von Nutzern vergebene Tags
if ($type == 7){
    my @databases = ();

    if ($database){
        push @databases, $database;
    }
    else {
        @databases=$config->get_active_databases();
    }

    foreach my $database (@databases){
        $logger->info("Generating Type 7 BestOf-Values for database $database");

        my $maxcount=0;
	my $mincount=999999999;

        my $bestof_ref=[];
        
        # DBI: "select t.id,t.tag,count(tt.tagid) as scount from tags as t, tittag as tt where tt.dbname=? and tt.tagid=t.id group by tt.tagid"
        my $usage = $user->get_schema->resultset('Tag')->search_rs(
            {
                'tit_tags.dbname' => $database,
            },
            {
                select   => ['me.name', 'me.id',{'count' => 'tit_tags.tagid'}],
                as       => ['thiscontent','thisid','titlecount',],
                join     => ['tit_tags'],
                group_by => ['tit_tags.tagid','me.name','me.id'],
                rows     => $num,
            }
        );
        
        foreach my $item ($usage->all){
            my $content = $item->get_column('thiscontent');
            my $id      = $item->get_column('thisid');
            my $count   = $item->get_column('titlecount');

            if ($maxcount < $count){
                $maxcount = $count;
            }

            if ($mincount > $count){
                $mincount = $count;
            }
            
            push @$bestof_ref, {
                item  => $content,
                id    => $id,
                count => $count,
            };
        }

	$bestof_ref = gen_cloud_class({
				       items => $bestof_ref, 
				       min   => $mincount, 
				       max   => $maxcount, 
				       type  => $config->{best_of}{$type}{cloud}});


        my $sortedbestof_ref ;
        my $collator = Unicode::Collate->new();
        
        @{$sortedbestof_ref} = map { $_->[0] }
            sort { $collator->cmp($a->[1],$b->[1]) }
                map { [$_, $_->{item}] }
                    @{$bestof_ref};
        
        $statistics->cache_data({
            type => 7,
            id   => $database,
            data => $sortedbestof_ref,
        });
    }
}

# Typ 8 => Meistgenutzte Suchbegriffe pro View
if ($type == 8){
    my @views = ();

    if ($view){
        push @views, $view;
    }
    else {
        @views=$config->get_active_views();
    }

    foreach my $view (@views){
        $logger->info("Generating Type 8 BestOf-Values for view $view");

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

	my $bestof_ref={};
        foreach my $category (qw/all fs hst verf swt/){
	  my $thisbestof_ref=[];
	  my $sqlstring;

          my $maxcount=0;
	  my $mincount=999999999;

	  my @sqlargs = ($view);

	  if ($category eq 'all'){
	    $sqlstring="select content, count(content) as scount from searchterms where DATE_SUB(CURDATE(),INTERVAL 6 MONTH) <= tstamp and viewname=? group by content order by scount DESC limit 200";
	  }
	  else {
	    $sqlstring="select content, count(content) as scount from searchterms where DATE_SUB(CURDATE(),INTERVAL 6 MONTH) <= tstamp and viewname=? and type = ? group by content order by scount DESC limit 200";
	    push @sqlargs, $cat2type_ref->{$category}; 
	  }

	  my $request=$statisticsdbh->prepare($sqlstring);
	  $request->execute(@sqlargs);
	  while (my $result=$request->fetchrow_hashref){
            my $content = $result->{content};
            my $count   = $result->{scount};
            if ($maxcount < $count){
	      $maxcount = $count;
            }
            if ($mincount > $count){
	      $mincount = $count;
            }
            
            push @$thisbestof_ref, {
				item  => $content,
				count => $count,
            };
	  }

	  $thisbestof_ref = gen_cloud_class({
              items => $thisbestof_ref, 
              min   => $mincount, 
              max   => $maxcount, 
              type  => $config->{best_of}{$type}{cloud}});
          
          
          my $sortedbestof_ref ;
          my $collator = Unicode::Collate->new();
          
          @{$sortedbestof_ref} = map { $_->[0] }
              sort { $collator->cmp($a->[1],$b->[1]) }
                  map { [$_, $_->{item}] }
                      @{$thisbestof_ref};
          
          
	  $bestof_ref->{$category}=$sortedbestof_ref;
      }
        
        if ($logger->is_debug){
            $logger->debug(YAML::Dump($bestof_ref));
        }
        
        $statistics->cache_data({
            type => 8,
            id   => $view,
            data => $bestof_ref,
        });
    }
}

# Typ 9 => Meistvorkommende Erscheinungsjahre pro Datenbank
if ($type == 9){
    my @databases = ();

    if ($database){
        push @databases, $database;
    }
    else {
        @databases=$config->get_active_databases();
    }
    
    foreach my $database (@databases){
        $logger->info("Generating Type 9 BestOf-Values for database $database");

        my $maxcount=0;
	my $mincount=999999999;

        my $catalog = new OpenBib::Catalog({ database => $database });

        my $bestof_ref=[];

        # DBI: "select count(distinct id) as scount, content from title where category=425 and content regexp ? group by content order by scount DESC" mit RegEXP "^[0-9][0-9][0-9][0-9]\$"
        my $usage = $catalog->get_schema->resultset('Title')->search_rs(
            {
                'title_fields.field' => 425,
            },
            {
                select   => ['title_fields.content', {'count' => 'title_fields.titleid'}],
                as       => ['thiscontent','titlecount'],
                join     => ['title_fields'],
                group_by => ['title_fields.content'],
                order_by => { -desc => \'count(title_fields.titleid)' },
                rows     => $num,
            }
        );

        foreach my $item ($usage->all){
            my $content = $item->get_column('thiscontent');
            my $count   = $item->get_column('titlecount');

            if ($maxcount < $count){
                $maxcount = $count;
            }

            if ($mincount > $count){
                $mincount = $count;
            }
            
            push @$bestof_ref, {
                item  => $content,
                count => $count,
            };
        }

	$bestof_ref = gen_cloud_class({
				       items => $bestof_ref, 
				       min   => $mincount, 
				       max   => $maxcount, 
				       type  => $config->{best_of}{$type}{cloud}});

        my $sortedbestof_ref ;
        my $collator = Unicode::Collate->new();
        
        @{$sortedbestof_ref} = map { $_->[0] }
            sort { $collator->cmp($a->[1],$b->[1]) }
                map { [$_, $_->{item}] }
                    @{$bestof_ref};
        
        $statistics->cache_data({
            type => 9,
            id   => $database,
            data => $sortedbestof_ref,
        });
    }
}

# Typ 10 => Titel nach BK pro View
if ($type == 10){
    my @views = ();

    if ($view){
        push @views, $view;
    }
    else {
        @views=$config->get_active_views();
    }

    foreach my $view (@views){
        $logger->info("Generating Type 10 BestOf-Values for view $view");

        my @databases = $config->get_dbs_of_view($view);
        
        # Verbindung zur SQL-Datenbank herstellen
        my $enrichdbh
            = DBI->connect("DBI:Pg:dbname=$config->{enrichmntdbname};host=$config->{enrichmntdbhost};port=$config->{enrichmntdbport}", $config->{enrichmntdbuser}, $config->{enrichmntdbpasswd})
                or $logger->error_die($DBI::errstr);

        my $bk_ref = {};

        my $in_select_string = join(',',map {'?'} @databases);
        my $sqlstring="select count(distinct ai.titleid) as bkcount,n.content as bk from all_titles_by_isbn as ai, enriched_content_by_isbn as n where n.field=4100 and n.isbn=ai.isbn and ai.dbname in ($in_select_string) group by n.content,ai.dbname";

        $logger->debug("$sqlstring");
        my $request=$enrichdbh->prepare($sqlstring) or $logger->error($DBI::errstr);
        $request->execute(@databases);

        while (my $result=$request->fetchrow_hashref){
            my $bk      = $result->{bk};
            my $bkcount = $result->{bkcount};

            my $base_bk = substr($bk,0,2);

            if (exists $bk_ref->{$base_bk}){
                $bk_ref->{$base_bk} = $bk_ref->{$base_bk}+$bkcount;
            }
            else {
                $bk_ref->{$base_bk} = $bkcount;
            }
            $bk_ref->{$bk}          = $bkcount;
        }
        
        if ($logger->is_debug){
            $logger->debug(YAML::Dump($bk_ref));
        }
        
        $statistics->cache_data({
            type => 10,
            id   => $view,
            data => $bk_ref,
        });
    }
}

# Typ 11 => Titel nach BK pro Katalog pro Sicht
if ($type == 11){
    my @views = ();

    if ($view){
        push @views, $view;
    }
    else {
        @views=$config->get_active_views();
    }

    foreach my $view (@views){
#        next if ($view eq "kug");
        $logger->info("Generating Type 11 BestOf-Values for view $view");

        my @databases = $config->get_dbs_of_view($view);
        
        # Verbindung zur SQL-Datenbank herstellen
        my $enrichdbh
            = DBI->connect("DBI:Pg:dbname=$config->{enrichmntdbname};host=$config->{enrichmntdbhost};port=$config->{enrichmntdbport}", $config->{enrichmntdbuser}, $config->{enrichmntdbpasswd})
                or $logger->error_die($DBI::errstr);

        my $bk_ref = {};

        foreach my $database (@databases){
            $logger->info("Generating BK's for database $database");
            my $sqlstring="select count(distinct ai.isbn) as bkcount,n.content as bk from all_titles_by_isbn as ai, enriched_content_by_isbn as n where n.field=4100 and n.isbn=ai.isbn and ai.dbname=? group by n.content";
            my $request=$enrichdbh->prepare($sqlstring) or $logger->error($DBI::errstr);
            $request->execute($database);
            
            while (my $result=$request->fetchrow_hashref){
                my $bk      = $result->{bk};
                my $bkcount = $result->{bkcount};
                
                my $base_bk = substr($bk,0,2);
                
                if (exists $bk_ref->{$base_bk} && exists $bk_ref->{$base_bk}{$database}){
                    $bk_ref->{$base_bk}{$database} = $bk_ref->{$base_bk}{$database}+$bkcount;
                }
                else {
                    $bk_ref->{$base_bk}{$database} = $bkcount;
                }
                $bk_ref->{$bk}{$database} = $bkcount;
            }
        }

        foreach my $bk (keys %{$bk_ref}){
            $statistics->cache_data({
                type   => 11,
                subkey => $bk,
                id     => $view,
                data   => $bk_ref->{$bk},
            });
            
            if ($logger->is_debug){
                $logger->debug(YAML::Dump($bk_ref->{$bk}));
            }
        }

    }
}

# Typ 12 => Meistaufgerufene Literaturlisten
if ($type == 12){

    my $dbh
        = DBI->connect("DBI:Pg:dbname=$config->{statisticsdbname};host=$config->{statisticsdbhost};port=$config->{statisticsdbport}", $config->{statisticsdbuser}, $config->{statisticsdbpasswd})
            or $logger->error_die($DBI::errstr);

    $logger->info("Generating Type 12 BestOf-Values");

    my $maxcount=0;
    my $mincount=999999999;
    
    my $bestof_ref=[];
    my $request = $dbh->prepare("select content as id, count(content) as scount from eventlog where type = 800 group by content order by scount DESC limit 200");
    $request->execute();
    while (my $result=$request->fetchrow_hashref){
        my $properties_ref = $user->get_litlist_properties({ litlistid => $result->{id}});
        my $content        = $properties_ref->{title};
        my $id             = $result->{id};
        my $count          = $result->{scount};
        if ($maxcount < $count){
            $maxcount = $count;
        }
        
        if ($mincount > $count){
            $mincount = $count;
        }

        if ($logger->is_debug){
            $logger->debug(YAML::Dump($properties_ref));
        }

        # Nur oeffentliche Literaturlisten verwenden
        push @$bestof_ref, {
            item       => $content,
            id         => $id,
            count      => $count,
            properties => $properties_ref,
        } if ($properties_ref->{type} == 1);
    }
    
    $bestof_ref = gen_cloud_class({
        items => $bestof_ref, 
        min   => $mincount, 
        max   => $maxcount, 
        type  => $config->{best_of}{$type}{cloud}});

    my $sortedbestof_ref ;
    my $collator = Unicode::Collate->new();
    
    @{$sortedbestof_ref} = map { $_->[0] }
        sort { $collator->cmp($a->[1],$b->[1]) }
            map { [$_, $_->{item}] }
                @{$bestof_ref};
    
    $statistics->cache_data({
        type => 12,
        id   => 'litlist_usage',
        data => $sortedbestof_ref,
    });
}

# Typ 13 => Meistaufgerufene Titel allgemein
if ($type == 13){
    my @views = ();

    if ($view){
        push @views, $view;
    }
    else {
        @views=$config->get_active_views();
    }

    foreach my $view (sort @views){
        $logger->info("Generating Type 13 BestOf-Values for view $view");

        my $viewdb_ref = [];
        foreach my $dbname ($config->get_viewdbs($view)){
            push @$viewdb_ref, {dbname => $dbname };
        }

        next unless (@$viewdb_ref);

        my $bestof_ref=[];

        my $titleusage = $statistics->get_schema->resultset('Titleusage')->search_rs(
            {
                -or    => $viewdb_ref,
                origin => 1,
                tstamp => { '>' => \'CURRENT_TIMESTAMP - INTERVAL \'180 days\'' },
                
            },
            {
                select   => ['titleid','dbname', {'count' => 'sid'}],
                as       => ['titleid','dbname','sidcount'],
                group_by => ['titleid','dbname'],
                order_by => { -desc => \'count(sid)' },
                rows     => 20,
            }
        );
        foreach my $item ($titleusage->all){
            my $titleid  = $item->get_column('titleid');
            my $count    = $item->get_column('sidcount');
            my $database = $item->get_column('dbname');

            my $item=OpenBib::Record::Title->new({database => $database, id => $titleid, config => $config})->load_brief_record()->to_hash;

            push @$bestof_ref, {
                item  => $item,
                count => $count,
            };
        }

        $statistics->cache_data({
            type => 13,
            id   => $view,
            data => $bestof_ref,
        });
    }
}

# Typ 14 => Meistvorkommender Feldinhalt pro Datenbank
if ($type == 14 && $field){
    my @databases = ();

    if ($database){
        push @databases, $database;
    }
    else {
        @databases=$config->get_active_databases();
    }
    
    foreach my $database (@databases){
        $logger->info("Generating Type 14 BestOf-Values for database $database");

        my $maxcount=0;
	my $mincount=999999999;

        my $catalog = new OpenBib::Catalog({ database => $database });

        my $bestof_ref=[];

        # DBI: "select count(distinct id) as scount, content from title where category=425 and content regexp ? group by content order by scount DESC" mit RegEXP "^[0-9][0-9][0-9][0-9]\$"
        my $usage = $catalog->get_schema->resultset('Title')->search_rs(
            {
                'title_fields.field' => $field,
            },
            {
                select   => ['title_fields.content', {'count' => 'title_fields.titleid'}],
                as       => ['thiscontent','titlecount'],
                join     => ['title_fields'],
                group_by => ['title_fields.content'],
                order_by => { -desc => \'count(title_fields.titleid)' },
                rows     => $num,
            }
        );

        foreach my $item ($usage->all){
            my $content = $item->get_column('thiscontent');
            my $count   = $item->get_column('titlecount');

            if ($maxcount < $count){
                $maxcount = $count;
            }

            if ($mincount > $count){
                $mincount = $count;
            }
            
            push @$bestof_ref, {
                item  => $content,
                count => $count,
            };
        }

	$bestof_ref = gen_cloud_class({
				       items => $bestof_ref, 
				       min   => $mincount, 
				       max   => $maxcount, 
				       type  => $config->{best_of}{$type}{cloud}});

        my $sortedbestof_ref ;
        my $collator = Unicode::Collate->new();
        
        @{$sortedbestof_ref} = map { $_->[0] }
            sort { $collator->cmp($a->[1],$b->[1]) }
                map { [$_, $_->{item}] }
                    @{$bestof_ref};
        
        $statistics->cache_data({
            type => 14,
            id   => "$database-$field",
            data => $sortedbestof_ref,
        });
    }
}

sub gen_cloud_class {
    my ($arg_ref) = @_;
    
    # Set defaults
    my $items_ref    = exists $arg_ref->{items}
        ? $arg_ref->{items}   : [];
    my $mincount     = exists $arg_ref->{min}
        ? $arg_ref->{min}     : 0;
    my $maxcount     = exists $arg_ref->{max}
        ? $arg_ref->{max}     : 0;
    my $type         = exists $arg_ref->{type}
        ? $arg_ref->{type}    : 'log';

    # Log4perl logger erzeugen
    my $logger = get_logger();

    if ($type eq 'log'){

      if ($maxcount-$mincount > 0){
	
	my $delta = ($maxcount-$mincount) / 6;
	
	my @thresholds = ();
	
	for (my $i=0 ; $i<=6 ; $i++){
	  $thresholds[$i] = 100 * log(($mincount + $i * $delta) + 2);
	}

        if ($logger->is_debug){
            $logger->debug(YAML::Dump(\@thresholds)." - $delta");
        }

	foreach my $item_ref (@$items_ref){
	  my $done = 0;
	
	  for (my $class=0 ; $class<=6 ; $class++){
	    if ((100 * log($item_ref->{count} + 2) <= $thresholds[$class]) && !$done){
	      $item_ref->{class} = $class;
              $logger->debug("Klasse $class gefunden");
	      $done = 1;
	    }
	  }
	}
      }
    }
    elsif ($type eq 'linear'){
      if ($maxcount-$mincount > 0){
	foreach my $item_ref (@$items_ref){
	  $item_ref->{class} = int(($item_ref->{count}-$mincount) / ($maxcount-$mincount) * 6);
	}
      }
    }

    if ($logger->is_debug){
        $logger->debug(YAML::Dump($items_ref));
    }
    
    return $items_ref;
}

sub print_help {
    print << "ENDHELP";
gen_bestof.pl - Erzeugen von BestOf-Analysen aus Relevance-Statistik-Daten

   Optionen:
   -help                 : Diese Informationsseite
   --database=...        : Einzelner Katalog
   --logfile=...         : Alternatives Logfile
   --type=...            : BestOf-Typ

   Typen:

   1 => Meistaufgerufene Titel pro Datenbank
   2 => Meistgenutzte Kataloge bezogen auf Titelaufrufe pro View
   3 => Meistgenutzte Schlagworte pro Katalog (Wolke)
   4 => Meistgenutzte Notationen/Systematiken pro Katalog (Wolke)
   5 => Meistgenutzte Koerperschaften/Urheber pro Katalog (Wolke)
   6 => Meistgenutzte Verfasser/Personen pro Katalog (Wolke)
   7 => Nutzer-Tags pro Katalog (Wolke)
   8 => Suchbegriffe pro View (Wolke)
   9 => Meistvorkommende Erscheinungsjahre pro Katalog (Wolke)
  10 => Titel nach BK pro View
  11 => Titel nach BK pro Katalog pro Sicht
  12 => Meistaufgerufene Literaturlisten
  13 => Meistaufgerufene Titel allgemein       
ENDHELP
    exit;
}

