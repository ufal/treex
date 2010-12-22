package Treex::Core::Config;

use strict;
use warnings;

use File::HomeDir;
use File::ShareDir;


sub devel_version {
    return (-d ".svn");
    # to je otazka, jak to co nejelegantneji poznat, ze jde o work.copy. a ne nainstalovanou distribuci
}


sub share_dir {
    return $ENV{TMT_ROOT}."/share/"; # temporary
    # return File::HomeDir->my_home."/.treex/share"; # future solution, probably symlink
}

sub pml_schema_dir {

    if (devel_version()) {
        return lib_core_dir()."/share/pml_schema/";
    }
    else {
        return File::ShareDir::dist_dir('Treex-Core')."/?????"; # tady nekde kolem to po instalaci bude
    }
}

sub lib_core_dir {
    return caller_dir();
}

sub caller_dir {
    my %call_info;
    @call_info{
        qw(pack file line sub has_args wantarray evaltext is_require)
    } = caller(0);
    $call_info{file} =~ s/[^\/]+$//;
    return $call_info{file};
}




1;


__END__

=head1 NAME

Treex::Core::Config - centralized info about Treex configuration

=head1 SYNOPSIS

  bla bla

=head1 DESCRIPTION

info about the running Treex instance
(e.g. distinguishing development working copy from installed CPAN distribution)

=head1 FUNCTIONS

=over 4

=item lib_core_dir

   directory from which this code was executed


=item share_dir

   Treex shared directory (formerly TMT_SHARE)

=item pml_schema_dir

   directory with PML schema files

=item caller_dir

   directory containing the source code file that called this function


=item devel_version

   returns true if this code is executed within a Treex working copy, otherwise it is
   a part of an installed CPAN distribution and false is returned

=back

=head1 AUTHOR

Zdenek Zabokrtsky <zabokrtsky@ufal.mff.cuni.cz>

=head1 COPYRIGHT

Copyright 2010 Zdenek Zabokrtsky
This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README

