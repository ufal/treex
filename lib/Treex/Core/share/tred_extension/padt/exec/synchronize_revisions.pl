# -*- perl -*- ############################################################# Otakar Smrz, 2006/02/11
#
# synchronize_revisions.pl ############################################################## 2006/02/12

# $Id: synchronize_revisions.pl 487 2008-02-01 12:39:27Z smrz $

our $VERSION = do { q $Revision: 487 $ =~ /(\d+)/; sprintf "%4.2f", $1 / 100 };


$dirsep = $^O eq 'MSWin32' ? '\\' : '/';

$copy = $^O eq 'MSWin32' ? 'copy' : 'cp -p';

$execDir = join $dirsep, $ENV{'HOME'}, qw '.tred.d extensions padt contrib padt exec', '';

@ARGV = glob join " ", @ARGV;

foreach $file (@ARGV) {

    @path = split /\//, $file;

    $name = pop @path;

    ($base, $type) = $name =~ /^(.+)\.(morpho|syntax)\.fs$/;

    @path = ( @path == 0 ? '..' : '.', $type ) if @path < 2;

    if ($type ne $path[-1]) {

        warn "$type <> $path[-1]\t with $file\n";
        next;
    }

    $file[0] = join $dirsep, @path[0 .. @path - 2], 'morpho', $base . '.morpho.fs';
    $file[1] = join $dirsep, @path[0 .. @path - 2], 'morpho', $base . '.syntax.fs';
    $file[2] = join $dirsep, @path[0 .. @path - 2], 'syntax', $base . '.syntax.fs.anno.fs';
    $file[3] = join $dirsep, @path[0 .. @path - 2], 'syntax', $base . '.syntax.fs';

    unless (-f $file[0]) {
          warn "$file[0] not present with $file\n";
          next;
    }

    if (-f $file[1]) {
          warn "$file[1] is blocking with $file\n";
          next;
    }

    if (-f $file[2]) {
          warn "$file[2] is blocking with $file\n";
          next;
    }

    unless (-f $file[3]) {
          warn "$file[3] not present with $file\n";
          next;
    }

    system $copy . ' ' . $file[3] . ' ' . $file[2];

    system 'btred -QI ' . $execDir . 'morpho_syntax.ntred ' . $file[0];

    system $copy . ' ' . $file[1] . ' ' . $file[3];

    system 'btred -QI ' . $execDir . 'migrate_annotation_syntax.btred ' . $file[3];
}
