use strict;
use warnings;

package Treex::Core::Resource;
use LWP::Simple;
use File::Path;
use Treex::Core::Log;

sub require_file_from_share {
    my ( $rel_path_to_file, $who_wants_it ) = @_;
    my $file = "$ENV{TMT_ROOT}/share/$rel_path_to_file";
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
    }
    return;
}

1;

__END__


=head1 NAME

Treex::Core::Resources

=head1 DESCRIPTION

resources....
