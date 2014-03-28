package Treex::Tool::Flect::Classif;

use Moose;
use Treex::Core::Common;
use Treex::Tool::Python::RunFunc;

has _python => ( is => 'rw' );

has model_file => ( is => 'ro', isa => 'Str' );

has features => ( is => 'ro', isa => 'ArrayRef[Str]' );

has feature_types => ( is => 'ro', isa => 'ArrayRef[Str]' );

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
    $self->_python->command("from flect.classif import FlectClassifier");

    # load model (construct features definitions from the variables)
    my $model    = $self->model_file;
    my $features = '';
    if ( $self->features ) {
        $features = '\'features\': \'' . join( '|', @{ $self->features } ) . '\', ';
    }
    my $feature_types = '';
    if ( $self->feature_types ) {
        $feature_types = '\'feature_types\': \'' . join( '|', @{ $self->feature_types } ) . '\', ';
    }

    print join( '|', @{ $self->features } ), "\n";
    $self->_python->command("classif = FlectClassifier({'model_file': '$model', $features $feature_types })");
}

sub classify {
    my ( $self, $tokens ) = @_;

    my $sent = join( '\n', @$tokens );
    $sent = $self->_python->command("print classif.classify('$sent')");
    print $sent, "\n";
    my @forms = split / /, $sent;
    return \@forms;
}

1;
