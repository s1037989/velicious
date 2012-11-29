# $ ps axf | perl -MJSON::Any -MMIME::Base64 -e '$/=undef; print JSON::Any->to_json({map{@_=split/=/,$_,2;$_[0]=>$_[1]}@ARGV}), "\n", encode_base64(<STDIN>), "\n"' pg="System Information" pn="ps axf" s="INFO" >> /tmp/a.txt
# $ env VELITE_COOKIE=${VELITE_COOKIE:-$(mktemp)} curl -b $VELITE_COOKIE -c $VELITE_COOKIE -X POST --data-binary @/tmp/a.txt http://localhost:3003

use constant VERSION => '12.10.30';

use Mojolicious::Lite;  
use Mojolicious::Sessions;
use Mojo::JSON;

my $sessions = Mojolicious::Sessions->new;
$sessions->cookie_name('velicious');
$sessions->default_expiration(60*60*24*365);

use MIME::Base64;
use UUID::Tiny;
use Digest::MD5 qw/md5_hex/;
use Data::Dumper;

use FindBin qw($Bin);
use lib "$Bin/lib";
use subs qw/analyze/;
use Schema;

# $ENV{DBIC_TRACE}=1;  # If mode == Dev
app->config(hypnotoad => {pid_file=>$Bin.'/../.velicious', listen=>['http://*:3003'], proxy=>1}, minver => '12.10.30', version => '12.10.30');
helper db => sub { Schema->connect({dsn=>'DBI:mysql:database=velite;host=localhost',user=>'velite',password=>'velite'}) };
helper upgrade => sub {
	my $self = shift;
	my $name = shift;
	return $self->{__UPGRADE} if $self->{__UPGRADE};
	my ($current) = ($self->req->headers->user_agent =~ /^$name\/(\S+)/);
	my $_current = $current;
	my $_min = $self->app->config->{minver};
	my $_latest = $self->app->config->{version};
	$_current =~ s/\D//g;
	$_min =~ s/\D//g;
	$_latest =~ s/\D//g;
	$self->{__UPGRADE} = {
		min => $self->app->config->{minver},
		latest => $self->app->config->{version},
		current => $current,
		can_upgrade => $_current < $_latest ? 1 : 0,
		must_upgrade => $_current < $_min ? 1 : 0,
		url => 'http://use.velicio.us',
	};
	#warn Dumper($self->{__UPGRADE});
	return $self->{__UPGRADE};
};
plugin 'HeaderCondition';
plugin 'IsXHR';
plugin 'authentication' => {
	'autoload_user' => 1,
	'session_key' => 'fifdhiwfiwhgfyug38g3iuhe8923oij20',
	'load_user' => sub {
		my ($self, $email) = @_;
		return $self->db->resultset('User')->find({email=>$email});
	},
	'validate_user' => sub {
		my ($self, $email, $password, $extradata) = @_;
		return undef unless defined $email;
		return $email if $self->db->resultset('User')->single({email=>$email, password=>md5_hex($password)});
		return undef;
	},
	#'current_user_fn' => 'user', # compatibility with old code
};
plugin 'authorization', {
	has_priv => sub {
		my ($self, $priv, $extradata) = @_;
		return 0 unless $self->current_user && $self->current_user->role;
		return 1 if $priv eq $self->current_user->role;
		return 0;
	},
	is_role => sub {
		my ($self, $role, $extradata) = @_;
		return 0 unless $self->current_user && $self->current_user->role;
		return 1 if $role eq $self->current_user->role;
		return 0;
	},
	user_privs => sub {
		my ($self, $extradata) = @_;
		return [] unless $self->current_user && $self->current_user->role;
		return $self->current_user->role;
	},
	user_role => sub {
		my ($self, $extradata) = @_;
		return '' unless $self->current_user && $self->current_user->role;
		return $self->current_user->role;
	},
};

# TODO: HeaderCondition host -> X-Forwarded-Host||Host
#get '/' => (host => qr/^use\.velicio\.us$/) => 'get-velicio';
#get '/' => (host => qr/^get\.velicio\.us$/) => 'get-velicious';
get '/' => [format => 0] => (headers => {'X-Forwarded-Host' => qr/^use\.velicio\.us$/}) => {format=>'text', template=>'get-velicio'};
get '/' => [format => 0] => (headers => {'X-Forwarded-Host' => qr/^get\.velicio\.us$/}) => {format=>'text', template=>'get-velicious'};
get '/' => 'index';

any '/login' => sub {
	my $self = shift;
	if ( $self->param('email') && $self->param('password') ) {
		return $self->redirect_to($self->session->{'requested_page'}||'/') if $self->authenticate($self->param('email'), $self->param('password'));
		$self->stash(denied => 1);
	}
} => 'login';
get '/logout' => sub {$_[0]->stash(is_user_authenticated => $_[0]->is_user_authenticated)} => 'logout';

post '/' => (agent => qr/^Velicio/) => sub {
	my $self = shift;
	return $self->render_json({upgrade => $self->upgrade('Velicio')}) if $self->upgrade('Velicio')->{must_upgrade};
	$self->session->{uuid} ||= create_UUID_as_string(UUID_V4);
	local $/ = undef;
	my @dt = localtime; $dt[4]++; $dt[5]+=1900;
	my $dt = sprintf("%04d-%02d-%02d %02d:%02d:%02d", reverse @dt[0..5]);
	# TODO: Set first run
	my @data = split /\n\n/, $self->req->body;
	my $record = Mojo::JSON->decode(shift @data);
	my $time_offset = time - ($record->{dt}||time); # account for time zones
	my $this = $self->db->resultset('System')->find_or_create({uuid=>$self->session->{uuid}, create_dt=>$dt});
	my $prev = $self->db->resultset('System')->find({uuid=>$self->session->{uuid}, dt=>$this->dt});
	my $sn_change = $prev->sn eq $record->{sn};
	$this->update({dt=>$dt, sn=>$record->{sn}});
	foreach ( @data ) {
		my ($tests, $details, $vals) = analyze split /\n/, $_, 2 or next;
		my $test = $self->db->resultset('Test')->find_or_create({uuid=>$self->session->{uuid}, %{$tests}});
		$test->update({last_dt=>$dt, %{$details}});
		$self->db->resultset('Val')->create({test_id=>$test->test_id, dt=>$dt, %{$vals}});
	}
	return $self->render_json({
		at => [],
		upgrade => $self->upgrade('Velicio')->{can_upgrade} ? $self->upgrade('Velicio') : undef,
	});
};

get '/conf/:conf' => {conf => 'remote'} => sub {
	my $self = shift;
	$self->session->{uuid} ||= create_UUID_as_string(UUID_V4);
	my $conf = $self->db->resultset('System')->find({uuid=>$self->session->{uuid}});
	return $self->render('conf', format=>'text', conf=>defined $conf ? $conf->conf : '');
};

under '/v' => sub { shift->is_user_authenticated };
get '/' => sub {
	my $self = shift;
	$self->stash(format => 'json') if $self->req->is_xhr;
	$self->respond_to(
		json => {json => {page=>1, pages=>1, records=>110, data=>[app->db->resultset('MyTests')->search(\['email=?', ['email', $self->current_user->email]])->all]}},
		html => {template => 'v'},
	);
};
get '/:uuid' => sub {
	my $self = shift;
	$self->render_json([app->db->resultset('MyTests')->search(\['email=? and uuid=?', ['email', $self->current_user->email], ['uuid', $self->param('uuid')]])->all]);
};
get '/:uuid/:pg' => sub {
	my $self = shift;
	$self->render_json([app->db->resultset('MyTests')->search(\['email=? and uuid=? and pg=?', ['email', $self->current_user->email], ['uuid', $self->param('uuid')], ['pg', $self->param('pg')]])->all]);
};
get '/:uuid/:pg/:pn' => sub {
	my $self = shift;
	$self->render_json([app->db->resultset('MyTests')->search(\['email=? and uuid=? and pg=? and pn=?', ['email', $self->current_user->email], ['uuid', $self->param('uuid')], ['pg', $self->param('pg')], ['pn', $self->param('pn')]])->all]);
};

app->start;

sub lines {
	my $l = shift;
	return 0;
}

sub analyze {
	my ($json, $body) = @_;
	return undef unless $json;
	$json = Mojo::JSON->decode($json);
	return undef unless $json->{'pg'} && $json->{'pn'};
	$json->{'l'} = decode_base64($body) if $body;
	$json->{'l'} =~ s/\s*$// if $json->{'l'};
	my $_l = lines($json->{'l'}) if $json->{'l'};
	$json->{'y'} =~ s/_/$_l/g if $_l && $json->{'y'};
	return {pg => $json->{'pg'}, pn => $json->{'pn'}}, {'y' => $json->{'y'}, l => $json->{'l'}}, {'s' => $json->{'s'}||'INFO', n => $json->{'n'}};
}

__DATA__

@@ v.html.ep
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<title>My First Grid</title>

<script src="http://ajax.googleapis.com/ajax/libs/jquery/1.8/jquery.min.js" type="text/javascript"></script>
<script src="http://jtemplates.tpython.com/jTemplates/jquery-jtemplates.js" type="text/javascript"></script>

<style>
.INFO {background-color:white}
.OK {background-color:green}
.WARN {background-color:yellow}
.ALERT {background-color:red}
</style>
<script type="text/javascript">
$(document).ready(function(){
   $("#data").setTemplateElement("tData").processTemplateURL("", null, {
      on_success: function(){
        $('#datatable tr td[name="status"]').each(function(){
            var status = $(this).html();
            $(this).parent().find(".color").addClass(status);
        });
        $('#datatable tr td[name="details"]').each(function(){
            $(this).toggle(function(){
                $(this).find('div').show();
            }, function(){
                $(this).find('div').hide();
            });
        });
      }
   });
});
</script>
</head>
<body>
<!-- Templates -->
    <p style="display:none"><textarea id="tData" rows="0" cols="0"><!--
    <table id="datatable">
      <tr>
        <td class="header">Timestamp</td>
        <td class="header">System Name</td>
        <td class="header CellDecimal">Property Group</td>
        <td class="header">Property Name</td>
        <td class="header">Status</td>
        <td class="header">Value</td>
        <td class="header">Details</td>
      </tr>
      {#foreach $T.data as r}
        <tr class="{#cycle values=['bcEED','bcDEE']}">
          <td class="dtcolor">{$T.r$index == 0 || $T.r.dt != $T.data[$T.r$index-1].dt ? $T.r.dt : '&nbsp;'}</td>
          <td class="sncolor">{$T.r$index == 0 || $T.r.sn != $T.data[$T.r$index-1].sn ? $T.r.sn : '&nbsp;'}</td>
          <td class="pgcolor"}">{$T.r$index == 0 || $T.r.pg != $T.data[$T.r$index-1].pg ? $T.r.pg : '&nbsp;'}</td>
          <td class="color">{$T.r.pn}</td>
          <td class="color" name="status">{$T.r.s}</td>
          <td class="color">{$T.r.n==null?'&nbsp;':$T.r.n}</td>
          <td class="color" name="details">{$T.r.y == null || $T.r.y == "" ? $T.r.l.substr(0,$T.r.l.indexOf('\n')<3?80:$T.r.l.indexOf('\n')) : $T.r.y}{#if $T.r.l.indexOf('\n')>=3}<div style="display:none" name="fulltext"><pre>{$T.r.l}</pre></div>{#/if}</td>
        </tr>
      {#/for}
    </table>
  --></textarea></p>

  <!-- Output elements -->
  <div id="data" class="Content"></div>
</body>
</html>

@@ oldv.html.ep
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<title>My First Grid</title>
 
<link   href="http://ajax.googleapis.com/ajax/libs/jqueryui/1.8/themes/base/jquery-ui.css" type="text/css" rel="stylesheet" media="all" />
<link   href="/s/css/ui.jqgrid.css" rel="stylesheet" type="text/css" media="screen" />      

<script src="http://ajax.googleapis.com/ajax/libs/jquery/1.8/jquery.min.js" type="text/javascript"></script>
<script type="text/javascript" src="/s/js/i18n/grid.locale-en.js"></script>
<script type="text/javascript" src="/s/js/jquery.jqGrid.min.js"></script>
 
<script type="text/javascript">
$(document).ready(function(){
  $("#44remote3").jqGrid({
          url:'',
          datatype: "json",
   jsonReader : {
      root:"data",
      page: "page",
      total: "pages",
      records: "records",
      repeatitems: false,
      id: "0"
   },
          colNames:['ID', 'System Name', 'Property Group','Property Name','Timestamp','Status', 'Value', 'Details'],
          colModel:[
                  {name:'test_id',index:'test_id', width:90},
                  {name:'sn',index:'sn', width:90},
                  {name:'pg',index:'pg', width:100},
                  {name:'pn',index:'pn', width:250},
                  {name:'dt',index:'dt', width:160},
                  {name:'s',index:'s', width:50},
                  {name:'n',index:'n', width:50, sortable:false,editable:false},
                  {name:'y',index:'y', width:450, sortable:false,editable:false}
          ],
          rowNum:200,
          rowList:[10,20,30],
          height: 'auto',
          pager: '#p44remote3',
          sortname: 'sn', 
      viewrecords: true,
      sortorder: "desc",
      caption:"Grouping with remote data",
      grouping: true,
          groupingView : {
                  groupField : ['sn', 'pg'],
                  groupColumnShow : [false, false],
                  groupText : ['<b>{0}</b> Sum of totaly: {total}', '{0} Sum'],
                  groupCollapse : true,
                  groupOrder: ['asc', 'asc'],
                  groupSummary : [false, false]
          }
  }); 
  $("#44remote3").jqGrid('navGrid','#p44remote3',{add:false,edit:false,del:false});
});

</script>
</head>
<body>
<%= scalar localtime %>
<table id="44remote3"></table>
<div id="p44remote3"></div>   
</body>
</html>

@@ index.html.ep
% if ( $self->current_user ) {
    Welcome, <%= $self->current_user->email %><br />
% }
<a href="<%= url_for 'login' %>">Login</a>

@@ login.html.ep
% if ( stash 'denied' ) {
    Access Denied<br />
% }
%= form_for '/login' => (method=>'POST') => begin
E-mail: <%= text_field 'email' %><br />
Password: <%= password_field 'password' %><br />
%= submit_button 'login', name=>'Login'
% end

@@ logout.html.ep
% if ( stash 'is_user_authenticated' ) {
    % $self->logout; 
    Logged out.<br />
% } else {
    Not logged in.<br />
% }
%= link_to Login => 'login'

@@ denied.html.ep
DENIED

@@ get-velicio.text.ep
#!/bin/sh
sudo rm -rf /etc/cemosshe* /usr/local/lib/cemosshe* /etc/cron.d/cemosshe /etc/cron.daily/*-cemosshe /tmp/cemosshe* /var/lib/cemosshe* /var/run/cemosshe*
sudo apt-get -y install libjson-perl libjson-any-perl libschedule-at-perl libfile-touch-perl
# How to remove old files that are no longer used by Velicio?
curl -f -s http://velicio.us/s/velicio.tar.gz | tar xz -C /tmp
dir=$(pwd)
cd /tmp/velicio-*
make test && sudo make install
cd $dir

@@ get-velicious.text.ep
#!/bin/sh
#curl -f -s http://velicio.us/d/velicious.tar.gz | sudo tar xz -C /tmp
echo get velicio.us

@@ conf.text.ep
% if ( $self->param('conf') eq 'local' ) {
# v12.10.27
% } elsif ( $self->param('conf') eq 'remote' && $conf ) {
<%= $conf %>
% } elsif ( $self->param('conf') eq 'remote' ) {
# v12.10.27

#=========================================================
# local shows
#=========================================================

#= System Info ===========================================
PROPERTYGROUP="System Info"
VelicioInfo


#=========================================================
# local checks
#=========================================================

#= Test ==================================================
PROPERTYGROUP="Tests"
ForceStatus TestOK OK
ForceStatus TestWARN WARN
ForceStatus TestALERT ALERT

#= Snapshots =============================================
#PROPERTYGROUP="Snapshots"
#SnapshotsCheck /backup/snapshots 2 5 2 5     # /path/to/snapshots lastrunwarn lastrunalert lastokwarn lastokalert

#= System Checks =========================================
PROPERTYGROUP="System Checks"
HostsFileCheck
StaticIPCheck
DaysUpCheck 10 3	# days up less than: warn / alert (days)

UpdatesAvailable
ReleaseUpgrade
RebootRequired

HDCheck /	1000	500	# system disk: 1GB /  500MB  - warn / alert (MByte)
HDCheck /boot	100	50	# system disk: 1GB /  500MB  - warn / alert (MByte)
HDCheck /data	10000	5000	# system disk: 1GB /  500MB  - warn / alert (MByte)

LoadCheck 1 3		# load: warn / alert
MemCheck 300 100	# free mem: warn / alert (MByte)
#SwapCheck 30 100	# page swaps / second : warn / alert

ProcessCheck 120 200	# processes: warn / alert
ZombieCheck 3 10	# zombies: warn / alert
ShellCheck 0 3		# shells: max.root, max.user

#NetworkErrorsCheck eth0  1 5		# percentage of errors on interface
#NetworkTrafficCheck eth0  50000 80000	# kbit/s average

# check "sensors" output for matching strings on your hardware 
# (second parameter MUST NOT contain space characters)
#HardwareSensor "CHASSIS FAN Speed" Chassis_Fan_Description 6500 7500
#HardwareSensor "CPU Temperature" CPU_Temp_descriptive_text 45 60

# check ClamAV-Daemon which likes to crash
#FileCheck /var/run/clamav/clamd.ctl
#ProcCheck /usr/sbin/clamd

# files growing too old or large
#FileTooOld /var/log/syslog 90           # file older than 90 minutes
#FileTooOld /var/log/backup.log 1500   # file older than 90 minutes
#FileTooOld /backup/mysql.sql 86400     # Last mysqldump MySQL backup older than 1 day
#FileTooOld /backup/ldap.ldif 86400     # Last ldapsearch or slapcat LDAP backup older than 1 day
#
#FileTooBig /var/log/auth 9000          # file bigger than 9,000 KBytes (= 9 MB)
#FileTooBig /var/log/syslog 500000       # file bigger than 9,000 KBytes (= 9 MB)

#MailqCheck 20 60

#= IDS ===================================================
PROPERTYGROUP="IDS"
#LogEntryCheck HTTPbruteforce	' 401 ' '/var/log/apache/*access.log' 100 200		# make sure we don't get HTTP bruteforced
#LogEntryCheck HTTPbruteforce	' 401 ' '/var/log/lighttpd/*access.log' 700 1000		# make sure we don't get HTTP bruteforced
#LogEntryCheck ImapBruteforce	'authdaemond: pam_unix(imap:auth): authentication failure' /var/log/auth.log 10 50     	# we don't like IMAP/Webmail bruteforcing either
#LogEntryCheck Pop3Bruteforce	'authdaemond: pam_unix(pop3:auth): authentication failure' /var/log/auth.log 10 50     	# we don't like IMAP/Webmail bruteforcing either
#LogEntryCheck VsFtpdBruteforce	'pam_unix(vsftpd:auth): authentication failure' /var/log/auth.log 50 100		# we don't like FTP bruteforcing either

LogEntryCheck TooManySU		'Successful su for ' /var/log/auth.log 50 100		# too many SU changes
LogEntryCheck SuFailed		'FAILED su for' /var/log/auth.log 5 10			# SU should not fail too often

LogEntryCheck SSHlogin		'Accepted publickey for ' /var/log/auth.log 100 200	# suspiciously many SSH logins
LogEntryCheck SSHbruteforce	'Illegal user ' /var/log/auth.log 3 5			# we don't like SSH bruteforcing

LogEntryCheck OtherBruteforce	'authentication failure' /var/log/auth.log 50 100	# we don't like other (PAM-based) bruteforcing either
#LogEntryCheck SASLusage		'sasl_username' /var/log/mail.log 400 600		# we don't like SMTP-Auth bruteforcing either

# CheckFileChanges  KnownFile stored in $DATADIR/CompareFiles  OriginalFile
CheckFileChanges resolv.conf /etc/resolv.conf
CheckFileChanges hosts /etc/hosts
CheckFileChanges passwd /etc/passwd
CheckFileChanges shadow /etc/shadow
CheckFileChanges group /etc/group 
CheckFileChanges sudoers /etc/sudoers
CheckFileChanges nsswitch.conf /etc/nsswitch.conf
CheckFileChanges authorized_keys /root/.ssh/authorized_keys

# CheckConfigChanges KnownOutputFile stored in $DATADIR/CompareFiles  "command +parameters"
CheckConfigChanges ifconfig.txt "ifconfig | egrep -v -e 'packets|bytes|collisions'"
CheckConfigChanges routing.txt "netstat -nr"
#CheckConfigChanges listeners.txt "netstat -tulpen"
% }

true

#############################################################################
# Velicio: The agent to Velicious
#
# Copyright (C) 2003-2011 Volker Tanger (MoSShE)
# Copyright (C) 2011- Stefan Adams
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# For bug reports and suggestions or if you just want to talk to me please
# contact me at stefan@cogentinnovators.com
#
# Updates will be available at  http://use.velicio.us
# For more information, visit http://velicio.us
# please check there for updates prior to submitting patches!
#
# For list of changes please refer to the HISTORY file. Thanks.
#############################################################################
