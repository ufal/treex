package Treex::Core::Resource;
#use Moose;
#use Treex::Core::Common;
use LWP::Simple;
use File::Path;
use Treex::Core::Log;
use Treex::Core::Config;

sub require_file_from_share {
    my ( $rel_path_to_file, $who_wants_it ) = @_;
    my $file = Treex::Core::Config::share_dir() . "/$rel_path_to_file";
    if ( not -e $file ) {
        log_info("Shared file '$rel_path_to_file' is missing by $who_wants_it.");
        my $url = "http://ufallab.ms.mff.cuni.cz/tectomt/share/$rel_path_to_file";
        log_info("Trying to download $url");

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
        chmod 0755, $file if $file =~ /installed_tools/;
    }
    return;
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

=item require_file_from_share($rel_path_to_file, $who_wants_it)

Helper method used in
L<Treex::Core::Block::get_required_share_files()|Treex::Core::Block/get_required_share_files>,
but it can be used also in Tools.

=back

=head1 AUTHOR

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
