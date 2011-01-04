package Treex::Core::Runner;

use Moose;
use MooseX::FollowPBP;

use Treex::Core;

has 'filenames' => (
    is => 'rw',
    isa => 'ArrayRef',
);

has 'opt_eval_code' => (
    is => 'rw',
);

has 'opt_save' => (
    is => 'rw',
);


sub run {
    my ($self) = @_;


    foreach my $file (@{$self->get_filenames}) {
        print "Loading $file\n";
        my $document = Treex::Core::Factory->createDocumentFromFile($file);
        #    eval_code();
        eval $self->get_opt_eval_code;
        if ($self->get_opt_save) {
            print "Saving $file\n";
            $document->save;
        }
    }
}

1;
