package Net::FTP::Find::Mixin;

use strict;
use warnings;

our $VERSION = '0.02';

use Carp;
use File::Spec;
use File::Basename;

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
		$permissions, $link, $user, $group, $size, $month, $mday, $year_or_time
	);

	return
		if (defined($opts->{'max_depth'}) && $depth > $opts->{'max_depth'});

	local $dir;
	my $orig_cwd = undef;
	my @entries = ();
	if ($opts->{'no_chdir'}) {
		@entries = $self->dir($directory);
		return unless @entries;

		if ($depth == 0) {
			if (! grep {((split(/\s+/, $_, 9))[8] || '') eq '.'} @entries) {
				build_start_dir( $self, \@entries, $directory,
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
		@entries = $self->dir('.');

		$dir = $self->pwd;
		if ($dir) {
			$dir =~ s{^/*}{/};
		}
		elsif (defined($dir)) {
			$dir = $directory;
		}

		if ($depth == 0) {
			if (! grep {((split(/\s+/, $_, 9))[8] || '') eq '.'} @entries) {
				$self->cwd('..')
					or return;
				build_start_dir($self, \@entries, $directory, '.');
			}

			$self->cwd($orig_cwd);
		}

		return if ! @entries || ! $directory;
	}

	my @dirs = ();
	foreach my $e (@entries) {
		local (
			$permissions, $link, $user, $group, $size, $month, $mday, $year_or_time, $_
		) = split(/\s+/, $e, 9);

		next unless $_;
		next if $_ eq '..';
		next if $_ eq '.' && $depth != 0;

		if ($depth == 0) {
			next if $_ ne '.';
			$_ = $directory;
		}

		$_ =~ s/\s*->.*//o;

		local $name = $depth == 0 ? $_ : File::Spec->catfile($dir, $_);
		$_ = $name if $opts->{'no_chdir'} && $depth != 0;
		my $next = $_;

		$name =~ s/$cwd// if $cwd;
		$dir  =~ s/$cwd// if $cwd;

		local ($is_directory, $is_symlink, $mode)
			= &parse_permissions($self, $permissions);

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
				'month', 'mday', 'year_or_time'
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
	my ($self, $entries, $current, $parent) = @_;

	my $detected = 0;
	if ($current ne '/') {
		my @parent_entries = $self->dir($parent);
		my $basename = basename($current);

		my ($s) = grep {
			((split(/\s+/, $_, 9))[8] || '') eq $basename
		} @parent_entries;

		if ($s) {
			$detected = 1;
			$s =~ s/$basename/./g;
			splice @$entries, 0, scalar(@$entries), $s;
		}
	}

	if (! $detected) {
		my ($month, $mday, $hour, $min) = (localtime)[4,3,2,1];
		my @month_name = qw(
			Jan  Feb  Mar  Apr May Jun Jul Aug Sep Oct Nov Dec
		);
		splice @$entries, 0, scalar(@$entries), (join(' ',
			'drwxr-xr-x',
			scalar(@$entries)+2,
			'-',
			'-',
			0,
			$month_name[$month],
			$mday,
			$hour . ':' . $min,
			'.'
		));
	}
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
