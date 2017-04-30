package Linux::NFS::BigDir;
use strict;
use warnings;
use Exporter 'import';
use Carp;
use File::Temp 'tempfile';
use Fcntl;
use Config;

use constant BUF_SIZE => 4096;
use constant SYS_getdents => do {
    $_ = $Config{archname};
    die "unsupported arch $_" unless /linux/;
    # 64 bits => 78
    /^x86_64-/ ? 78 :
    # 32 bits => 141
    /^i686-/ ? 141 :
    # TODO
    die "unsupported arch"
};

#require 'syscall.ph';

# VERSION

=pod

=head1 NAME

Linux::NFS::BigDir - use Linux getdents syscall to read large directories over NFS

=head1 SYNOPSIS

    use Linux::NFS::BigDir qw(getdents);
    # entries_ref is an array reference
    my $entries_ref = getdents($very_large_dir);

=head1 DESCRIPTION

This module was created to solve a very specific problem: you have a directory over NFS, mounted by
a Linux OS, and that directory has a very large number of items (files, directories, etc). The number of entries
is so large that you have trouble to list the contents with C<readdir> or even C<ls> from the shell. In extreme
cases, the operation just "hangs" and will provide a feedback hours later.

I observed this behavior only with NFS version 3 (and wasn't able to simulate it with local EXT3/EXT4): you might find in different situations, 
but in that case it migh be a wrong configuration regarding the filesystem. Ask your administrator first.

If you can't fix (or get fixed) the problem, then you might want to try to use this module. It will use the C<getdents>
syscall from Linux. You can check the documentation about this syscall with C<man getdents> in a shell.

In short, this syscall will return a data structure, but you probably will want to use only the name of each entry in the directory.

How can this be useful? Here are some directions:

=over 

=item 1.

You want to remove all directory content.

=item 2.

You want to remove files from the directory with a pattern in their filename (using regular expressions, for example).

=item 3.

You want to select specific files by their filenames and then test something else (like atime).

=back

These are examples, but it should cover the vast majority of what you want to do. C<getdents> syscall will be more effective because
it will not call C<stat> of each of those files before returning the information to you. That means, you will have the opportunity to filter
whatever you need and then call C<stat> if you really need.

I came up at C<getdents> after researching about "how to remove million of files". After a while I reached an C program example that uses C<getdents>
to print the filenames under the directory. By using it, I was able to cleanup directories with thousands (or even millions) of files in a couple of minutes, 
instead of many hours.

This module is a Perl implementation of that.

=head1 FUNCTIONS

The sub C<getdents> is exported by demand.

=cut

our @EXPORT_OK = qw(getdents);

=head2 getdents

Expects the full path to the directory as a parameter.

Returns an array reference with all the fullpath to each of the file inside that directory.

Meanwhile simple, you should be careful regarding memory restrictions. If you have too files, you program may try to allocate too much memory, with all the
undesired effects.

=cut

sub getdents {
    my ( $dir, $output ) = @_;
    confess "directory $dir is not available" unless ( -d $dir );
    sysopen( my $fd, $dir, O_RDONLY | O_DIRECTORY );
    my @items;

    while (1) {
        my $buf = "\0" x BUF_SIZE;
        my $read = syscall( SYS_getdents, fileno($fd), $buf, BUF_SIZE );

        if ( ( $read == -1 ) and ( $! != 0 ) ) {
            confess "failed to syscall getdents: $!";
        }

        last if ( $read == 0 );

        while ( $read != 0 ) {
            my ( $ino, $off, $len, $name ) = unpack( "L!L!SZ*", $buf );
            push( @items, ( $dir . '/' . $name ) );
            substr( $buf, 0, $len ) = '';
            $read -= $len;
        }

    }

    return @items;
}

=head1 ARCH SUPPORT

The syscall number for C<getdents> is defined as constants for a limited set of Linux platforms:

=over 4

=item C</^x86_64-/>

=item C</^i686-/>

=back

C<Linux::NFS::BigDir> must be patched to add missing platforms.

=head1 SEE ALSO

=over

=item *

L<pack>

=item *

L<h2ph>.

=item *

L<syscall>

=item *

The manual page of C<getdents>.

=item *

L<This discussion about it at PerlMonks|http://perlmonks.org/?node_id=1148448>.

=back

=head1 AUTHOR

Alceu Rodrigues de Freitas Junior, E<lt>arfreitas@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2016 of Alceu Rodrigues de Freitas Junior, E<lt>arfreitas@cpan.orgE<gt>

This file is part of Linux-NFS-BigDir distribution.

Linux-NFS-BigDir is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Linux-NFS-BigDir is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Linux-NFS-BigDir. If not, see <http://www.gnu.org/licenses/>.

=cut

1;
