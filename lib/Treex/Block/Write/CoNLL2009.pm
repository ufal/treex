package Treex::Block::Write::CoNLL2009;

use strict;
use warnings;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::CoNLLX';

my %FALLBACK_FOR = ( 'pos' => 'tag', 'deprel' => 'afun', );

sub process_atree {
    my ( $self, $atree ) = @_;

    # if only random sentences are printed
    return if rand() > $self->randomly_select_sentences_ratio;
    foreach my $anode ( $atree->get_descendants( { ordered => 1 } ) ) {
        my ( $lemma, $pos, $cpos, $deprel ) =
            map { $self->get_attribute( $anode, $_ ) }
            (qw(lemma pos cpos deprel)); # "conll/" will be prefixed if needed; see get_attribute()

        #my $ctag  = $self->get_coarse_grained_tag($tag);

        # append suffices to afuns
        my $suffix = '';
        $suffix .= 'M' if $self->is_member_within_afun            && $anode->is_member;
        $suffix .= 'S' if $self->is_shared_modifier_within_afun   && $anode->is_shared_modifier;
        $suffix .= 'C' if $self->is_coord_conjunction_within_afun && $anode->wild->{is_coord_conjunction};
        $deprel .= "_$suffix" if $suffix;

        my $feat;
        if ( $self->feat_attribute eq 'conll/feat' && defined $anode->conll_feat() ) {
            $feat = $anode->conll_feat();
        }
        elsif ( $self->feat_attribute eq 'iset' && $anode->get_iset_pairs_list() ) {
            $feat = $anode->get_iset_conll_feat();
        }
        else {
            $feat = '_';
        }
        my $p_ord = $anode->get_parent->ord;
        # Make sure that values are not empty and that they do not contain spaces.
        my @values = ($anode->ord, $anode->form, $lemma, '_', $pos, '_', $feat, '_', $p_ord, '_', $deprel, '_', '_', '_', '_', '_', '_', '_');
        @values = map
        {
            my $x = $_ // '_';
            $x =~ s/^\s+//;
            $x =~ s/\s+$//;
            $x =~ s/\s+/_/g;
            $x = '_' if($x eq '');
            $x
        }
        (@values);
        print { $self->_file_handle } join( "\t", @values ) . "\n";
    }
    print { $self->_file_handle } "\n" if $atree->get_descendants;
    return;
}

1;

__END__

=head1 NAME

Treex::Block::Write::CoNLL2009

=head1 DESCRIPTION

Document writer for CoNLL2009 format, one token per line.

=head1 PARAMETERS

=over

=item encoding

Output encoding. C<utf8> by default.

=item to

The name of the output file, STDOUT by default.

=item deprel_attribute

The name of attribute which will be printed into the 8th column (dependency relation).
Default is C<autodetect> which tries first C<conll/deprel>
and if it is not defined then C<afun>.

=item pos_attribute

The name of attribute which will be printed into the 5th column (part-of-speech tag).
Default is C<autodetect> which tries first C<conll/pos>
and if it is not defined then C<tag>.

=item cpos_attribute

The name of attribute which will be printed into the 4th column
(coarse-grain part-of-speech tag).
Default is C<conll/cpos>.

=item feat_attribute

The name of attribute which will be printed into the 6th column (features).
Default is C<_> which means that an underscore will be printed instead of the features.
Possible values are C<conll/feat> and C<iset>.


=back

=head1 METHODS

=over

=item process_document

Saves the document.

=back

=head1 AUTHOR

David Mareček, Daniel Zeman, Martin Popel

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
