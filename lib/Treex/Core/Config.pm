package Treex::Core::Config;
use strict;
use warnings;

use File::HomeDir;
use File::ShareDir;

# this should be somehow systematized, since there will be probably many switches like this one 
our $debug_run_jobs_locally; ## no critic (ProhibitPackageVars)
our %service; ## no critic (ProhibitPackageVars)

# 0: Treex::Moose::pos_validated_list() called if params needed, skipped otherwise
# 1: Treex::Moose::pos_validated_list() called always
# 2: MooseX::Params::Validate::pos_validated_list called always
our $params_validate = 0; ## no critic (ProhibitPackageVars)

sub devel_version {
    return $ENV{TMT_ROOT};

    # return -d lib_core_dir()."/share/";
    # to je otazka, jak to co nejelegantneji poznat, ze jde o work.copy. a ne nainstalovanou distribuci
}

sub share_dir {

    #return $ENV{TMT_ROOT} . "/share/";    # temporary
    #                                      # return File::HomeDir->my_home."/.treex/share"; # future solution, probably symlink
    if ( devel_version() ) {
        return $ENV{TMT_ROOT} . "/share/";

        #return lib_core_dir() . "/share/";
    }
    else {
        return File::ShareDir::dist_dir('Treex-Core')
            . "/";
    }
}

sub tred_dir {
    return share_dir() . 'tred/';
}

sub pml_schema_dir {

    if ( devel_version() ) {
        return lib_core_dir() . "/share/tred_extension/treex/resources/";
    }
    else {
        return File::ShareDir::dist_dir('Treex-Core')
            . "/tred_extension/treex/resources/";
    }
}

# tenhle adresar ted vubec v balicku neni!
sub tred_extension_dir {
    return pml_schema_dir() . "/../../";
}

sub lib_core_dir {
    return _caller_dir();
}

sub _caller_dir {
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

  use Treex::Core::Config;
  print "TrEd in availabe in " . Treex::Core::Config::tred_dir . "\n";
  print "PML schema is available in " . Treex::Core::Config::pml_schema_dir . "\n";

=head1 DESCRIPTION

This module provides information about the current installed Treex framework,
for instance paths to its components.

=head1 FUNCTIONS

=over 4

=item devel_version()

   returns true iff the current Treex instance is running from the svn working copy
   (which means that it is the development version, not installed from CPAN)

=item lib_core_dir()

   returns the directory in which this module is located (and where
   the other Treex::Core modules are expected too)

=item share_dir()

   returns the Treex shared directory (formerly TMT_SHARE)

=item pml_schema_dir()

   return the directory in which the PML schemata for .treex files are located

=item tred_dir()

   the directory in which the tree editor TrEd is installed


=item tred_extension_dir

   the directory in which the TrEd extension for Treex files is stored

=back


=head1 AUTHOR

Zdenek Zabokrtsky

=head1 COPYRIGHT AND LICENSE

Copyright 2010 by UFAL

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
