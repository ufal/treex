package Treex::Block::Print::SentencesWithValencyFrames;
use Moose;
use Treex::Core::Common;
use Treex::Tool::Vallex::ValencyFrame;
extends 'Treex::Block::Write::BaseTextWriter';

has '+language' => ( required => 1 );

has '+extension' => ( default => '.txt' );

has 'valency_dict_name' => ( is => 'ro', isa => 'Str', required => 1 );

sub process_atree {

    my ( $self, $aroot ) = @_;
    my @anodes = $aroot->get_descendants( { ordered => 1 } );
    my $sent_id = $aroot->get_document->file_stem . '#' . $aroot->get_bundle->id;

    for ( my $i = 0; $i < @anodes; ++$i ) {

        my ($tnode)    = $anodes[$i]->get_referencing_nodes('a/lex.rf');
        my ($tgold) = $tnode ? $tnode->get_aligned_nodes_of_type('alignsame') : undef;
        my ($tali) = $tnode ? $tnode->get_aligned_nodes_of_type('copy') : undef;

        # we have alignment predicted -> gold, with at least one of them having valency frame set
        if ($tnode
            and $tgold
            and ( ( $tnode->gram_sempos // '' ) eq 'v' )
            and ( $tnode->val_frame_rf or $tgold->val_frame_rf )
            )
        {
            # get sentence text, with lex. anode of current verb highlighted
            my $sent_text  = '';
            for ( my $j = 0; $j < @anodes; ++$j ) {
                $sent_text .= ' ' . ( $i != $j ? $anodes[$j]->form : '-->' . $anodes[$j]->form . '<--' );
            }
            $sent_text =~ s/^\s*//;
            $sent_text =~ s/\s*\r?\n?$//;
            
            # get aligned (other language) sentence text, with aligned anode highlighted
            my $ali_sent_text = '';
            if ($tali){
                my ($aali) = $tali->get_anodes();
                if ($aali){
                    foreach my $ali_anode ( $aali->get_root->get_descendants({ordered=>1}) ){
                        $ali_sent_text .= ' ' .  ( $ali_anode != $aali ? $ali_anode->form : '-->' . $ali_anode->form . '<--' );
                    }
                }
            }
            $ali_sent_text =~ s/^\s*//;
            $ali_sent_text =~ s/\s*\r?\n?$//;

            my $pred_frame = $self->_get_frame($tnode);
            my $gold_frame = $self->_get_frame($tgold);
            print { $self->_file_handle } $tnode->t_lemma, "\t",
                ( ( $tnode->val_frame_rf // '' ) eq ( $tgold->val_frame_rf // '' ) ? '*' : '!' ), "\t",
                ( $pred_frame ? $pred_frame->to_string({formemes=>0, id=>1, note=>1}) : '---' ), "\t",
                ( $gold_frame ? $gold_frame->to_string({formemes=>0, id=>1, note=>1}) : '---' ), "\t",
                $sent_id, "\t", $sent_text, "\t", $ali_sent_text, "\n";
        }
    }
}

sub _get_frame {
    my ( $self, $tnode ) = @_;
    my $frame_id = $tnode->val_frame_rf;

    return if ( !$frame_id );

    $frame_id =~ s/^.*#//;

    return Treex::Tool::Vallex::ValencyFrame::get_frame_by_id(
        $self->valency_dict_name, $self->language, $frame_id
    );
}

1;


__END__

=encoding utf-8

=head1 NAME

Treex::Block::Print::SentencesWithValencyFrames

=head1 DESCRIPTION

Printing sentences with assigned valency frames for valency frame assignment debugging.

Output format, tab-separated on one line:
* t-lemma
* '*' for correctly assigned, '!' for errors
* predicted valency frame
* golden valency frame (alignment links of type 'alignsame' must lead from predicted to golden data)
* sentence id (document file stem + bundle id)
* sentence text, with the word in question marked with '--> <--'
* aligned sentence text, with aligned word marked with '--> <--' (if applicable)

If there are more verbal valency frames set in the sentence, this will produce output for
each one of them, i.e. the same sentence will appear multiple times on the output.

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014-2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
