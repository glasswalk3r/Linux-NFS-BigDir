# Linux-NFS-BigDir

This module was created to solve a very specific problem: you have a directory over NFS, mounted by
a Linux OS, and that directory has a very large number of items (files, directories, etc). The number of entries
is so large that you have trouble to list the contents with `readdir` or even `ls` from the shell. In extreme
cases, the operation just "hangs" and will provide a feedback hours later.

I observed this behavior only with NFS version 3 (and wasn't able to simulate it with local EXT3/EXT4): you might find in different situations, 
but in that case it migh be a wrong configuration regarding the filesystem. Ask your administrator first.

If you can't fix (or get fixed) the problem, then you might want to try to use this module. It will use the `getdents`
syscall from Linux. You can check the documentation about this syscall with `man getdents` in a shell.

In short, this syscall will return a data structure, but you probably will want to use only the name of each entry in the directory.

How can this be useful? Here are some directions:

1. You want to remove all directory content.
2. You want to remove files from the directory with a pattern in their filename (using regular expressions, for example).
3. You want to select specific files by their filenames and then test something else (like atime).

These are examples, but it should cover the vast majority of what you want to do. `getdents` syscall will be more effective because
it will not call `stat` of each of those files before returning the information to you. That means, you will have the opportunity to filter
whatever you need and then call `stat` if you really need.

I came up at `getdents` after researching about "how to remove million of files". After a while I reached an C program example that uses `getdents`
to print the filenames under the directory. By using it, I was able to cleanup directories with thousands (or even millions) of files in a couple of minutes, 
instead of many hours.

This module is a Perl implementation of that.

## Install

This distribution will only work in Linux OS with perl version 5.14.4 or higher. Check the dist.ini file for details on that.

You should install this module as any Perl module, but before that be sure to execute `h2ph` before trying to run any function from this module!

In some system, you might need to use the system administrator account to run `h2ph` or even run some manual steps to fix files locations.

If you got errors like:

```
Error:  Can't locate bits/syscall.ph in @INC (did you run h2ph?) (@INC contains: /home/me/Projetos/Linux-NFS-BigDir/.build/MHr69O96uB/blib/lib /home/me/Projetos/Linux-NFS-BigDir/.build/MHr69O96uB/blib/arch /home/me/perl5/perlbrew/perls/perl-5.24.0/lib/site_perl/5.24.0/x86_64-linux /home/me/perl5/perlbrew/perls/perl-5.24.0/lib/site_perl/5.24.0 /home/me/perl5/perlbrew/perls/perl-5.24.0/lib/5.24.0/x86_64-linux /home/me/perl5/perlbrew/perls/perl-5.24.0/lib/5.24.0 .) at /home/me/perl5/perlbrew/perls/perl-5.24.0/lib/site_perl/5.24.0/sys/syscall.ph line 9.
```

It might means that the expected header files are not in the expected standard location. For instance, on a Ubuntu system you might need to create additional links: 

```
ln -s /home/me/perl5/perlbrew/perls/perl-5.24.0/lib/site_perl/5.24.0/x86_64-linux/x86_64-linux-gnu/bits /home/me/perl5/perlbrew/perls/perl-5.24.0/lib/site_perl/5.24.0/bits
```

The baseline here is that perl doesn't expected to have the following sequence of directories under `site_perl`:

```
site_perl/
└── 5.24.0
    └── x86_64-linux
        └── x86_64-linux-gnu
            └── bits
```

But this is where Ubuntu will keep the header files and `h2ph` will not mimic that. The problem is, your perl `@INC` doesn't have the directory `x86_64-linux-gnu` include on it. You can fix that by changing `@INC` or creating symbolic links (I prefer the later).

You will have to troubleshoot this by looking at the `$Config{'installsitearch'}` to see where are located your .ph files, then check the content of each .ph and compare with the real location of the C header files.

You might need to run this as root unless you are using something like perlbrew (or compiling perl yourself).

If you got a recipe for your system to fix that (or a permanent, portable solution) please contact me by e-mail so I can include this information here.

### Install receipt

This might work on your environment. This was tested under Ubuntu LTS 16.04.

Open a shell and type the following sequence of commands:


```
default=$(perl -MConfig -E 'say $Config{installsitearch}')
cd /usr/include
h2ph * sys/*
h2ph syscall x86_64-linux-gnu/sys/*
h2ph syscall x86_64-linux-gnu/bits/*
h2ph unistd x86_64-linux-gnu/asm/*
ph_dir=$(find $default -name 'syscall.ph' | sort | tail -1 | sed -e "s#${default}##" | cut -d '/' -f2)
if [ -z ${ph_dir} ]
then
    echo 'Could not define the location of subdirectory with additional .ph files that are required. Check h2ph output'
    exit 1
fi
for sub_dir in bits sys asm; do ln -s -v "${default}/${ph_dir}/${sub_dir}" "${default}/${sub_dir}"; done
```

I could have tried to avoid using find to define `${ph_dir}`, but there is a inconsistence of values of `$Config{archname}` (from Config module) when you compile a perl with perlbrew with or without threads support.
