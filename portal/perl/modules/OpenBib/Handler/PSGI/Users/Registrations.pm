#####################################################################
#
#  OpenBib::Handler::PSGI::Users::Registrations
#
#  Dieses File ist (C) 2004-2012 Oliver Flimm <flimm@openbib.org>
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

package OpenBib::Handler::PSGI::Users::Registrations;

use strict;
use warnings;
no warnings 'redefine';
use utf8;

use Email::Valid;               # EMail-Adressen testen
use Encode 'decode_utf8';
use Log::Log4perl qw(get_logger :levels);
use Captcha::reCAPTCHA;
use POSIX;
use MIME::Lite;

use OpenBib::Common::Util;
use OpenBib::Config;
use OpenBib::L10N;
use OpenBib::QueryOptions;
use OpenBib::Session;
use OpenBib::User;

use base 'OpenBib::Handler::PSGI';

# Run at startup
sub setup {
    my $self = shift;

    $self->start_mode('show');
    $self->run_modes(
        'show'              => 'show',
        'register'          => 'register',
        'mail_confirmation' => 'mail_confirmation',
        'dispatch_to_representation'           => 'dispatch_to_representation',
    );

    # Use current path as template path,
    # i.e. the template is in the same directory as this script
#    $self->tmpl_path('./');
}

sub show {
    my $self = shift;

    # Log4perl logger erzeugen
    my $logger = get_logger();
    
    # Dispatched Args
    my $view           = $self->param('view')           || '';

    # Shared Args
    my $query          = $self->query();
    my $r              = $self->param('r');
    my $config         = $self->param('config');    
    my $session        = $self->param('session');
    my $user           = $self->param('user');
    my $msg            = $self->param('msg');
    my $queryoptions   = $self->param('qopts');
    my $stylesheet     = $self->param('stylesheet');    
    my $useragent      = $self->param('useragent');
    my $path_prefix    = $self->param('path_prefix');
    
    # CGI Args
    my $action              = ($query->param('action'))?$query->param('action'):'none';
    my $targetid            = ($query->param('targetid'))?$query->param('targetid'):'none';
    my $username            = ($query->param('username'))?$query->param('username'):'';
    my $password1           = ($query->param('password1'))?$query->param('password1'):'';
    my $password2           = ($query->param('password2'))?$query->param('password2'):'';
    my $recaptcha_challenge = $query->param('recaptcha_challenge_field');
    my $recaptcha_response  = $query->param('recaptcha_response_field');

    
    my $recaptcha = Captcha::reCAPTCHA->new;

    # Wenn der Request ueber einen Proxy kommt, dann urspruengliche
    # Client-IP setzen
    my $client_ip="";
    
    if ($r->header('X-Forwarded-For') =~ /([^,\s]+)$/) {
        $client_ip=$1;
    }

    # TT-Data erzeugen
    my $ttdata={
        recaptcha  => $recaptcha,
        
        lang       => $queryoptions->get_option('l'),
    };
    
    return $self->print_page($config->{tt_users_registrations_tname},$ttdata);
}

sub mail_confirmation {
    my $self = shift;

    # Log4perl logger erzeugen
    my $logger = get_logger();
    
    # Dispatched Args
    my $view           = $self->param('view')           || '';

    # Shared Args
    my $query          = $self->query();
    my $r              = $self->param('r');
    my $config         = $self->param('config');    
    my $session        = $self->param('session');
    my $user           = $self->param('user');
    my $msg            = $self->param('msg');
    my $queryoptions   = $self->param('qopts');
    my $stylesheet     = $self->param('stylesheet');    
    my $useragent      = $self->param('useragent');
    my $path_prefix    = $self->param('path_prefix');

    # CGI Args
    my $action              = ($query->param('action'))?$query->param('action'):'none';
    my $targetid            = ($query->param('targetid'))?$query->param('targetid'):'none';
    my $username            = ($query->param('username'))?$query->param('username'):'';
    my $password1           = ($query->param('password1'))?$query->param('password1'):'';
    my $password2           = ($query->param('password2'))?$query->param('password2'):'';
    my $recaptcha_challenge = $query->param('recaptcha_challenge_field');
    #my $recaptcha_response  = $query->param('recaptcha_response_field');
    my $recaptcha_response  = $query->param('g-recaptcha-response');

    if ($logger->is_debug){
	foreach my $qparam ($query->param){
	    $logger->debug("$qparam -> ".$query->param($qparam));
	}
    }
    
    my $recaptcha = Captcha::reCAPTCHA->new;

    # Wenn der Request ueber einen Proxy kommt, dann urspruengliche
    # Client-IP setzen
    # Wenn der Request ueber einen Proxy kommt, dann urspruengliche
    # Client-IP setzen
    my $client_ip="";
    
    if ($r->header('X-Forwarded-For') =~ /([^,\s]+)$/) {
        $client_ip=$1;
    }

    # Cleanup Username
    $username=~s/^\s+//g;
    $username=~s/\s+$//g;
    
    if ($username eq "" || $password1 eq "" || $password2 eq "") {
        return $self->print_warning($msg->maketext("Es wurde entweder kein Benutzername oder keine zwei Passworte eingegeben"));
    }

    if ($password1 ne $password2) {
        return $self->print_warning($msg->maketext("Die beiden eingegebenen Passworte stimmen nicht Ã¼berein."));
    }
    
    # Ueberpruefen, ob es eine gueltige Mailadresse angegeben wurde.
    unless (Email::Valid->address($username)){
        return $self->print_warning($msg->maketext("Sie haben keine gÃ¼tige Mailadresse eingegeben. Gehen Sie bitte [_1]zurÃ¼ck[_2] und korrigieren Sie Ihre Eingabe","<a href=\"$path_prefix/$config->{users_loc}/$config->{registrations_loc}\">","</a>"));
    }
    
    if ($user->user_exists($username)) {
        return $self->print_warning($msg->maketext("Ein Benutzer mit dem Namen [_1] existiert bereits. Haben Sie vielleicht Ihr Passwort vergessen? Dann gehen Sie bitte [_2]zurÃ¼ck[_3] und lassen es sich zumailen.","$username","<a href=\"http://$r->get_server_name$path_prefix/$config->{users_loc}/$config->{registrations_loc}.html\">","</a>"));
    }
    
    # Recaptcha nur verwenden, wenn Zugriffsinformationen vorhanden sind
    if ($config->{recaptcha_private_key}){
        # Recaptcha pruefen
        my $recaptcha_result = $recaptcha->check_answer_v2(
            $config->{recaptcha_private_key}, $recaptcha_response, $client_ip
        );
        
        unless ( $recaptcha_result->{is_valid} ) {
            return $self->print_warning($msg->maketext("Sie haben ein falsches Captcha eingegeben! Gehen Sie bitte [_1]zurÃ¼ck[_2] und versuchen Sie es erneut.","<a href=\"$path_prefix/$config->{users_loc}/$config->{registrations_loc}.html\">","</a>"));
        }
    }

    my $registrationid = $user->add_confirmation_request({username => $username, password => $password1});

    # Bestaetigungsmail versenden

    my $afile = "an." . $$;

    my $subject = $msg->maketext("Bestaetigen Sie Ihre Registrierung");

    my $mainttdata = {        
                      registrationid => $registrationid,
                      view           => $view,
                      config         => $config,
		      msg            => $msg,
		      servername     => $self->param('servername'),
		      path_prefix    => $self->param('path_prefix'),
		     };

    my $maintemplate = Template->new({
        LOAD_TEMPLATES => [ OpenBib::Template::Provider->new({
            INCLUDE_PATH   => $config->{tt_include_path},
            ABSOLUTE       => 1,
        }) ],
        #        ABSOLUTE      => 1,
        #        INCLUDE_PATH  => $config->{tt_include_path},
        # Es ist wesentlich, dass OUTPUT* hier und nicht im
        # Template::Provider definiert wird
        RECURSION      => 1,
        OUTPUT_PATH   => '/tmp',
        OUTPUT        => $afile,
    });

    $maintemplate->process($config->{tt_users_registrations_mail_message_tname}, $mainttdata ) || do { 
        $logger->error($maintemplate->error());
        $self->header_add('Status','400'); # Server Error
        return;
    };

    my $mailmsg = MIME::Lite->new(
        From            => $config->{contact_email},
        To              => $username,
        Subject         => $subject,
        Type            => 'multipart/mixed'
    );

    my $anschfile="/tmp/" . $afile;

    $mailmsg->attach(
        Type            => 'TEXT',
        Encoding        => '8bit',
	Path            => $anschfile,
    );
  
    $mailmsg->send('sendmail', "/usr/lib/sendmail -t -oi -f$config->{contact_email}");

    # TT-Data erzeugen
    my $ttdata={
        username      => $username,
    };

    return $self->print_page($config->{tt_users_registrations_confirmation_tname},$ttdata);
}

sub register {
    my $self = shift;

    # Log4perl logger erzeugen
    my $logger = get_logger();
    
    # Dispatched Args
    my $view           = $self->param('view')           || '';
    my $registrationid = $self->strip_suffix($self->param('registrationid')) || '';

    # Shared Args
    my $query          = $self->query();
    my $r              = $self->param('r');
    my $config         = $self->param('config');    
    my $session        = $self->param('session');
    my $user           = $self->param('user');
    my $msg            = $self->param('msg');
    my $queryoptions   = $self->param('qopts');
    my $stylesheet     = $self->param('stylesheet');    
    my $useragent      = $self->param('useragent');
    my $path_prefix    = $self->param('path_prefix');
    

    my $client_ip = "";
    # Wenn der Request ueber einen Proxy kommt, dann urspruengliche
    # Client-IP setzen
    if ($r->header('X-Forwarded-For') =~ /([^,\s]+)$/) {
        $client_ip = $1; # $r->connection->remote_ip($1);
    }

    # ab jetzt ist klar, dass es den Benutzer noch nicht gibt.
    # Jetzt eintragen und session mit dem Benutzer assoziieren;

    my $confirmation_info_ref = $user->get_confirmation_request({registrationid => $registrationid});

    my $username         = $confirmation_info_ref->{username};
    my $hashed_password  = $confirmation_info_ref->{password};

    if ($username && $hashed_password){

      # Wurde dieser Nutzername inzwischen bereits registriert?
      if ($user->user_exists($username)) {
        return $self->print_warning($msg->maketext("Ein Benutzer mit dem Namen [_1] existiert bereits. Haben Sie vielleicht Ihr Passwort vergessen? Dann gehen Sie bitte [_2]zurück[_3] und lassen es sich zumailen.","$username","<a href=\"http://$r->get_server_name$path_prefix/$config->{users_loc}/$config->{registrations_loc}.html\">","</a>"));
      }

      # OK, neuer Nutzer -> eintragen
      $user->add({
		  username         => $username,
		  hashed_password  => $hashed_password,
		  email            => $username,
		 });

      # An dieser Stelle darf zur Bequemlichkeit der Nutzer die Session 
      # nicht automatisch mit dem Nutzer verknuepft werden (=automatische
      # Anmeldung), dann dann ueber das Ausprobieren von Registrierungs-IDs 
      # Nutzer-Identitaeten angenommen werden koennten.
      
      $user->clear_confirmation_request({ registrationid => $registrationid });
    }
    else {
      return $self->print_warning($msg->maketext("Diese Registrierungs-ID existiert nicht."));
    }

    # TT-Data erzeugen
    my $ttdata={
        username   => $username,
    };

    return $self->print_page($config->{tt_users_registrations_success_tname},$ttdata);
}

1;
