use strict;
use warnings;
use Modern::Perl;
use IO::Socket;
use IO::Socket::INET;
use Module::Refresh;
use Data::Dumper qw(Dumper);
require './Hooks.pm';

my $server = 'irc.rizon.net';
my $port = 6667;
my $addr = sockaddr_in($port, inet_aton($server));
my $proto = getprotobyname('tcp');
my $debug = 1;
my $refresher = Module::Refresh->new();

# State and the command table are shared between the main program and the
# module containing the actual bot code
our %state = ('logged_on' => 0,
			 'channels' => {},
		 	 'nick' => 'TestBot',
		 	 'user' => 'testing');
our %cmd_table;

sub logmsg {
	my ($msg) = @_;
	if ($debug) {
		print "$msg\n";
	}
}

sub sendsock {
	my ($sock, $msg) = @_;
	logmsg("-> $msg");
	print $sock "$msg\r\n";
}

sub logon {
	my ($sock) = @_;
	sendsock($sock, "NICK $state{'nick'}");
	sendsock($sock, "USER $state{'user'} 8 * :Jack Nicholson");
}

sub sendmsg {
	my ($msg) = @_;
	my $sock = $state{'sock'};
	sendsock($sock, $msg);
}

$/ = "\r\n";
my $sock = IO::Socket::INET->new(PeerAddr => $server,
								 PeerPort => $port,
								 Proto => 'tcp') or die "socket: $!";
$state{'sock'} = $sock;
logon($sock);

while(<$sock>) {
	chomp;
	logmsg("<- $_");
	my ($source, $cmd, $dest, $msg) = split(/ /, $_, 4);
	$source = substr($source, 1);
	$msg = substr($msg, 1) if defined $msg;

	#Special case for PING because it's odd
	if ($_ =~ /^PING/) {
		logmsg('PING!');
		sendmsg("PONG $cmd");
		next;
	}

	# This refresh code probably violates at least 3 best practices
	# But, it works
	# Also command and nick probabaly shouldn't be hardcoded
	if ($_ =~ /:!refresh$/ && $_ =~ /^:?Owner!/) {
		logmsg('Reloading...');
		$refresher->refresh_module('./Hooks.pm');
		do './Hooks.pm';
		next;
	}

	if (exists $cmd_table{$cmd}) {
		$cmd_table{$cmd}->($source, $dest, $msg);
	}
}
