package Treex::Core::Config;
use strict;
use warnings;

use File::HomeDir;
use File::ShareDir;
use File::Slurp;
use Cwd qw(realpath);

# this should be somehow systematized, since there will be probably many switches like this one
our $debug_run_jobs_locally;    ## no critic (ProhibitPackageVars)
our %service;                   ## no critic (ProhibitPackageVars)

# 0: Treex::Core::Common::pos_validated_list() called if params needed, skipped otherwise
# 1: Treex::Core::Common::pos_validated_list() called always
# 2: MooseX::Params::Validate::pos_validated_list called always
our $params_validate = 0;       ## no critic (ProhibitPackageVars)

sub config_dir {
    return File::HomeDir->my_dist_config( 'Treex-Core', { create => 1 } );
}

sub default_resource_dir {
    my @path = ( File::HomeDir->my_dist_data( 'Treex-Core', { create => 1 } ) );
    if ( defined $ENV{TMT_ROOT} ) {
        push @path, realpath( $ENV{TMT_ROOT} . '/share' );
    }
    return @path if wantarray;
    return join ':', @path;
}

sub resource_path {
    my $path_file = config_dir() . '/path';
    my @path;
    local $/;
    $/ = ':';
    @path = read_file( $path_file, err_mode => 'silent' );
    if ( not defined $path[0] ) {
        @path = default_resource_dir();
        write_file( $path_file, { no_clobber => 1, err_mode => 'silent' }, join $/,@path )
    }
    return @path;
}

sub devel_version {
    return -d lib_core_dir() . "/share/";

    # to je otazka, jak to co nejelegantneji poznat, ze jde o work.copy. a ne nainstalovanou distribuci
}

sub share_dir {

    # return File::HomeDir->my_home."/.treex/share"; # future solution, probably symlink
    if ( devel_version() ) {
        return realpath( lib_core_dir() . "/../../../../share/" );
    }
    else {
        return realpath( File::ShareDir::dist_dir('Treex-Core') );
    }
}

sub tred_dir {
    return realpath( share_dir() . '/tred/' );
}

sub pml_schema_dir {

    if ( devel_version() ) {
        return realpath( lib_core_dir() . "/share/tred_extension/treex/resources/" );
    }
    else {
        return realpath( File::ShareDir::dist_dir('Treex-Core') . "/tred_extension/treex/resources/" );
    }
}

# tenhle adresar ted vubec v balicku neni!
sub tred_extension_dir {
    return realpath( pml_schema_dir() . "/../../" );
}

sub lib_core_dir {
    return realpath( _caller_dir() );
}

sub tmp_dir {    #!!! to be replaced with ~/.treex/tmp !!!
    return realpath( lib_core_dir . "/../../../../tmp/" );
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

=encoding utf-8

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

returns C<true> iff the current Treex instance is running from the svn working copy
(which means that it is the development version, not installed from CPAN)

=item lib_core_dir()

returns the directory in which this module is located (and where
the other L<Treex::Core> modules are expected too)

=item share_dir()

returns the Treex shared directory (formerly C<$TMT_SHARE>)

=item pml_schema_dir()

return the directory in which the PML schemata for .treex files are located

=item tred_dir()

the directory in which the tree editor TrEd is installed


=item tred_extension_dir

the directory in which the TrEd extension for Treex files is stored

=back


=head1 AUTHOR

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Tomáš Kraut <kraut@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
