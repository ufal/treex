package Treex::Core::Resource;
use strict;
use warnings;

#use Moose;
#use Treex::Core::Common;
use LWP::Simple;
use File::Path;
use Treex::Core::Log;
use Treex::Core::Config;

use Exporter 'import';
use vars qw(@EXPORT_OK);
@EXPORT_OK = qw(require_file_from_share);

sub require_file_from_share {
    my ( $rel_path_to_file, $who_wants_it, $make_executable ) = @_;
    my $writable;    #will store first writable directory found
    SEARCH:
    foreach my $resource_dir ( Treex::Core::Config::resource_path() ) {
        my $file = "$resource_dir/$rel_path_to_file";
        return $file if -e $file;
        $writable = $resource_dir if not defined $writable and -w $resource_dir;
    }

    log_info("Shared file '$rel_path_to_file' is missing by $who_wants_it.");
    log_fatal("Cannot find writable directory for downloading from share") if not defined $writable;

    my $url = "http://ufallab.ms.mff.cuni.cz/tectomt/share/$rel_path_to_file";
    log_info("Trying to download $url");

    my $file = "$writable/$rel_path_to_file";

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
    if ( $file =~ /installed_tools/ or $make_executable ) {
        chmod 0755, $file;
    }
    return $file;
}

1;

__END__


=encoding utf-8

=head1 NAME

Treex::Core::Resources

=head1 DESCRIPTION

resources....

=head1 SUBROUTINES

=over

=item require_file_from_share($rel_path_to_file, $who_wants_it, $make_executable)

Helper method used in
L<Treex::Core::Block::get_required_share_files()|Treex::Core::Block/get_required_share_files>,
but it can be used also in Tools.

=back

=head1 AUTHOR

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Tomáš Kraut <kraut@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
