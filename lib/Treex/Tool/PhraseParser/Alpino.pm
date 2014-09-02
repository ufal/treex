package Treex::Tool::PhraseParser::Alpino;

use Moose;
use Treex::Core::Common;
use ProcessUtils;

use Treex::Block::Read::Alpino qw(create_subtree);

has '_twig'               => ( is => 'rw' );
has '_alpino_readhandle'  => ( is => 'rw' );
has '_alpino_writehandle' => ( is => 'rw' );
has '_alpino_pid'         => ( is => 'rw' );

sub BUILD {

    my $self      = shift;
    my $tool_path = 'installed_tools/parser/Alpino';
    my $exe_path  = require_file_from_share("$tool_path/bin/Alpino");

    #TODO this should be done better
    my $redirect = Treex::Core::Log::get_error_level() eq 'DEBUG' ? '' : '2>/dev/null';

    my @command = ( $exe_path, 'end_hook=xml_dump', '-parse' );

    $SIG{PIPE} = 'IGNORE';    # don't die if parser gets killed
    my ( $reader, $writer, $pid ) = ProcessUtils::bipipe_noshell( ":encoding(utf-8)", @command );

    $self->_set_alpino_readhandle($reader);
    $self->_set_alpino_writehandle($writer);
    $self->_set_alpino_pid($pid);

    $self->_set_twig( XML::Twig::->new() );

    return;
}

sub parse_zones {
    my ( $self, $zones_rf ) = @_;

    my $writer = $self->{writer};
    my $reader = $self->{reader};

    foreach my $zone (@$zones_rf) {

        # Take the (tokenized) sentence
        my @forms = map { $_->form } $zone->get_atree->get_descendants( { ordered => 1 } );

        # Have Alpino parse the sentence
        print $writer join( " ", @forms ) . "\n";
        my $line = <$reader>;

        if ( $line !~ /^<xml/ ) {
            log_fatal( 'Unexpected Alpino input: ' . $line );
        }
        my $xml = $line;
        while ( $line and $line !~ /^<\/alpino_ds/ ) {
            $line = <$reader>;
            $xml .= $line;
        }

        # Create a p-tree out of Alpino's output
        if ( $zone->has_ptree ) {
            $zone->remove_tree('p');
        }
        my $proot = $zone->create_ptree;
        $self->_twig->setTwigRoots(
            {
                alpino_ds => sub {
                    my ( $twig, $xml ) = @_;
                    $twig->purge;
                    $proot->set_phrase('top');
                    foreach my $node ( $xml->first_child('node')->children('node') ) {
                        create_subtree( $node, $proot );
                    }
                }
            }
        );
        $self->_twig->parse($xml);
    }

}

1;

__END__


