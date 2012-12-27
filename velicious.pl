use Mojolicious::Lite;  
use Mojo::JSON;
use Mojolicious::Sessions;

use MIME::Base64;
use Digest::MD5 qw/md5_hex/;
use Switch;
use Data::Dumper;

use File::Basename;
use FindBin qw($Bin);
use lib "$Bin/lib";
use subs qw/analyze/;
use Schema;

use Velicious;

# $ENV{DBIC_TRACE}=1;  # If mode == Dev
my $basename = basename $0, '.pl';
plugin Config => {
	default => {
		db => {
			db => $basename,
			host => 'localhost',
			user => $basename,
			pass => $basename,
		},
	}
};
app->config(hypnotoad => {pid_file=>"$Bin/../.$basename", listen=>[split ',', $ENV{MOJO_LISTEN}||'http://*,https://*'], proxy=>$ENV{MOJO_REVERSE_PROXY}||1});
app->sessions->default_expiration(60*60*24*365);

helper db => sub { Schema->connect({dsn=>"DBI:mysql:database=".app->config->{db}->{db}.";host=".app->config->{db}->{host},user=>app->config->{db}->{user},password=>app->config->{db}->{pass}}) };
helper json => sub {
	my $self = shift;
	#warn Dumper({body => $self->req->body});
	unless ( $self->{__JSON} ) {
		my $json = new Mojo::JSON;
		$self->{__JSON} = $json->decode($self->req->body);
	}
	#warn Dumper({json => $self->{__JSON}});
	return $self->{__JSON}||{};
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

under '/v' => sub { shift->is_user_authenticated };
get '/' => sub {
	my $self = shift;
	my %filter = filter(map { $_ => $self->param($_) } grep { $self->param($_) } qw/label uuid pg pn s/);
	switch ( $self->req->is_xhr ) {
		case 0 {
			$self->respond_to(
				html => {template => 'v'},
			);
		}
		case 1 {
			$self->respond_to(
				json => {json => {localtime=>scalar localtime, page=>1, pages=>1, records=>110, data=>[app->db->resultset('MyTests')->search({email=>$self->current_user->email, %filter}, {order_by=>'label,sn,pg_sort,pn_sort'})->all]}},
			);
		}
	}
};

under '/ws';
websocket '/' => sub {
	# This sub does not generate commands.
	# Commands come either from POSTs or from the agent itself -- that's IT!
	my $self = shift;
	my $velicious = new Velicious({db=>$self->db, tx=>$self->tx});
	$velicious->secret(app->secret);
	$self->on(error => sub { warn "Error: $_[1]" });
	$self->on(message => sub { $velicious->recv($_[1]) });
	$self->on(finish => sub { $velicious->disconnect("Server disconnected") });
};

# curl -i --data-ascii '[{"agent":["abe78b76-2200-4a50-801b-522ef9f56e13"]}]' http://dev.velicio.us/ws/eval/version
post '/eval/:eval' => sub {
	my $self = shift;
	my $json = new Mojo::JSON;
	my $req = $self->json;
	$req = ref $req eq 'HASH' ? [$req] : undef unless ref $req eq 'ARRAY';
	my $res = {
		total => 0,
		ok => 0,
		err => 0,
	};
	foreach ( grep { exists $_->{devices} && ref $_->{devices} eq 'ARRAY' } @$req ) {
		warn Dumper({velicio_req=>$_});
		$res->{total} = $#{$_->{devices}}+1;
		foreach my $device ( @{$_->{devices}} ) {
			warn "Looking up device: $device\n";
			if ( $device = $self->db->resultset('Device')->find($device) ) {
				if ( my $v = new Velicious(''.$device->agent) ) {
					warn "Agent is ", $device->agent, " and connected (", $v->id, "); sending command ", $self->param('eval'), "\n";
					$v->queue({
						cinfo=>$device->cinfo,
						config=>undef,
					});
					# Manage packages, execute arbitary code, reboot, restart agent, disconnect agent, ping, upgrade agent
					$res->{ok}++;
				} else {
					warn "Agent is ", $device->agent, " but is not connected\n"
				}
			} else {
				warn "Device record not found\n";
			}
		}
	}
	$res->{err} = $res->{total} - $res->{ok};
	$self->render_json({res=>($res->{ok}==$res->{total}?'ok':'err'),msg=>"$res->{err} errors of $res->{total}"});
};

app->start;


sub filter {
	my %filter = @_;
	return %filter;
}

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
<title>Velicious</title>

<link   href="http://ajax.googleapis.com/ajax/libs/jqueryui/1.8/themes/base/jquery-ui.css" type="text/css" rel="stylesheet" media="all" />
<script src="http://ajax.googleapis.com/ajax/libs/jquery/1.8/jquery.min.js" type="text/javascript"></script>
<script src="http://ajax.googleapis.com/ajax/libs/jqueryui/1.9.1/jquery-ui.min.js" type="text/javascript"></script>
<script src="/s/jquery-jtemplates_uncompressed.js" type="text/javascript"></script>

<style>
* {font-family:verdana;font-size:12px}
table {border-collapse:collapse}
th {background-color:gray}
th,td {padding:0px 5px 0px 5px;margin:0px 5px 0px 5px}
td {vertical-align:top}
td.ageWARN {padding:0px 3px 0px 3px;border:2px solid yellow;border-width: 0px 2px 2px 0px;margin:0px 5px 0px 5px}
td.ageALERT {padding:0px 3px 0px 3px;border:2px solid red;border-width: 0px 2px 2px 0px;margin:0px 5px 0px 5px}
.expand {cursor:pointer}
.color {background-color:purple}
.INFO {background-color:lightgray}
.OK {background-color:green}
.WARN {background-color:yellow}
.ALERT {background-color:red}
</style>
<script type="text/javascript">
$(document).ready(function(){
   var sl = new Object();
   var statuses = new Object();
   statuses = {NONE:0, INFO:1, OK:2, WARN:3, ALERT:4, UNDEF:5};
   $("#data").setTemplateElement("tData", null, {runnable_functions: true}).processTemplateStart("", null, 300000, $("#filter").serialize(), {
      headers: {  
        Accept : "application/json; charset=utf-8"
      },
      on_success: function(){
        $('#datatable tr td[name="status"]').each(function(){
            var status = $(this).html();
            $(this).parent().find(".color").addClass(status);
        });
        $('#datatable tr td.labelcolor.head').each(function(){
            var label=$(this).html().replace(/\W/g, '');
            sl[label] = 'NONE';
            $('#datatable tr td[name="status"]['+label+']').each(function(i){
                var s=$(this).html();
                if ( statuses[s] > statuses[sl[label]] ) {
                    sl[label]=s;
                }
            });
            $(this).addClass(sl[label]);
        });
        $('#datatable tr td.sncolor.head').each(function(){
            var sn=$(this).html().replace(/\W/g, '');
            sl[sn] = 'NONE';
            $('#datatable tr td[name="status"]['+sn+']').each(function(i){
                var s=$(this).html();
                if ( statuses[s] > statuses[sl[sn]] ) {
                    sl[sn]=s;
                }
            });
            $(this).addClass(sl[sn]);
        });
        $('#datatable tr td.pgcolor.head').each(function(){
            var pg=$(this).html().replace(/\W/g, '');
            sl[pg] = 'NONE';
            $('#datatable tr td[name="status"]['+pg+']').each(function(i){
                var s=$(this).html();
                if ( statuses[s] > statuses[sl[pg]] ) {
                    sl[pg]=s;
                }
            });
            $(this).addClass(sl[pg]);
        });
        $('#datatable tr td[name="details"]').each(function(){
            $(this).toggle(function(){
                $(this).find('div').show();
                $(this).find('img').attr({src:"collapse.gif"});
            }, function(){
                $(this).find('div').hide();
                $(this).find('img').attr({src:"expand.gif"});
            });
        });
      }
   });
    $("#btnfilter").click(function(){
        $.get("<%= url_for 'filter' %>", $("#filter").serialize(), function(data){
            console.log(data);
            if ( data.response == "ok" ) {
                $("#admin-msg").addClass('ok').removeClass('err').html(data.message).show().delay(2500).fadeOut();
            } else {
                $("#admin-msg").addClass('err').removeClass('ok').html(data.message).show().delay(2500).fadeOut();
            }
        });
    });

    $("a.button").button();
});
</script>
</head>
<body>
  Velicious <%= config 'version' %><br />
  Filter:<br />
  <form id="filter" action="<%= url_for %>">
  <table>
    <tr><td>Label:</td><td><input type="text" name="label" value="<%= param 'label' %>" /></td></tr>
    <tr><td>Property Group:</td><td><input type="text" name="pg" value="<%= param 'pg' %>" /></td></tr>
    <tr><td>Property Name:</td><td><input type="text" name="pn" value="<%= param 'pn' %>" /></td></tr>
    <tr><td>status:</td><td><input type="text" name="s" value="<%= param 's' %>" /></td></tr>
    <tr><td colspan="2"><input type="submit" value="Filter" /></td></tr>
  </table>
  </form>
  <hr />
  <div id="data" class="Content"></div>

<!-- Templates -->
    <p style="display:none"><textarea id="tData" rows="0" cols="0"><!--
    {$T.localtime}
    <table id="datatable">
      {#foreach $T.data as r}
        {#if $T.r$index == 0 || $T.r.label != $T.data[$T.r$index-1].label}
        <tr>
          <th>Label</th>
          <th>System Name</th>
          <th class="CellDecimal">Property Group</th>
          <th>Property Name</th>
          <th>Status</th>
          <th>%-OK</th>
          <th>Time on Status</th>
          <th>Value</th>
          <th>Details</th>
        </tr>
        {#else}
          {#if $T.r$index == 0 || $T.r.sn != $T.data[$T.r$index-1].sn}
          <tr>
            <td>&nbsp;</td>
            <th>System Name</th>
            <th class="CellDecimal">Property Group</th>
            <th>Property Name</th>
            <th>Status</th>
            <th>%-OK</th>
            <th>Time on Status</th>
            <th>Value</th>
            <th>Details</th>
          </tr>
          {#/if}
        {#/if}
        <tr class="{#cycle values=['bcEED','bcDEE']}">
          <td class="age{$T.r$index == 0 || $T.r.label != $T.data[$T.r$index-1].label ? $T.r.age : ''} labelcolor {$T.r$index == 0 || $T.r.label != $T.data[$T.r$index-1].label ? 'head' : ''}">{$T.r$index == 0 || $T.r.label != $T.data[$T.r$index-1].label ? $T.r.label : '&nbsp;'}</td>
          <td class="age{$T.r$index == 0 || $T.r.sn != $T.data[$T.r$index-1].sn ? $T.r.age : ''} sncolor {$T.r$index == 0 || $T.r.sn != $T.data[$T.r$index-1].sn ? 'head' : ''}">{$T.r$index == 0 || $T.r.sn != $T.data[$T.r$index-1].sn ? $T.r.sn : '&nbsp;'}</td>
          <td class="age{$T.r$index == 0 || $T.r.sn != $T.data[$T.r$index-1].sn ? $T.r.age : ''} pgcolor {$T.r$index == 0 || $T.r.pg != $T.data[$T.r$index-1].pg ? 'head' : ''}">{$T.r$index == 0 || $T.r.pg != $T.data[$T.r$index-1].pg ? $T.r.pg : '&nbsp;'}</td>
          <td class="age{$T.r.age} color">{$T.r.pn}</td>
          <td class="age{$T.r.age} color" name="status" {$T.r.sn.replace(/\W/g, '')}="{$T.r.s}" {$T.r.pg.replace(/\W/g, '')}="{$T.r.s}">{$T.r.s}</td>
          <td class="age{$T.r.age} color">{#if $T.r.s != "INFO"}{$T.r.ok}{#/if}</td>
          <td class="age{$T.r.age} color">{#if $T.r.s != "INFO"}{$T.r.t==null?'':$T.r.t}{#/if}</td>
          <td class="age{$T.r.age} color">{$T.r.n==null?'&nbsp;':$T.r.n}</td>
          {#if $T.r.l == null}
            <td class="age{$T.r.age} color" name="details"><img src="/blank.gif" width="11" height="11" /></td>
          {#elseif $T.r.l.indexOf('\n')>=3}
            <td class="age{$T.r.age} color expand" name="details"><img src="/expand.gif" />
              {$T.r.y == null || $T.r.y == "" ? $T.r.l.substr(0,$T.r.l.indexOf('\n')<3?80:$T.r.l.indexOf('\n')) : $T.r.y}
              <div style="display:none" name="fulltext"><pre>{$T.r.l}</pre></div>
            </td>
          {#else}
            <td class="age{$T.r.age} color" name="details"><img src="/blank.gif" width="11" height="11" />
              {$T.r.y == null || $T.r.y == "" ? $T.r.l.substr(0,$T.r.l.indexOf('\n')<3?80:$T.r.l.indexOf('\n')) : $T.r.y}
            </td>
          {#/if}
        </tr>
      {#/for}
      <tr>
        <th>Label</th>
        <th>System Name</th>
        <th class="CellDecimal">Property Group</th>
        <th>Property Name</th>
        <th>Status</th>
        <th>%-OK</th>
        <th>Time on Status</th>
        <th>Value</th>
        <th>Details</th>
      </tr>
    </table>
  --></textarea></p>
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

@@ expand.gif (base64)
R0lGODlhCwALAIAAAAAAAPj8+CH5BAAAAAAALAAAAAALAAsAAAIVhI8Wy6zd
3gKRujpRjvg6C21hliQFADs=

@@ collapse.gif (base64)
R0lGODlhCwALAIAAAAAAAPj8+CH5BAAAAAAALAAAAAALAAsAAAIUhI8Wy6zd
HlxyvkTBdHqHCoFRQhYAOw==

@@ blank.gif (base64)
R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAQAIBRAA7

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
#PROPERTYGROUP="Tests"
#ForceStatus TestOK OK
#ForceStatus TestWARN WARN
#ForceStatus TestALERT ALERT

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
#HDCheck /data	10000	5000	# system disk: 1GB /  500MB  - warn / alert (MByte)

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
