package Net::FTP::Find::Mixin;

use strict;
use warnings;

our $VERSION = '0.033';

use Carp;
use File::Spec;
use File::Basename;
use File::Listing;

my @month_name_list = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);

sub import {
	my $class = shift;
	my $pkg = shift || 'Net::FTP';

	no strict 'refs';
    *{$pkg . '::find'} = \&find;
    *{$pkg . '::finddepth'} = \&finddepth;
}

sub finddepth {
	my $self = shift;
	my ($opts, @directories) = @_;

	if (ref $opts eq 'CODE') {
		$opts = {
			'wanted' => $opts,
		};
	}

	$opts->{'bydepth'} = 1;

	&find($self, $opts, @directories);
}

sub find {
	my $self = shift;
	my ($opts, @directories) = @_;

	my %options = ();

	if (ref $opts eq 'CODE') {
		$options{'wanted'} = $opts;
	}
	elsif (ref $opts eq 'HASH') {
		while (my ($k, $v) = each(%$opts)) {
			$options{$k} = $v;
		}
	}

	if (! $options{'wanted'}) {
		croak('no &wanted subroutine given');
	}

	if ( !$options{'fstype'} ) {
		$options{'fstype'} = 'unix';
		if ($self->cmd('SYST') == 2) {
			if ($self->message =~ m/windows/i) {
				$options{'fstype'} = 'dosftp';
			}
		}
	}

	my $cwd = $self->pwd;
	$cwd =~ s{/*\z}{/} if $cwd;

	foreach my $d (@directories) {
		&recursive( $self, $d =~ m!\A/! ? '' : $cwd, \%options, $d, 0 )
			or return;
	}
}

sub recursive {
	my $self = shift;
	my ($cwd, $opts, $directory, $depth) = @_;

	our (
		$name, $dir,
		$is_directory, $is_symlink, $mode,
		$permissions, $link, $user, $group, $size, $month, $mday, $year_or_time,
		$type, $ballpark_mtime,
		$unix_like_system_size, $unix_like_system_name
	);

	return 1
		if (defined($opts->{'max_depth'}) && $depth > $opts->{'max_depth'});

	local $dir;
	my $orig_cwd = undef;
	my @entries = ();
	if ($opts->{'no_chdir'}) {
		@entries = dir_entries( $self, $directory, undef, undef, undef,
			$depth == 0 );
		return 1 unless @entries;

		if ($depth == 0) {
			if (! grep {$_->{data}[0] eq '.'} @entries) {
				build_start_dir( $self, $opts, \@entries, $directory,
					dirname($directory) );
			}
		}

		$dir = $directory;
	}
	else {
		defined($orig_cwd = $self->pwd)
			or return;
		if ($orig_cwd) {
			$orig_cwd =~ s{^/*}{/};
		}

		$self->cwd($directory)
			or return;
		@entries
			= dir_entries( $self, '.', undef, undef, undef, $depth == 0 );

		defined($dir = $self->pwd)
			or return;
		if ($dir) {
			$dir =~ s{^/*}{/};
		}
		elsif (defined($dir)) {
			$dir = $directory;
		}

		if ($depth == 0) {
			if (! grep {$_->{data}[0] eq '.'} @entries) {
				$self->cwd('..')
					or return;
				build_start_dir($self, $opts, \@entries, $directory, '.');
			}

			$self->cwd($orig_cwd);
		}

		return 1 if ! @entries;
	}

	my @dirs = ();
	foreach my $e (@entries) {
		local (
			$permissions, $link, $user, $group, $unix_like_system_size, $month, $mday, $year_or_time, $unix_like_system_name
		) = split(/\s+/, $e->{line}, 9);
		local (
			$_, $type, $size, $ballpark_mtime, $mode
		) = @{ $e->{data} };

		next if $_ eq '..';
		next if $_ eq '.' && $depth != 0;

		if ($depth == 0) {
			next if $_ ne '.';
			$_ = $directory;
		}

		local $name = $depth == 0 ? $_ : File::Spec->catfile($dir, $_);
		$_ = $name if $opts->{'no_chdir'} && $depth != 0;
		my $next = $_;

		$name =~ s/$cwd// if $cwd;
		$dir  =~ s/$cwd// if $cwd;

		local $is_directory = $type eq 'd';
		local $is_symlink   = substr($type, 0, 1) eq 'l';

		if ($is_directory && $opts->{'bydepth'}) {
			&recursive($self, $cwd, $opts, $next, $depth+1)
				or return;
		}

		if (
			(! defined($opts->{'min_depth'}))
			|| ($depth > $opts->{'min_depth'})
		) {
			local $_ = '.' if (! $opts->{'no_chdir'}) && $depth == 0;

			no strict 'refs';
			foreach my $k (
				'name', 'dir',
				'is_directory', 'is_symlink', 'mode',
				'permissions', 'link', 'user', 'group', 'size',
				'month', 'mday', 'year_or_time',
				'type', 'ballpark_mtime',
			) {
				${'Net::FTP::Find::'.$k} = $$k;
			}

			$opts->{'wanted'}($self);
		}

		if ($is_directory && ! $opts->{'bydepth'}) {
			&recursive($self, $cwd, $opts, $next, $depth+1)
				or return;
		}
	}

	if ($orig_cwd) {
		$self->cwd($orig_cwd)
			or print(STDERR $self->message . " " . $orig_cwd);
	}

	1;
}

sub parse_permissions {
	my $self = shift;
	my ($permissions) = @_;
	my $mode = 0;

	my ($type, @perms) = split(//, $permissions);

	my $num = 1;
	my $index = 0;
	foreach my $p (reverse(@perms)) {
		if ($p ne '-') {
			if ($index == 0 && $p eq 't') {
				$mode += $num + (2**9-1+1);
			}
			elsif ($index == 0 && $p eq 'T') {
				$mode += (2**9-1+1);
			}
			elsif ($index == 2 && $p eq 's') {
				$mode += $num + (2**9-1+2);
			}
			elsif ($index == 2 && $p eq 'S') {
				$mode += (2**9-1+2);
			}
			elsif ($index == 5 && $p eq 's') {
				$mode += $num + (2**9-1+4);
			}
			elsif ($index == 5 && $p eq 'S') {
				$mode += (2**9-1+4);
			}
			else {
				$mode += $num;
			}
		}
		$num *= 2;
		$index++;
	}

	($type eq 'd', $type eq 'l', $mode);
}

sub build_start_dir {
	my ($self, $opts, $entries, $current, $parent) = @_;

	my $detected = 0;
	if ($current ne '/') {
		my @parent_entries = dir_entries($self, $parent);
		my $basename = basename($current);

		for my $e (@parent_entries) {
			next if $e->{data}[0] ne $basename;

			$detected = 1;
			$e->{line} =~ s/$basename$/./g;
			$e->{data}[0] = '.';
			splice @$entries, 0, scalar(@$entries), $e;
		}
	}

	if (! $detected) {
		my ($year, $month, $mday, $hour, $min) = (localtime)[5,4,3,2,1];
		my $line;
		if ($opts->{'fstype'} eq 'dosftp') {
			$line = join(
				' ',
				sprintf( '%02d-%02d-%d',
					$month + 1, $mday, substr( $year + 1900, 2 ) ),
				(   $hour < 12
					? sprintf( '%02d:%02dAM', $hour,	  $min )
					: sprintf( '%02d:%02dPM', $hour - 12, $min )
				),
				'<DIR>', '.'
			);
		}
		else {
			$line = join(' ',
				'drwxr-xr-x',
				scalar(@$entries)+2,
				'-',
				'-',
				0,
				$month_name_list[$month],
				$mday,
				$hour . ':' . $min,
				'.'
			);
		}
		my ($e) = parse_entries([$line], undef, undef, undef, 1);
		splice @$entries, 0, scalar(@$entries), $e;
	}
}

sub dir_entries {
	my $self = shift;
	my ($directory, $tz, $fstype, $error, $preserve_current) = @_;

	if ($directory ne '.' && $directory ne '..') {
		$directory =~ s{/*\z}{/};
	}
	my $list = $self->dir($directory);
	parse_entries($list, $tz, $fstype, $error, $preserve_current);
}

sub parse_entries {
	my($dir, $tz, $fstype, $error, $preserve_current) = @_;

	if ($preserve_current) {
		$dir = [ map {
			my $e = $_;
			$e =~ s/(\s\S*)d(?=\S*\z)/$1dd/g;
			$e =~ s/(?<=\s)\.\z/d./g;
			$e;
		} @$dir ];
	}

	my @parsed = map {
		my ($data) = File::Listing::parse_dir($_, $tz, $fstype, $error);
		$data ? +{ line => $_, data => $data } : ()
	} @$dir;

	if (@$dir && ! @parsed) {
		# Fallback
		@parsed = map {
			my $l = $_;
			$l =~ s/
				(\s\d+\s+)
				(\d+)\S*
				(?=\s+\d+\s+(\d{2}:\d{2}|\d{4}))
			/$1 . $month_name_list[$2-1]/ex;
			my ($data) = File::Listing::parse_dir($l, $tz, $fstype, $error);
			$data ? +{ line => $_, data => $data } : ()
		} @$dir;
	}

	if ($preserve_current) {
		for (@parsed) {
			$_->{data}[0] =~ s/dd/d/;
			$_->{data}[0] =~ s/d\././g;
		}
	}

	wantarray ? @parsed : \@parsed;
}

1;
__END__

=head1 NAME

Net::FTP::Find::Mixin - Inject the function of Net::FTP::Find

=head1 SYNOPSIS

  use Net::FTP;
  use Net::FTP::Find::Mixin;

  my $ftp = Net::FTP->new('localhost');
  $ftp->login('user', 'pass');
  $ftp->find(sub { ... }, '/');

or

  use Net::FTP::Subclass;
  use Net::FTP::Find::Mixin qw( Net::FTP::Subclass );

  my $sub = Net::FTP::Subclass->new('localhost');
  $sub->login('user', 'pass');
  $sub->find(sub { ... }, '/');

=head1 AUTHOR

Taku Amano E<lt>taku@toi-planning.netE<gt>

=head1 SEE ALSO

L<Net::FTP::Find>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
