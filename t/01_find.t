#!perl
##!perl -T

use strict;
use warnings;

use Test::More;

use Test::FTP::Server;
use Test::TCP;
use File::Basename;

use Net::FTP::Find;
use File::Find;
use Cwd;

my $user = 'testid';
my $pass = 'testpass';


sub run_test {
    my ($port, $target, $start_directory) = @_;

	my $ftp = Net::FTP::Find->new('localhost', Port => $port);
	ok($ftp, 'Create an object');
	ok($ftp->login($user, $pass), 'Login');

    $ftp->cwd($start_directory) if $start_directory;

	foreach my $k ('__PACKAGE__::name', '__PACKAGE__::dir', '_') {
		(my $k_ftp = $k) =~ s/__PACKAGE__/Net::FTP::Find/;
		(my $k_fs = $k) =~ s/__PACKAGE__/File::Find/;
		foreach my $no_chdir (0 .. 1) {
			foreach my $bydepth (0 .. 1) {
				no strict 'refs';

				my $str_ftp = '';
				$ftp->find({
					'wanted' => sub {
						$str_ftp .= ':' . $$k_ftp;
					},
					'no_chdir' => $no_chdir,
					'bydepth' => $bydepth,
				}, $target);

				my $str_fs = '';
                my $orig_cwd = getcwd();
                chdir($start_directory) if $start_directory;
				find({
					'wanted' => sub {
						$str_fs .= ':' . $$k_fs;
					},
					'no_chdir' => $no_chdir,
					'bydepth' => $bydepth,
				}, $target);
                chdir($orig_cwd) if $start_directory;

				is(
					$str_ftp, $str_fs,
					"\$$k_ftp (no_chdir => $no_chdir, bydepth => $bydepth)"
				);
			}
		}
	}

	{
		my $str_ftp = '';
		$ftp->find({
			'wanted' => sub {
				$str_ftp .= $_;
			},
			'no_chdir' => 1,
			'max_depth' => 1,
		}, $target);
		is($str_ftp, "$target$target/testdir", 'max_depth')
	}

	{
		my $str_ftp = '';
		$ftp->find({
			'wanted' => sub {
				$str_ftp .= $_;
			},
			'no_chdir' => 1,
			'min_depth' => 0,
		}, $target);
		is($str_ftp, "$target/testdir$target/testdir/testfile.txt", 'min_depth');
	}

	ok($ftp->quit, 'Quit');
}

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

        subtest 'Absolute path' => sub {
            (my $target = Cwd::realpath(__FILE__)) =~ s/\.t$//;
            run_test($port, $target);
        };

        subtest 'Relative path' => sub {
            (my $target = Cwd::realpath(__FILE__)) =~ s/\.t$//;
            run_test($port, basename($target), dirname($target));
        };
    }
);

done_testing;

1;
