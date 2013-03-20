package Net::FTP::Find;

use strict;
use warnings;

our $VERSION = '0.031';

use Carp;
use File::Spec;

use Net::FTP;
use base qw( Net::FTP );

use Net::FTP::Find::Mixin qw( Net::FTP::Find );

use Exporter;
use base qw( Exporter );
our @EXPORT_OK = qw( find finddepth );

1;
__END__

=head1 NAME

Net::FTP::Find - Traverse a directory tree through Net::FTP

=head1 SYNOPSIS

  use Net::FTP::Find;

  my $ftp = Net::FTP::Find->new('localhost');
  $ftp->login('user', 'pass');

  $ftp->find(sub { ... }, '/');

  $ftp->finddepth(sub { ... }, '/');

or

  use Net::FTP;
  use Net::FTP::Find::Mixin;

  my $ftp = Net::FTP->new('localhost');
  $ftp->login('user', 'pass');

  $ftp->find(sub { ... }, '/');

  $ftp->finddepth(sub { ... }, '/');

=head1 DESCRIPTION

These are functions for searching through directory trees doing work on each
file found similar to the File::Find. Net::FTP::Find provides two functions,
"find" and "finddepth".  They work similarly but have subtle differences.

=head1 FUNCTIONS

=over 3

=item B<find>

  $ftp->find(\&wanted,  @directories);
  $ftp->find(\%options, @directories);

=item B<finddepth>

  $ftp->finddepth(\&wanted,  @directories);
  $ftp->finddepth(\%options, @directories);

=back

=head2 %options

The first argument to C<find()> is either a code reference to your
C<&wanted> function, or a hash reference describing the operations
to be performed for each file.  The
code reference is described in L<The wanted function> below.

Here are the possible keys for the hash:

=over 3

=item C<wanted>

The value should be a code reference.  This code reference is
described in L<The wanted function> below. The C<&wanted> subroutine is
mandatory.

=item C<bydepth>

Reports the name of a directory only AFTER all its entries
have been reported.  Entry point C<finddepth()> is a shortcut for
specifying C<< { bydepth => 1 } >> in the first argument of C<find()>.

=item C<no_chdir>

Does not C<cwd()> to each directory as it recurses. The C<wanted()>
function will need to be aware of this, of course. In this case,
C<$_> will be the same as C<$Net::FTP::Find::name>.

=item C<max_depth>

The directories that are deeper than this value is traversed.

=item C<min_depth>

The directories that are shallower than this value is traversed.

=back


=head2 The wanted function

The C<wanted()> function does whatever verifications you want on
each file and directory.  Note that despite its name, the C<wanted()>
function is a generic callback function, and does B<not> tell
Net::FTP::Find if a file is "wanted" or not.  In fact, its return value
is ignored.

The wanted function takes no arguments but rather does its work
through a collection of variables.

=over 4

=item C<$Net::FTP::Find::dir> is the current directory name,

=item C<$_> is the current filename within that directory

=item C<$Net::FTP::Find::name> is the complete pathname to the file.

=back

The above variables have all been localized and may be changed without
effecting data outside of the wanted function.

For example, when examining the file F</some/path/foo.ext> you will have:



    $Net::FTP::Find::dir  = /some/path/
    $_                    = foo.ext
    $Net::FTP::Find::name = /some/path/foo.ext

You are cwd()'d to C<$Net::FTP::Find::dir> when the function is called,
unless C<no_chdir> was specified. Note that when changing to
directories is in effect the root directory (F</>) is a somewhat
special case inasmuch as the concatenation of C<$Net::FTP::Find::dir>,
C<'/'> and C<$_> is not literally equal to C<$Net::FTP::Find::name>. The
table below summarizes all variants:

              $Net::FTP::Find::name  $Net::FTP::Find::dir  $_
 default      /                      /                     .
 no_chdir=>0  /etc                   /                     etc
              /etc/x                 /etc                  x

 no_chdir=>1  /                      /                     /
              /etc                   /                     /etc
              /etc/x                 /etc                  /etc/x



=head1 AUTHOR

Taku Amano E<lt>taku@toi-planning.netE<gt>

A mostly parts of the document are from L<File::Find>.

=head1 SEE ALSO

L<File::Find>
L<Net::FTP::Find::Mixin>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
