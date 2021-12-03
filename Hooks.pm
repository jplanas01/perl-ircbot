use warnings;
use strict;
use Modern::Perl;

our %cmd_table;
our %state;
my %replies;

# Helper functions
sub privmsg {
	my ($dest, $msg) = @_;
	sendmsg("PRIVMSG $dest :$msg");
}

sub do_response {
	my ($msg, $dest) = @_;
	if (exists $replies{$msg}) {
		privmsg($dest, $replies{$msg});
	}
}

# 001: Connnection to server successful, logged on
sub on_001 {
	my ($source, $dest, $msg) = @_;
	print "Successfully logged on.\n";
	$state{'logged_on'} = 1;
	sendmsg('JOIN #room');
}

# 353: /names response, names list
sub on_353 {
	my ($source, $dest, $msg) = @_;
	$msg =~ s/^\s+|\s+$//g;
	my ($chan, $list) = split(/ :/, $msg, 2);
	my @names = split(/ /, $list);
	foreach my $name (@names) {
		my ($mode) = ($name =~ /^([&+@])/);
		$name =~ s/^[&+@]//;
		print "353 $chan: $name\n";
	}
}

sub on_join {
	my ($source, $dest, $msg) = @_;
	$dest = substr($dest, 1);
	my $nuser = "$state{'nick'}!$state{'user'}";
	if ($source =~ /$nuser/) {
		print "Joined channel $dest\n";
		$state{'channels'}{$dest} = 1;
	}
}

sub on_part {
	my ($source, $dest, $msg) = @_;
	$dest = substr($dest, 1);
	my $nuser = "$state{'nick'}!$state{'user'}";
	if ($source =~ /$nuser/) {
		print "Left channel $dest\n";
		$state{'channels'}{$dest} = 0;
	}
}

sub on_privmsg {
	my ($source, $dest, $msg) = @_;
	logmsg("$dest: <$source> $msg\n");

	unless ($dest =~ /#room/) {
		return;
	}

	do_response($msg, $dest);
}

sub init {
	# Programmed responses
	$replies{'!hello'} = "world!";

	# Numeric command hooks
	$cmd_table{'001'} = \&on_001;
	$cmd_table{'353'} = \&on_353;

	# Named command hooks
	$cmd_table{'JOIN'} = \&on_join;
	$cmd_table{'PART'} = \&on_part;
	$cmd_table{'PRIVMSG'} = \&on_privmsg;
}

init();
1;
