package Treex::Core::Resource;

use strict;
use warnings;

use 5.010;

#use Moose;
#use Treex::Core::Common;
use LWP::Simple;    #TODO rewrite using LWP:UserAgent to show progress
use File::Path 2.08 qw(make_path);
use File::Spec;
use Treex::Core::Log;
use Treex::Core::Config;

use Exporter 'import';
use vars qw(@EXPORT_OK);
@EXPORT_OK = qw(require_file_from_share);

sub require_file_from_share {
    my ( $path_to_file, $who_wants_it, $make_executable ) = @_;
    
    # The following three cases are handled first
    #   ./relative_path
    #   ../relative_path
    #   /absolute_path
    # These files are not searched within Treex Share.
    if ($path_to_file =~ m|^[.]{0,2}/|) {
        log_debug("Looking for absolute or relative path $path_to_file\n");
        return $path_to_file if -e $path_to_file;
        my $file = File::Spec->rel2abs($path_to_file);
        log_fatal "Cannot find '$path_to_file'.\nNote that it starts with '/' or '.', so it is not search for within Treex Share.\nFile '$file' does not exist.\n";
    }

    my $writable;    #will store first writable directory found
    SEARCH:
    foreach my $resource_dir ( Treex::Core::Config->resource_path() ) {
        next if (!$resource_dir);
        my $file = File::Spec->catfile( $resource_dir, $path_to_file );
        log_debug("Trying $file\n");
        if ( -e $file ) {
            log_debug("Found $file\n");
            return $file;
        }
        if ( !defined $writable ) {
            if ( !-e $resource_dir ) {
                make_path($resource_dir);
            }
            if ( -d $resource_dir && -w $resource_dir ) {
                $writable = $resource_dir;
                log_debug("Found writable directory: $writable");
            }
        }
    }
    $who_wants_it = defined $who_wants_it ? " by $who_wants_it" : '';
    log_info("Shared file '$path_to_file' is missing$who_wants_it.");
    log_fatal("Cannot find writable directory for downloading from share") if !defined $writable;

    my $url = Treex::Core::Config->share_url() . "/$path_to_file";
    log_info("Trying to download $url");

    my $file = "$writable/$path_to_file";

    # first ensure that the directory exists
    my $directory = $file;
    $directory =~ s/[^\/]*$//;
    File::Path::mkpath($directory);

    # downloading the file using LWP::Simple
    my $response_code = getstore( $url, $file );

    if ( $response_code == 200 ) {
        log_info("Successfully downloaded to $file");
    }
    else {
        log_fatal(
            "Error when trying to download "
                . "$url and to store it as $file ($response_code)\n"
        );
    }

    # TODO: better solution
    if ( $file =~ /installed_tools/ || $make_executable ) {
        chmod 0755, $file;
    }
    return $file;
}

1;

__END__


=encoding utf-8

=head1 NAME

Treex::Core::Resource - Access to shared resources

=head1 SYNOPSIS

use Treex::Core::Resource qw(require_file_from_share);
my $path = require_file_from_share('relative/path/to/file/within/Treex/Share');
open my $MODEL, '<', $path or log_fatal($!);

# or
my $path = require_file_from_share('./relative/path/from/the/current/directory');
my $path = require_file_from_share('/absolute/path');

=head1 DESCRIPTION

This module provides access to shared resources (e.g. models). First it tries to locate it on local computer.
If not found, download from server (L<http://ufallab.ms.mff.cuni.cz/>).
If the path starts with "." or "/" it is searched in the local file system (and not in Treex Share).

=head1 SUBROUTINES

=over

=item require_file_from_share($path_to_file, $who_wants_it, $make_executable)

Try to locate file in local resource paths, if not found, try to download it and stores it to first writable path.
Obtains paths from L<Treex::Core::Config->resource_path()|Treex::Core::Config/resource_path>
Returns path to file.

=back

=head1 AUTHOR

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Tomáš Kraut <kraut@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011,2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
