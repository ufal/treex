package Treex::Core::Config;
use strict;
use warnings;

use 5.010;    # operator //
use File::HomeDir 0.97;
use File::ShareDir;
use File::Spec;
use File::Slurp 9999;    # prior versions has different interface
use Cwd qw(realpath);
use Treex::Core::Log;
use YAML 0.72 qw(LoadFile DumpFile);

# this should be somehow systematized, since there will be probably many switches like this one
our $debug_run_jobs_locally;    ## no critic (ProhibitPackageVars)
our %service;                   ## no critic (ProhibitPackageVars)

# 0: Treex::Core::Common::pos_validated_list() called if params needed, skipped otherwise
# 1: Treex::Core::Common::pos_validated_list() called always
# 2: MooseX::Params::Validate::pos_validated_list called always
our $params_validate = 0;       ## no critic (ProhibitPackageVars)

my $config = __PACKAGE__->_load_config();

sub _load_config {
    my $self = shift;
    my %args = @_;
    my $from = $args{from} // $self->config_file();
    my $yaml = read_file($from, {err_mode => 'silent'});
    my $toReturn = YAML::Load($yaml);
    return $toReturn // {}; #rather than undef return empty hashref
}

sub _save_config {
    my $self = shift;
    my %args = @_;
    my $to   = $args{to} // $self->config_file();
    return DumpFile( $to, $config );
}

END {
    __PACKAGE__->_save_config();
}

sub config_dir {
    my $self = shift;
    my $dirname = $ENV{TREEX_CONFIG} // File::Spec->catdir( File::HomeDir->my_home(), '.treex' );
    if ( !-e $dirname ) {
        mkdir $dirname;
    }
    if ( -d $dirname ) {
        return $dirname;
    } else {
        return File::HomeDir->my_dist_config( 'Treex-Core', { create => 1 } );
    }
}

sub config_file {
    my $self = shift;
    return File::Spec->catfile( $self->config_dir(), 'config.yaml' );
}

sub _default_resource_path {
    my $self = shift;
    my @path;
    push @path, File::Spec->catdir($self->config_dir(), 'share' );
    push @path, File::HomeDir->my_dist_data( 'Treex-Core', { create => 0 } ) ;
    if ( defined $ENV{TMT_ROOT} ) {
        push @path, realpath( $ENV{TMT_ROOT} . '/share' );
    }
    return @path if wantarray;
    return \@path;
}

sub resource_path {
    my $self = shift;
    my @path;
    if ( defined $config->{resource_path} ) {
        @path = @{ $config->{resource_path} };
    }
    else {
        @path = $self->_default_resource_path();
        $config->{resource_path} = \@path;
    }
    return @path if wantarray;
    return \@path;
}

sub _devel_version {
    my $self = shift;
    return -d $self->lib_core_dir() . "/share/";

    # to je otazka, jak to co nejelegantneji poznat, ze jde o work.copy. a ne nainstalovanou distribuci
}

sub share_dir {
    my $self = shift;
    if ( defined $config->{share_dir} ) {
        return $config->{share_dir};
    }
    else {
        my $share_dir;

        # return File::HomeDir->my_home."/.treex/share"; # future solution, probably symlink
        if ( _devel_version() ) {
            $share_dir = realpath( $self->lib_core_dir() . "/../../../../share/" ); # default on UFAL machines
        }
        else {
            $share_dir = File::Spec->catdir($self->config_dir(), 'share' ); # by default take ~/.treex/share
        }
        $config->{share_dir} = $share_dir;
        return $share_dir;

    }
}

sub share_url {
    my $self = shift;
    $config->{share_url} = 'http://ufallab.ms.mff.cuni.cz/tectomt/share' if !defined $config->{share_url};
    return $config->{share_url};
}

sub tred_dir {
    my $self = shift;
    $config->{tred_dir} = realpath( $self->share_dir() . '/tred/' ) if !defined $config->{tred_dir};
    return $config->{tred_dir};
}

sub pml_schema_dir {
    my $self = shift;
    if (!defined $config->{pml_schema_dir}) {
        if ( _devel_version() ) {
            $config->{pml_schema_dir} = realpath( $self->lib_core_dir() . "/share/tred_extension/treex/resources/" );
        }
        else {
            $config->{pml_schema_dir} = realpath( File::ShareDir::dist_dir('Treex-Core') . "/tred_extension/treex/resources/" ); #that's different share than former TMT_SHARE
        }
    }
    return $config->{pml_schema_dir};
}

# tenhle adresar ted vubec v balicku neni!
sub tred_extension_dir {
    my $self = shift;
    $config->{tred_extension_dir} = realpath( $self->pml_schema_dir() . "/../../" ) if !defined $config->{tred_extension_dir};
    return $config->{tred_extension_dir};
}

sub lib_core_dir {
    my $self = shift;
    return realpath( _caller_dir() );
}

sub tmp_dir {
    my $self = shift;
    $config->{tmp_dir} = $self->_default_tmp_dir() if !defined $config->{tmp_dir};
    return $config->{tmp_dir};
}

sub _default_tmp_dir {
    my $self = shift;
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
  print "TrEd in available in " . Treex::Core::Config->tred_dir . "\n";
  print "PML schema is available in " . Treex::Core::Config->pml_schema_dir . "\n";

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
