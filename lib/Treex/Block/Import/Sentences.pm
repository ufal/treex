package Treex::Block::Import::Sentences;
use Moose;

use Treex::Core::Common;

extends 'Treex::Core::Block';

has 'from' => ( is => 'ro', isa => 'Treex::Core::Files', required => 1, coerce => 1 );

sub process_document {
    my ($self, $doc) = @_;

    my @bundles = $doc->get_bundles();
    my $bundle_count = scalar @bundles;

    while (my $line = $self->from->next_line()) {
        chomp $line;
        if ($line =~ /^\s*$/) {
            if (@bundles < $bundle_count) {
                log_fatal "Number of lines in the file to import does not correspond with number of bundles in the processed documents";
            }
            next;
        }
        my $bundle = shift @bundles;
        my $new_zone = $bundle->create_zone($self->language, $self->selector);
        $new_zone->set_sentence($line);

        last if (!@bundles);
    }
}

1;
