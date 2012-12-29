# TODO: Auto-purge agents and ALL devices, configs, results, history, etc when no users subscribed to the agent (i.e. no agent configs)
# TODO: Compress history by not repeating entries that don't change (will require a new $ok and $t formula)

# The life of an agent:
#   1) Send/Request Registration
#      A) Before registration server checks version (protocol) compatibility
#      B) Server commences Registration
#   2) Receive Messages
#      A) registration -> this should never happen, but if a server doesn't
#         know who an agent it is, it'll ask before allowing anything else
#      B) upgrade -> if agent must_upgrade, no further processing will happen
#         1) if enabled, actually do upgrade and reload (see how CPAN does it)
#      C) code -> agent takes this code and shove it into its memory
#      D) run -> include a list of run statements and configurations for each
#         1) Configs include frequency.  If once, just do it; if recurring,
#            agent puts its code in Mojo::IOLoop->recurring
#   3) Send Response
#      A) Respond to commands, completing the conversation
#      B) Send run results in a structured manner so that the server can process
#         1) Run results can be:
#            a) One-time
#            b) Recurring

# The life of a server:
#   1) Do nothing.  The server does nothing on its own.
#   2) Receive Messages.  From:
#      A) POSTs.  POSTs can send:
#         1) code -> agent takes this code and shove it into its memory
#            a) this code might be pre-saved, available in the DB, or
#            b) it might be supplied code -- type whatever you want! Just remember:
#               1) It will be packaged and it must have a run method available, also
#               2) it makes no sense to consider "protecting" the agent. The fact that
#                  it's SSL and the registration process already provide that protection.
#                  The server is essentially root -- the agent has already agreed to allow
#                  the server to do whatever it wants.
#         2) run -> include a list of run statements and configurations for each
#            a) Configs include frequency.  If once, just do it; if recurring,
#               agent puts its code in Mojo::IOLoop->recurring
#      3) Agents.  Agent can send:
#         [See life of an agent (3)]

# Code can be: literally anything
# Run commands can be: well, literally anything as well, but to actually succeed
#   there must be corresponding pakcages already loaded.

# All-in-all, the point of this Velicio.us suite is that the agent does things (run)
#   and tells the server about it.  The server processes what the agent says.

# The "protocol header", if you will, deals will registration and upgrade only.  From the
#   server's perspective, that's all it cares about.  If the agent passes the registration
#   phase and the version check and then just chills out as a wallflower, that's fine by
#   the server.  MAYBE implement an agent timeout.  Stop wasting my resources!  If you can't
#   figure out what you wanna talk about, go away.  Obviously this would need to flag an alert.

# What we can take away from this is that the agent needs to lead this dance.  A POST
#   can come along like a DJ and change the music, but the agent keeps dancing.

#	Velicio::Base sub run {
	# In:	{
	#		[r]user => {
	#			[o]label => '',
	#			[o]warn => '',
	#			[o]alert => '',
	#			[o]ok => '',  <-- proly no need
	#			[o]info => '',  <-- proly no need
	#			[o]args => [],  <-- If args, calculates results each time; if not, calculates once
	#		},
	#	}
	#
	# Out:	[
	#		{
	#			[r]user,
	#			[r]label,
	#			[r]status,  <-- UNDEF ALERT WARN OK QXFAIL NOINFO INFO
	#			[o]reason,
	#			[o]details,
	#			[o]summary,
	#			[r]package,
	#			[o]value,
	#			[o]extra,
	#		},
	#	]
	# Supported keywords: user, label, status, reason, details, summary, package, value, extra
	# Anything else is ignored, so put what you want in extra
# All that above is the Supporting code, technically it's not necessary at all.  technically you just need a run method in your package
# But, the supporting code will get delivered whether the agent likes it or not, the packages don't have to make use.

               # Received a run configuration
                #    my $run = {
                #       frequency => [
                #          { frequency=>f,id=>'config_id',warn=>'warn',alert=>'alert',pkg=>'pkg',args=>[args] },
                #          { more... },
                #       ],
                #       frequencies => [],
                #     };

package Velicious;

our $VERSION='v12.12.27';
our $AGENT_MINIMUM = 'v12.12.28';
our $AGENT_LATEST = 'v12.12.28';

use version 0.77;
use Scalar::Util 'blessed';
use Digest;
use Data::Serializer;
use Mojo::IOLoop;
use UUID::Tiny;

use Data::Dumper;

my $clients = {};
sub clients {
	if ( $_[0] ) {
		grep { $clients->{$_}->{__REGISTRATION} && ref $clients->{$_}->{__REGISTRATION} eq 'HASH' && $clients->{$_}->{__REGISTRATION}->{agent} eq $_[0] } keys %$clients;
	} else {
		keys %$clients;
	}
}
sub client { my $id = ref $_[0] eq __PACKAGE__ ? $_[1] : $_[0]; bless {id=>$id}, __PACKAGE__ }

sub _unbless {
	my $value = shift;

	if (my $ref = ref $value) {
		return [map { _unbless($_) } @$value] if $ref eq 'ARRAY';
		return {map { $_ => _unbless($value->{$_}) } keys %$value} if $ref eq 'HASH';
		return $value if $ref eq 'SCALAR';
		return ''.$value if blessed $value;
		return undef;
	}
	return $value;
}

sub new {
	my $class = shift;
	if ( ref $_[0] ) { # New agent connection
		Mojo::IOLoop->stream($_[0]->{tx}->connection)->timeout(330);
		my $id = sprintf "%s", $_[0]->{tx};
		warn "Client connected: $id\n";
		$clients->{$id} = $_[0];
		bless {id=>$id}, $class;
	} else { # Find existing agent connection
		my $id = shift;
		($id) = grep { $clients->{$_}->{__REGISTRATION} && $clients->{$_}->{__REGISTRATION}->{agent} eq $id } clients();
		bless {id=>$id}, $class;
	}
}

sub id { shift->{id} }
sub db { $clients->{shift->id}->{db} }

sub secret {
	my $self = shift;
	$self->{__SECRET} = $_[0] if $_[0];
	warn "Your secret passphrase needs to be changed!!!\n" unless $self->{__SECRET};
	return $self->{__SECRET} || ref $self;
}

sub tx {
	my $self = shift;
	if ( my $tx = shift ) {
		warn "Storing tx\n";
		$clients->{$self->id}->{tx} = $tx;
	}
	return $clients->{$self->id}->{tx}->can('send') ? $clients->{$self->id}->{tx} : undef;
}

sub debug {
	my $self = shift;
	my $level = shift;
	return 0 unless $ENV{DEBUG};
	use Data::Dumper;
	return $ENV{DEBUG} =~ /$level/;
}
 
sub log {
	my $self = shift;
	warn shift."\n"; 
}

sub queue {
	my $self = shift;
	my $msg = shift; 
	if ( $msg && ref $msg eq 'HASH' ) {
		#warn Dumper({queueing => $msg});
		push @{$self->{__SEND_QUEUE}}, $msg;
	}
}
 
sub send {
	my $self = shift;

	my %msg = ();
	foreach my $msg ( @{$self->{__SEND_QUEUE}} ) {
		$msg{$_} = _unbless($msg->{$_}) foreach keys %$msg;
	}
	my $msg = $self->serializer->serialize({%msg});
	#warn Dumper({send => [$self->{__SEND_QUEUE}, {%msg}, $msg]});
	$self->tx->send($msg) if $msg && ! ref $msg;
	delete $self->{__SEND_QUEUE};
}

sub recv {
	my $self = shift;
	my $msg = shift;
	if ( $msg && ! ref $msg ) {
		my $_msg = $msg;
		$msg = $self->serializer->deserialize($msg);
		#warn Dumper({recv => [$_msg, $msg]});
		# The protocol is thus:
		# Receive -> Process -> Send
		# Every received message results in sending a response
		#   (But, maybe there's no response to send in which case it skips that)
		$self->{__RECV} = $msg and $self->process and $self->send if ref $msg eq 'HASH';
	}
	return $self->{__RECV};
}
 
sub disconnect {
	my $self = shift;
	$clients->{$self->id}->{tx}->finish;
	delete $clients->{$self->id};
}
sub disconnected { $clients->{$self->id} ? 0 : 1 }

sub serializer {
	my $self = shift;
	my $secret = shift;
	if ( $secret ) {
		return $self->{"__SERIALIZER_$secret"} ||= new Data::Serializer(serializer => 'Storable', secret => $secret, compress => 1)
	} else {
		return $self->{__SERIALIZER} ||= new Data::Serializer(serializer => 'Storable', compress => 1)
	}
}

sub process { # Process received messages, checking for very specific things
	my $self = shift;

	$self->register;

	$self->last_seen;

	$self->code; # Agent is requesting to receive its code
	             #   Its code is all packages from all users
	             # POST is sending code
	             #   Only authorized users can send code
	$self->run;  # Agent is requesting run configuration
	             #   Does this after registration and on a schedule
	             # POST is sending run configuration
	             #   Only authorized users can send code
}

###

# Ideally this would run last and only if nothing else has updated the mtime.
# Ideally, the agent mtime should be modifed by the other functions (e.g. code and run).
sub last_seen {
	my $self = shift;
	$self->db->resultset('Agent')->find({agent=>$self->registration->{uuid}})->update({mtime=>undef});
}

###

sub upgrade_agent {
	my $self = shift;

	if ( my $version = $self->recv->{version} ) {
		my $name;
		($name, $version) = ($version =~ /^(\S+)\s+(\S+)$/);
		my $upgrade = {
			min => $AGENT_MINIMUM,
			latest => $AGENT_LATEST,
			current => $version,
			can_upgrade => 0,
			must_upgrade => 0,
			url => 'http://use.velicio.us',
		};
		warn "Agent version: $name -=- $version\nPerl version: $perl_version\n" if $self->debug('V');
		if ( version->parse($version) < version->parse($AGENT_MINIMUM) ) {
			$upgrade->{can_upgrade} = 1;
			$upgrade->{must_upgrade} = 1;
		} elsif ( version->parse($version) < version->parse($AGENT_LATEST) ) {
			$upgrade->{can_upgrade} = 1;
			$upgrade->{must_upgrade} = 0;
		}
		$self->queue({upgrade=>$upgrade});
		if ( $upgrade->{must_upgrade} ) {
			warn "Agent must upgrade\n";
			$self->disconnect;
			return 1;
		}
	}
	return 0;
}

###

sub register {
	my $self = shift;

	return if $self->upgrade_agent;
	return if $self->registered;

	if ( not exists $self->recv->{registration} ) {
		warn "Requesting Registration from Client\n";
		$self->queue({registration=>undef});
	} elsif ( ! ref $self->recv->{registration} ) {
		warn "Received Registration from Client and Storing in Memory\n";
		$self->deserialize_registration;
		# Check that it's in the DB
		my $ctx = Digest->new("SHA-512");
		$ctx->add($self->registration->{uuid});
		unless ( $self->db->resultset('Agent')->search({'me.agent'=>$self->registration->{uuid},sig=>$ctx->hexdigest}, {join=>'device_signatures'}) ) {
			warn "Received Registration doesn't exist or signature doesn't match\n";
			$self->unregister;
		} else {
			#$self->db->resultset('Config')->create({agent=>$self->registration->{uuid},ctime=>\'now()'});
		}
	} else {
		warn "Generating Registration and Sending to Client\n";
		$self->serialize_registration;
		# Add to DB
		$self->db->resultset('Agent')->create({agent=>$self->registration->{uuid},ctime=>\'now()',name=>$self->recv->{hostname}});
		$self->db->resultset('Device')->create({device=>$self->registration->{uuid},agent=>$self->registration->{uuid},ctime=>\'now()',name=>$self->recv->{hostname},ip=>'127.0.0.1'});
		$self->db->resultset('DeviceCinfo')->create({device=>$self->registration->{uuid},cinfo=>'whatever'});
		my $ctx = Digest->new("SHA-512");
		$ctx->add($self->registration->{uuid});
		$self->db->resultset('DeviceSignature')->create({device=>$self->registration->{uuid},sig=>$ctx->hexdigest});
	}

	if ( my $perl_version = $self->recv->{perl_version} ) {
		$self->registration->{perl_version} = $perl_version;
	}
}
sub unregister { my $self = shift; delete $clients->{$self->id}->{__REGISTRATION}; }
sub registered { my $self = shift; $clients->{$self->id}->{__REGISTRATION} }
sub registration {
	my $self = shift;
	$clients->{$self->id}->{__REGISTRATION} = $_[0] if $_[0] && ref $_[0] eq 'HASH';
	return $clients->{$self->id}->{__REGISTRATION} ||= {};
}
sub serialize_registration {
	my $self = shift;
	$self->registration({uuid => create_UUID_as_string(UUID_V4)});
	warn "  UUID -> ", $self->registration->{uuid}, "\n";
	$self->queue({registration => $self->serializer($self->secret)->serialize($self->registration)});
}
sub deserialize_registration {
	my $self = shift;
	my $registration = $self->recv->{registration};
	if ( ! ref $registration ) {
		$self->registration($self->serializer($self->secret)->deserialize($registration));
		if ( $self->registration->{uuid} ) {
			warn "  UUID -> ", $self->registration->{uuid}, "\n";
		} else {
			warn "Invalid Registration, possible hacking attempt\n";
			$self->unregister;
		}
	}
}

###

sub code {
	my $self = shift;

	return unless $self->registered;

	if ( my $code = $self->recv->{code} ) {
		# POST is requesting to send code to agent
		# The POST request might be code already in the DB or it might be code that was supplied via the POST
	} elsif ( exists $self->recv->{code} ) {
		# Agent is requesting to receive code, server will look up available code in the DB
		my (%code, %base, %base_code);
		$_ = $self->db->resultset('Code')->search({agent=>[$self->registration->{uuid},'']}, {order_by=>'agent'});
		while ( my $code = $_->next ) {
			$base{$code->base} = $code->base_version if $code->base && $code->base_version && version->parse($code->base_version) >= version->parse($base{$code->pkg});
			$code{code}{$code->pkg} = join "\n", sprintf("package Velicio::Code::%s;", $code->pkg), ($code->base?sprintf("BEGIN { use base 'Velicio::Base::%s'; Velicio::Base::%s->import; }", $code->base, $code->base):''), $code->code;
		}
		$_ = $self->db->resultset('BaseCode')->search({pkg=>{-in=>[keys %base]}});
		while ( my $base_code = $_->next ) {
			$base_code{$base_code->pkg} = $base_code->version if version->parse($base_code->version) >= version->parse($base_code{$base_code->pkg});
			if ( version->parse($self->registration->{perl_version}) >= version->parse('v5.12.0') ) {
				$code{base}{$base_code->pkg} = join "\n", sprintf("package Velicio::Base::%s %s;", $base_code->pkg, $base_code->version), $base_code->code
					if version->parse($base_code->version) >= version->parse($base_code{$base_code->pkg});
			} else {
				$code{base}{$base_code->pkg} = join "\n", sprintf("package Velicio::Base::%s;\nour \$VERSION='%s';", $base_code->pkg, $base_code->version), $base_code->code
					if version->parse($base_code->version) >= version->parse($base_code{$base_code->pkg});
			}
		}
		$self->queue({code=>join "\n", (map { $code{base}{$_} } keys %{$code{base}}), (map { $code{code}{$_} } keys %{$code{code}})});
	}
}

###

sub run {
	my $self = shift;

	return unless $self->registered;

	if ( my $run = $self->recv->{run} ) {
		# Server received run results from agent, time to process those run results
		use constant {
			UNDEF => 950,
			QXFAIL => 900,
			ALERT => 550,
			NOINFO => 500,
			WARN => 400,
			OK => 50,
			INFO => 10,
			DEFAULT_LABEL => 'Default Label',
		};
		foreach my $r ( @$run ) {
			$r->{id} or next;
			my $config = $self->db->resultset('Config')->find({id=>$r->{id}, agent=>$self->registration->{uuid}}) or next;
			#warn "Package ran: ", $config->pkg, "\n";
			#warn Dumper({ran=>$r});
			$self->db->resultset('Runhistory')->create({
				config_id => $r->{id},
				dt => \'now()',
				's' => $r->{status},
				n => $r->{value}
			});
			my $c = $self->db->resultset('Runhistory')->search({config_id=>$r->{id}})->count;
			my $ok = $self->db->resultset('Runhistory')->search({config_id=>$r->{id}, 's'=>{'<'=>100}})->count;
	                my $t;
        	        if ( $t = $self->db->resultset('Runhistory')->search({config_id=>$r->{id}, 's'=>{'!='=>$r->{status}}}, {order_by=>'dt desc', rows=>1}) ) {
                	        if ( $t = $t->next ) {
                        	        $t = $t->dt;
	                        }
        	        }
			$self->db->resultset('Runresult')->update_or_create({
				config_id => $r->{id},
				dt => \'now()',
				's' => $r->{status},
				ok => sprintf("%.2f", $c?$ok/$c*100:0),
				t => $t,
				n => $r->{value},
				'y' => $->{summary},
				d => $r->{details}
			}, {
				key => 'config_id'
			});
		}
	} elsif ( exists $self->recv->{run} ) {
		# Agent is requesting to receive its run configuration
		#   There's really only one true run configuration.  This run configuration contains a myriad
		#   of commands, arguments and frequencies.  Group by frequency and run each group in serial.
		my $run = {};
		my $configs = $self->db->resultset('Config')->search({agent=>[$self->registration->{uuid},'']}, {order_by=>'seq'});
		while ( my $config = $configs->next ) {
			my %config = ();
			$config{$_} = $config->$_ foreach qw/frequency id warn alert pkg args/;
			$run->{$config->frequency||0}->[$#{$run->{$config->frequency||0}}+1] = {%config};
			#warn Dumper({run=>$run});
		}
		$self->queue({run=>$run});
	}
}

1;
