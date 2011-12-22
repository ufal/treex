package Treex::Block::Write::BaseTextWriter;
use Moose;
use Treex::Core::Common;
use autodie;
use Encode 'decode';

extends 'Treex::Block::Write::BaseWriter';

has encoding => (
    isa           => 'Str',
    is            => 'ro',
    default       => 'utf8',
    documentation => 'Output encoding. \'utf8\' by default.',
);

has to_bundle_attr => (
    isa           => 'Str',
    is            => 'ro',
    documentation => 'set to an attribute name and the string per bundle will go there',
);


around 'process_bundle' => sub {
    
    my ($orig, $self, $bundle) = @_;

    if (defined $self->to_bundle_attr) {

        # Open a temp file handle redirected to string
        my $output = '';
        my $fh = undef;
        open $fh, '>', \$output; # we use autodie
        binmode( $fh, ":utf8" );
        $self->_file_handle($fh);

        # call the main process_bundle
        $self->$orig(@_);

        # Close the temp file handle
        close $fh;
        $self->_file_handle(undef);

        # Store the output
        chomp($output);
        $bundle->set_attr($self->to_bundle_attr, decode("utf8", $output));
    } else {
        # call the main process_bundle
        $self->$orig(@_);
    }
};

around '_open_file_handle' => sub {
    
    my ( $orig, $self, $filename ) = @_;
    my $handle = $self->$orig($filename);

    binmode( $handle, ':' . $self->encoding );
    return $handle;     
};

1;