#!perl
##!perl -T

use strict;
use warnings;

use Test::More;

use Test::FTP::Server;
use Test::TCP;

use Net::FTP;
use Net::FTP::Find::Mixin;

my $user = 'testid';
my $pass = 'testpass';
(my $target = Cwd::realpath(__FILE__)) =~ s/\.t$//;

test_tcp(
	server => sub {
		my $port = shift;

		Test::FTP::Server->new(
			'users' => [{
				'user' => $user,
				'pass' => $pass,
				'root' => '/',
			}],
			'ftpd_conf' => {
				'port' => $port,
				'daemon mode' => 1,
				'run in background' => 0,
			},
		)->run;
	},
	client => sub {
		my $port = shift;

		my $ftp = Net::FTP->new('localhost', Port => $port);
		ok($ftp);
		ok($ftp->login($user, $pass));

		{
			my $str_ftp = '';
			$ftp->find({
				'wanted' => sub {
					$str_ftp .= $_;
				},
				'no_chdir' => 1,
				'max_depth' => 1,
			}, $target);
			is($str_ftp, "$target$target/testdir")
		}
	},
);

done_testing;

1;
