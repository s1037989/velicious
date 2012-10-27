# $ ps axf | perl -MJSON::Any -MMIME::Base64 -e '$/=undef; print JSON::Any->to_json({map{@_=split/=/,$_,2;$_[0]=>$_[1]}@ARGV}), "\n", encode_base64(<STDIN>), "\n"' pg="System Information" pn="ps axf" s="INFO" >> /tmp/a.txt
# $ env VELITE_COOKIE=${VELITE_COOKIE:-$(mktemp)} curl -b $VELITE_COOKIE -c $VELITE_COOKIE -X POST --data-binary @/tmp/a.txt http://localhost:3003

use Mojolicious::Lite;  
use Mojo::JSON;

use MIME::Base64;
use UUID::Tiny;
use Data::Dumper;

use FindBin qw($Bin);
use lib "$Bin/lib";
use Schema;

app->config(hypnotoad => {pid_file=>$Bin.'/../.velicious', listen=>['http://*:3003'], proxy=>1});
helper db => sub { Schema->connect({dsn=>'DBI:mysql:database=velite;host=localhost',user=>'velite',password=>'velite'}) };
plugin 'HeaderCondition';

# TODO: HeaderCondition host -> X-Forwarded-Host||Host
#get '/' => (host => qr/^use\.velicio\.us$/) => 'get-velicio';
#get '/' => (host => qr/^get\.velicio\.us$/) => 'get-velicious';
get '/' => [format => 0] => (headers => {'X-Forwarded-Host' => qr/^use\.velicio\.us$/}) => {format=>'text', template=>'get-velicio'};
get '/' => [format => 0] => (headers => {'X-Forwarded-Host' => qr/^get\.velicio\.us$/}) => {format=>'text', template=>'get-velicious'};

post '/' => (agent => qr/^Velicio|^Ce/) => sub {
        my $self = shift;
	$self->session->{uuid} ||= create_UUID_as_string(UUID_V4);
	my @dt = localtime; $dt[4]++; $dt[5]+=1900;
	local $/ = undef;
	if ( $self->req->headers->user_agent =~ / (\{.*?\})$/ ) {
		my $system = Mojo::JSON->decode($1);
		$self->db->resultset('System')->update_or_create({uuid=>$self->session->{uuid}, sn=>$system->{sn}});
	}
	foreach ( split /\n\n/, $self->req->body ) {
		local @_ = split /\n/, $_, 2;
		local $_ = Mojo::JSON->decode($_[0]);
		$_->{'s'} ||= 'INFO';
		$self->db->resultset('Velicious')->create({dt=>sprintf("%04d-%02d-%02d %02d:%02d:%02d", reverse @dt[0..5]), uuid=>$self->session->{uuid}, %{$_}, l=>decode_base64($_[1])});
	}
	return $self->render_json({
		at => [],
	});
};

get '/conf/:conf' => {conf => 'remote'} => sub {
	my $self = shift;
	$self->session->{uuid} ||= create_UUID_as_string(UUID_V4);
	my $conf = $self->db->resultset('System')->find({uuid=>$self->session->{uuid}});
	return $self->render('conf', format=>'text', conf=>defined $conf ? $conf->conf : '');
};

app->start;

__DATA__

@@ get-velicio.text.ep
#!/bin/sh
echo use

@@ get-velicious.text.ep
#!/bin/sh
echo get

@@ conf.text.ep
% if ( $conf ) {
<%= $conf %>
% } elsif ( $self->param('conf') eq 'local' ) {
# v12.10.27
% } elsif ( $self->param('conf') eq 'remote' ) {
# v12.10.27

#=========================================================
# local shows
#=========================================================

#= System Info ===========================================
PROPERTYGROUP="System Info"
CemossheInfo


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

HDCheck /dev/mapper/ubuntu-root 1000 500	# system disk: 1GB /  500MB  - warn / alert (MByte)

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


#=========================================================
# Push results
#=========================================================

PushResults $VELICIOUS
% }


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
