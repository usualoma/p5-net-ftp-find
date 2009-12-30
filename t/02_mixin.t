#!perl
##!perl -T

use strict;
use warnings;

use Test::More;

use Test::FTP::Server;
use Test::TCP;

use Net::FTP;
use Net::FTP::Find::Mixin;
use File::Find;
use Cwd;

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

		foreach my $k ('__PACKAGE__::name', '__PACKAGE__::dir', '_') {
			(my $k_ftp = $k) =~ s/__PACKAGE__/Net::FTP::Find/;
			(my $k_fs = $k) =~ s/__PACKAGE__/File::Find/;
			foreach my $no_chdir (0 .. 1) {
				foreach my $bydepth (0 .. 1) {
					no strict 'refs';

					my $str_ftp = '';
					$ftp->find({
						'wanted' => sub {
							$str_ftp .= $$k_ftp;
						},
						'no_chdir' => $no_chdir,
						'bydepth' => $bydepth,
					}, $target);

					my $str_fs = '';
					find({
						'wanted' => sub {
							$str_fs .= $$k_fs;
						},
						'no_chdir' => $no_chdir,
						'bydepth' => $bydepth,
					}, $target);

					is(
						$str_ftp, $str_fs,
						"\$$k_ftp (no_chdir => $no_chdir, bydepth => $bydepth)"
					);
				}
			}
		}

		ok($ftp->quit);
	},
);

done_testing;

1;
