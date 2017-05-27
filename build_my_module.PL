# This script relies on behavior of ExtUtils::MakeMaker described in Pod, PL_FILES
use warnings;
use strict;
use File::Spec;
use Inline 0.80 C => <<'...';
#include <sys/syscall.h>
int _get_syscall_num() {
      return SYS_getdents;
}
...

open(
    my $out,
    '>>',
    File::Spec->catfile(
        'lib', 'Linux', 'NFS', 'BigDir', 'Syscalls.pm'
    )
) or die "Cannot update Syscalls.pm: $!";
my $getdents_num = _get_syscall_num();
print $out <<BLOCK;
sub SYS_getdents {
    return $getdents_num;
}

1;
BLOCK
close($out);

