package Treex::Tool::Flect::Base;

use Moose;
use Treex::Core::Common;
use Treex::Tool::Python::RunFunc;

has _python => ( is => 'rw' );

has model_file => ( is => 'ro', isa => 'Str' );

has features => ( is => 'ro', isa => 'ArrayRef[Str]' );

has additional_features => ( is => 'ro', isa => 'ArrayRef[Str]' );

sub BUILD {

    my ( $self, $params ) = @_;

    # test Flect installation
    my $file = __FILE__;
    $file =~ s/\/[^\/]*$//;
    if ( !-d $file . '/flect' ) {
        log_warn('Flect not installed. Trying to download from GitHub...');
        system("git clone git\@github.com:UFAL-DSG/flect.git $file/flect") == 0 || die('Could not install Flect');
    }

    $self->_set_python( Treex::Tool::Python::RunFunc->new() );

    # initialize (add Flect to libraries)
    $self->_python->command("import sys\nsys.path.append(b'$file/flect')");
    $self->_python->command("from flect.flect import SentenceInflector");

    # load model (construct features definitions from the variables)
    my $model    = $self->model_file;
    my $features = '';
    if ( $self->features ) {
        $features = '\'features\': \'' . join( '|', @{ $self->features } ) . '\', ';
    }
    my $add_features = '';
    if ( $self->additional_features ) {
        $add_features = '\'additional_features\': [\'' . join( '\', \'', @{ $self->additional_features } ) . '\'],';
    }
    $self->_python->command("infl = SentenceInflector({'model_file': '$model', $features $add_features})");
}

sub inflect_sentence {
    my ( $self, $tokens ) = @_;

    my $sent = join( ' ', @$tokens );
    $sent = $self->_python->command("print infl.inflect_sent('$sent')");
    my @forms = split / /, $sent;
    return \@forms;
}

1;
