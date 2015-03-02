package Treex::Tool::Alpino::Run;

use Moose::Role;
use LWP::Simple;

use Treex::Core::Log qw(log_info log_warn log_fatal);
use Treex::Core::Resource qw(require_file_from_share);

has '_alpino_readhandle'  => ( is => 'rw', reader => '_alpino_readhandle',  writer => '_set_alpino_readhandle' );
has '_alpino_writehandle' => ( is => 'rw', reader => '_alpino_writehandle', writer => '_set_alpino_writehandle' );
has '_alpino_pid'         => ( is => 'rw', reader => '_alpino_pid',         writer => '_set_alpino_pid' );

my $EXE        = 'bin/Alpino';
my $ALPINO_WEB = 'http://www.let.rug.nl/~vannoord/alp/Alpino/binary/versions/';

sub _start_alpino {

    my ( $self, @args ) = @_;

    my $tool_path;

    # Alpino is installed somewhere, we'll just use it
    if ( $ENV{ALPINO_HOME} ) {
        $tool_path = $ENV{ALPINO_HOME};
        log_info( 'Running Alpino from $ALPINO_HOME=' . $tool_path );
    }

    # Find the path to Alpino in SHARE
    else {

        # This should always succeed for properly set-up share (it won't download anything, just create the directory)
        $tool_path = require_file_from_share( 'installed_tools/parser/Alpino', ref $self, 0, 1 );

        # Check if we actually have Alpino there and install it if not
        if ( !-x "$tool_path/$EXE" ) {
            log_warn("Alpino not found. Trying to download it from RUG website...");

            my $listing = get($ALPINO_WEB);
            log_fatal( 'Could not get a list of Alpino versions from ' . $ALPINO_WEB ) if ( !$listing );

            # This will find the last link to Alpino-something on the website, we assume it's the latest
            my ($last_version) = ( $listing =~ m/^.*(<a[^>]*href="Alpino-[^"]*)"/s );
            $last_version =~ s/<a[^>]*href="//;
            log_fatal( 'Could not find a reference to an Alpino version on ' . $ALPINO_WEB ) if ( !$last_version );

            log_info( 'Downloading from ' . $ALPINO_WEB . $last_version . '... ' );

            # Download it, unpack and verify we have the main executable file
            my $arc_path = $tool_path;
            $arc_path =~ s/Alpino$//;

            my $ret = getstore( $ALPINO_WEB . $last_version, $arc_path . $last_version );
            log_fatal( 'Could not download ' . $ALPINO_WEB . $last_version . ': HTTP code ' . $ret ) if ( $ret != 200 );

            log_info("Unpacking $arc_path$last_version...");
            system("tar -xzf \"$arc_path$last_version\" -C \"$arc_path\"") == 0 or log_fatal( 'Could not unpack ' . $arc_path );

            log_fatal('Could not find downloaded Alpino executable') if ( !-x "$tool_path/$EXE" );
            
            # Delete the tar.gz archive after unpacking
            system("rm \"$arc_path$last_version\"") == 0 or log_warn( 'Could not delete ' . $arc_path );

            log_info( 'Alpino is now installed in ' . $tool_path );
        }
        else {
            log_info( 'Found Alpino installation in ' . $tool_path );
        }

        # set the path as an environment variable to be passed to Alpino
        $ENV{ALPINO_HOME} = $tool_path;
    }

    # Start Alpino with given arguments, force line-buffering of its output (otherwise it will hang)
    my @command = ( 'stdbuf', '-oL', "$tool_path/$EXE", @args );

    $SIG{PIPE} = 'IGNORE';    # don't die if Alpino gets killed
    my ( $reader, $writer, $pid ) = Treex::Tool::ProcessUtils::verbose_bipipe_noshell( ":encoding(utf-8)", @command );

    $self->_set_alpino_readhandle($reader);
    $self->_set_alpino_writehandle($writer);
    $self->_set_alpino_pid($pid);

    return;
}

1;
