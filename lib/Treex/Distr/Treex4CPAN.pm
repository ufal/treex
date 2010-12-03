package Treex::Distr::Treex4CPAN;

our $VERSION = '0.1';

use strict;
use warnings;
use Carp;

my @required_fields = qw(module_name author email lib bin t );

sub _get_version {
    my $svn_info = `svn info`;
    $svn_info =~ /Revision:\s(\d+)/sxm or die "Undetectable svn revision number!";
    return "1.".sprintf("%05d",$1);
}


sub create_distr {
    my $arg_hash = shift;

    if (not $arg_hash or not ref($arg_hash) eq "HASH") {
        croak "create_distr requires a hash argument";
    }

    foreach my $field (@required_fields) {
        if (not defined $arg_hash->{$field}) {
            croak "missing obligatory '$field' in the argument hash";
        }
    }

    my $version = _get_version();
    my $distro_name = $arg_hash->{module_name};
    $distro_name =~ s/::/-/g;
    $distro_name .= "-$version";

    # 2. preparing the list of modules

    my %module2file;
    my @all_files = map {glob "$ENV{TMT_ROOT}/$_"} @{$arg_hash->{lib}};
    my @all_modules;

#    print STDERR "Files to be included:\n";

    foreach my $file (@all_files) {
#        print STDERR "  $file\n";
        if ($file =~ /\.pm$/) {
            my $module = $file;

            if (not ( $module =~ s/\.pm//
                          and $module=~ s/.+\/(Treex\/)/$1/
                              and $module =~ s/\//::/g )) {
                die "\"$file\" not matching the expected patterns";
            }

            $module2file{$module} = $file;
            push @all_modules, $module;
        }
    }



    # 3. pre-generating the distribution package using module-starter

    my @sorted_modules = ($arg_hash->{module_name}, grep {$arg_hash->{module_name} ne $_} @all_modules);
    my $command = "module-starter  ".(join " ",map {"--module=$_"} (@all_modules)).
        " --builder=ExtUtils::MakeMaker --builder=Module::Build ".
            " --distro $distro_name  --author=\"$arg_hash->{author}\" --email=\"$arg_hash->{email}\"";


    print STDERR "Executing module-starter:\n $command\n";

    system $command;

#    exit;



    # 4. copying all files (not only modules) from their repository locations into the distr,
    # and arranging their version numbers

    print STDERR "Copying modules, scripts, and tests...\n";

    foreach my $original_file (map {glob "$ENV{TMT_ROOT}/$_"} @{$arg_hash->{lib}}) {

        $original_file =~ /\/(Treex\/.+?)$/ or die "path to the module is not matchin expected pattern";
        my $target_file = $distro_name."/lib/".$1;

        print "Copying $original_file to $target_file\n";

        open IN,"<:utf8",$original_file or die "Cannot open file for reading: $original_file";
        open OUT,">:utf8",$target_file or die "Cannot open file for writing: $target_file";

        my $content = join "",<IN>;

        $content =~ s/\$VERSION\s*=\s*['"][^'"]*['"]/\$VERSION = \'$version\'/
            or print STDERR "Warning: Can't find \$VERSION in the source code $original_file\n";

        print OUT $content;
        close IN;
        close OUT
    }

    if (@{$arg_hash->{bin}}) {
        system "mkdir -p $distro_name/bin";
    }

    foreach my $dir (qw(bin t)) {
        foreach my $original_file (map {glob "$ENV{TMT_ROOT}/$_"} @{$arg_hash->{$dir}}) {

            $original_file =~ /([^\/]+)$/
                or die "path to the file does not match expected pattern: $original_file";

            my $target_file = $distro_name."/$dir/".$1;
            my $command = "cp $original_file $target_file";
            print STDERR "Copying: $command\n";
            system $command;
        }

    }

    print STDERR "Done.\n";

}


1;

__END__


=head1 NAME

Treex::Distr::Treex4CPAN - utility for preparing Treex packages for CPAN

=head1 SYNOPSIS

  use Treex::Distr::Treex4CPAN;
  
  Treex::Distr::Treex4CPAN::create_distr(
  
  
  )


and then

 $ make manifest disttest distsignature (?) dist


=head1 DESCRIPTION

Tool for preparing CPAN packages comprising selected
Treex components (modules & scripts).

=head1 METHODS

=over 4

=item Treex::Distr::Treex4CPAN->create_distr($arg_hash);

=back

Arguments passed by the hash:

=over 4

=item

=back


=head1 COPYRIGHT

Copyright 2010 Zdenek Zabokrtsky
This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README


