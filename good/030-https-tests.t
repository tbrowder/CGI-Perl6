#!/usr/bin/env perl6

use Test;

use HTTP::UserAgent;

use CGI;
use CGI::Vars;

# tests here use a live apache2 server

plan 12;

my $debug = 0;

# HTTPS tests
my $protocol = 'https';
my $host = 'usafa-1965.org'; # apache2

# reuse defaults
my $client = HTTP::UserAgent.new;
$client.timeout = 1;

my ($resp, $body, %body, @body, $res, @res, %res, $url);

# this depends on one's server setup
$url = 'cgi-bin-cmn/show-env.cgi';
{
    lives-ok { $resp = $client.get("$protocol://$host/$url"); }, 
        'request environment list';
}

my $test-env = 0;
{
    lives-ok {
	if $resp.is-success {
	    $body = $resp.content;
	    $test-env = 1;
	}
	else {
	    $body = $resp.status-line;
	}
    }, 'the required environment list';
}

my %env;
if $test-env {
    %*ENV = {};
    for $body.lines -> $line is copy {
	next if $line !~~ /\S/;
	say "DEBUG: line = '$line'" if $debug > 1;
	# each line should be two words: key : value

	# skip some lines
	my $idx = index $line, ':';
	my ($k, $v);
	if $idx.defined {
	    $k = $line.substr: 0, $idx;
	    $v = $line.substr: $idx+1;
	    $k .= trim;
	    $v .= trim;
	    %env{$k} = $v;
	    %*ENV{$k} = $v;
            if $debug && $line ~~ /SSL|HTTPS/ {
	        say "DEBUG: k = '$k', v = '$v'";
            }
	}
	else {
	    say "WARNING: No separator char ':'for line: '$line'" if $debug;
	}
    }
}

# ensure we have all MUST request CGI vars
my $no-vars = 0;
for %req-meta-vars.keys -> $k {
    if not %env{$k} {
	++$no-vars;
	warn "Std var '$k' is missing.";
    }
}
is $no-vars, 0, 'MUST have request vars';

# ensure we have all CGI TLS vars
my $no-tls-server-vars = 0;
for %tls-server-vars.keys -> $k {
    if not %env{$k} {
	++$no-vars;
	warn "Std var '$k' is missing.";
    }
}
is $no-tls-server-vars, 0, 'MUST have TLS server vars';

if $test-env {
    # check the CGI methods
    my $c = CGI.new;
    my @ekeys;
    lives-ok { @ekeys = $c.https; }, 'c.https';

    my $str = join ' ', @ekeys;
    say @ekeys.gist if $debug;
    my @expect = <HTTPS SSL_CIPHER SSL_PROTOCOL>; # UserAgent
    for @expect {
       like $str, /$_/, 'https method';
    }

    lives-ok { $resp = $c.server-software; }, 'c.server-software';

    like $resp, /Apache/, 'c.server-software matches';

    lives-ok { $resp = $c.remote-addr; }, 'c.remote-addr';

    like $resp, /\d*/, 'c.remote-addr matches';
}

#done-testing;
