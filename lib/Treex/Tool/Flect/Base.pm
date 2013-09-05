package Treex::Tool::Flect::Base;

use Moose;
use Treex::Core::Common;
use Treex::Tool::Python::RunFunc;
use List::MoreUtils "pairwise";

has _python => ( is => 'rw' );

has model_file => ( is => 'ro', isa => 'Str' );


sub BUILD {

    my ( $self, $params ) = @_;

    # test Flect installation
    my $file = __FILE__;
    $file =~ s/\/[^\/]*$//;
    if (! -d $file . '/flect' ){
        log_warn('Flect not installed. Trying to download from GitHub...');
        system("git clone git\@github.com:UFAL-DSG/flect.git $file/flect") == 0 || die ('Could not install Flect');
    }
    
    $self->_set_python(Treex::Tool::Python::RunFunc->new());
    # initialize (add Flect to libraries)
    $self->_python->command("import sys\nsys.path.append(b'$file/flect')");
    $self->_python->command("from lib.flect import SentenceInflector");
    # load model
    my $model = $self->model_file;
    $self->_python->command("infl = SentenceInflector({'model_file': '$model'})");
}


sub inflect_sentence {
    my ($self, $lemmas, $poses) = @_;
    
    my $sent = join(' ', pairwise { our $a . '|' . our $b } @$lemmas, @$poses);
    $sent = $self->_python->command("print infl.inflect_sent('$sent')");
    my @forms = split / /, $sent;
    return \@forms;
}


1;