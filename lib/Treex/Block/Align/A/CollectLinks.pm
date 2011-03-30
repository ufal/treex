package Treex::Block::Align::A::CollectLinks;
use Moose;
use Treex::Common;
use autodie;
extends 'Treex::Core::Block';

has 'output' => (
    is            => 'ro',
    default       => '-',
    writer        => '_set_output',
    documentation => 'filename where to save the output',
);

has 'bigrams' => (
    is            => 'ro',
    isa           => 'Bool',
    default       => 1,
    documentation => 'print also bigram substitutions?',
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
    return if $atree->id =~ /[2-9]of/;    # because of re-segmentation
    my @nodes = $atree->get_descendants( { ordered => 1 } );
    my ( $last_form, $last_r_form, $last_r_ord ) = ( '<S>', '<S>', 0 );

    foreach my $node (@nodes) {
        my $r_node = $node->get_r_attr('align');
        my ( $r_form, $r_ord ) = $r_node ? ( $r_node->form, $r_node->ord ) : ( '', -2 );
        my $form = $node->form;

        # There are hacks in TectoMT that generate more tokens in one node,
        # e.g.: "v pondělí", "ve čtvrtek", "v tomto případě". TODO: fix this.
        # These nodes result in misleading alignments,
        # e.g. "v pondělí" -> "pondělí", so we should skip them.
        next if $form =~ / /;
        print { $self->output } "$form\t$r_form\n";

        # Two consecutive words are aligned to two consecutive words
        # either in the same order or swapped.
        if ( $self->bigrams ) {
            if ( $last_r_ord == $r_ord - 1 ) {
                print { $self->output } "$last_form $form\t$last_r_form $r_form\n";
            }
            elsif ( $last_r_ord == $r_ord + 1 ) {
                print { $self->output } "$last_form $form\t$r_form $last_r_form\n";
            }
            elsif ( $last_r_form ne '' && $r_form ne '' ) {
                print { $self->output } "$last_form $form\tNOT_ALIGNED\n";
            }
            else {
                print { $self->output } "$last_form $form\t$last_r_form$r_form\n";
            }
            ( $last_form, $last_r_form, $last_r_ord ) = ( $form, $r_form, $r_ord );
        }
    }

    return;
}

1;

# Copyright 2011 Martin Popel
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
