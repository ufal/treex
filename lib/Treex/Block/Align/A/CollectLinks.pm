package Treex::Block::Align::A::CollectLinks;
use Moose;
use Treex::Moose;
use autodie;
extends 'Treex::Core::Block';

has 'output' => (
    is            => 'ro',
    default       => '-',
    writer        => '_set_output',
    documentation => 'filename where to save the output',
);

sub _build_language { log_fatal "Language must be given"; }

sub BUILD {
    my ($self) = @_;
    if ( $self->output eq '-' ) {
        $self->_set_output( \*STDOUT );
    }
    else {
        open my $F, '>:utf8', $self->output;
        $self->_set_output($F);
    }
    return;
}

sub process_atree {
    my ( $self, $atree ) = @_;
    return if $atree->id =~ /[2-9]of/; # because of re-segmentation
    my @nodes = $atree->get_descendants( { ordered => 1 } );
    my $doc = $atree->get_document();
    foreach my $node (@nodes) {
        my $aligned_word = '';
        if ( $node->get_attr('align') ) {
            $aligned_word = $doc->get_node_by_id( $node->get_attr('align') )->form;
        }
        print { $self->output } $node->form . "\t" . $aligned_word . "\n";
    }

    return;
}

1;

# Copyright 2011 Martin Popel
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
