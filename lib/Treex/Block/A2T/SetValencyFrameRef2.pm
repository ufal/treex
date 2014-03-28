package Treex::Block::A2T::SetValencyFrameRef2;

use Moose;
use Treex::Core::Common;
use Treex::Tool::Vallex::ValencyFrame;

extends 'Treex::Tool::Flect::FlectClassifBlock';

has 'valency_dict_name' => ( is => 'ro', isa => 'Str', required => 1 );

has 'valency_dict_prefix' => ( is => 'ro', isa => 'Str', default => '' );

has 'sempos_filter' => ( is => 'ro', isa => 'Str', default => '' );

sub process_ttree {

    my ( $self, $troot ) = @_;

    # apply sempos filter
    my $sempos_filter = $self->sempos_filter;
    my @tnodes = grep {
        my $sempos = $_->gram_sempos // '';
        $sempos =~ /$sempos_filter/
    } $troot->get_descendants( { ordered => 1 } );

    return if (!@tnodes);  # no nodes passed the filter in this sentence
    
    # classify using Flect
    my @classes = $self->classify_nodes(@tnodes);

    for ( my $i = 0; $i < @tnodes; ++$i ) {
        # model available: use its output
        if ($classes[$i] ne 'UNK'){
            $tnodes[$i]->set_val_frame_rf( $classes[$i] );
            $tnodes[$i]->wild->{val_frame_set} = 'ML';
        }
        # assign first frame for the given lemma, if no model is available and frames exist
        else {
            my $sempos = $tnodes[$i]->gram_sempos;
            next if ( !$sempos );
            $sempos =~ s/\..*//;
    
            my $t_lemma = $tnodes[$i]->t_lemma;
            $t_lemma =~ s/_/ /g;
    
            my ($frame) = Treex::Tool::Vallex::ValencyFrame::get_frames_for_lemma(
                $self->valency_dict_name, $self->language, $t_lemma, $sempos
            );
            next if ( !$frame );
    
            $tnodes[$i]->set_val_frame_rf( $self->valency_dict_prefix . $frame->id );
            $tnodes[$i]->wild->{val_frame_set} = 'VALLEX-1st';
        }
    }
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2T::SetValencyFrameRef2

=head1 DESCRIPTION

Assign valency frame references to the given valency lexicon, using the given model.
This implementation uses Flect (Python/Scikit-Learn) models.

Models and lexicons are preset in L<Treex::Block::A2T::CS::SetValencyFrameRef> and
L<Treex::Block::A2T::EN::SetValencyFrameRef> for Czech and English, respectively.

The block uses the classifier to assign valency frame references for t-lemmas where
sub-models are available. If submodel for a t-lemma is not available, the t-lemma
is looked up in the valency lexicon and the first available frame is assigned   
(if it exists).

=head1 PARAMETERS

=head2 sempos_filter

Use this parameter if you want to set valency frames eg. for verbs only
(sempos_filter=v). The filter is a regexp on the gram/sempos attribute of t-nodes.
The default is empty, ie. all nodes will be allowed to the classification.

=head1 NOTE

Please note that the current models take several minutes to load and require 6G of memory!

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
