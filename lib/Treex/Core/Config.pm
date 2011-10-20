package Treex::Core::Config;
use strict;
use warnings;

use File::HomeDir 0.97;
use File::ShareDir;
use File::Slurp 9999;
use Cwd qw(realpath);
use Treex::Core::Log;

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
    return join q{:}, @path;
}

sub resource_path {
    my $path_file = config_dir() . '/path';
    my @lines = read_file( $path_file, err_mode => 'silent' );
    my @path;
    foreach my $entry ( map { split /:/ } @lines ) {
        chomp $entry;
        push @path, $entry;
    }
    if ( not defined $path[0] ) {
        @path = default_resource_dir();
        write_file( $path_file, { no_clobber => 1, err_mode => 'silent' }, join q{:}, @path )
    }
    return @path if wantarray;
    return join q{:}, @path;
}

sub _devel_version {
    return -d lib_core_dir() . "/share/";

    # to je otazka, jak to co nejelegantneji poznat, ze jde o work.copy. a ne nainstalovanou distribuci
}

sub share_dir {

    # return File::HomeDir->my_home."/.treex/share"; # future solution, probably symlink
    if ( _devel_version() ) {
        return realpath( lib_core_dir() . "/../../../../share/" );
    }
    else {
        return realpath( File::ShareDir::dist_dir('Treex-Core') );
    }
}

sub share_url {
    return 'http://ufallab.ms.mff.cuni.cz/tectomt/share';
}

sub tred_dir {
    return realpath( share_dir() . '/tred/' );
}

sub pml_schema_dir {

    if ( _devel_version() ) {
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

sub tmp_dir {
    my $dot_treex = File::HomeDir->my_dist_data( 'Treex-Core', { create => 1 } );
    my $suffix    = 'tmp';
    my $tmp_dir   = realpath("$dot_treex/$suffix");
    if ( !-e $tmp_dir ) {
        mkdir $tmp_dir or log_fatal("Cannot create temporary directory");
    }
    return $tmp_dir;
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
  print "TrEd in available in " . Treex::Core::Config::tred_dir . "\n";
  print "PML schema is available in " . Treex::Core::Config::pml_schema_dir . "\n";

=head1 DESCRIPTION

This module provides information about the current installed Treex framework,
for instance paths to its components.

=head1 FUNCTIONS

=over 4

=item config_dir()

returns directory where configuration of Treex will reside (currently just F<path> file)

=item default_resource_dir()

returns default path for resources, it uses dist data for C<Treex-Core> and if $TMT_ROOT variable set also $TMT_ROOT/share

=item resource_path()

return list of directories where resources will be searched

=item tmp_dir()

return temporary directory, shoud be used instead of /tmp or similar

=item _devel_version()

returns C<true> iff the current Treex instance is running from the svn working copy
(which means that it is the development version, not installed from CPAN)

=item lib_core_dir()

returns the directory in which this module is located (and where
the other L<Treex::Core> modules are expected too)

=item share_dir()

returns the Treex shared directory (formerly C<$TMT_SHARE>)

=item share_url()

returns base url from shared data are downloaded

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
