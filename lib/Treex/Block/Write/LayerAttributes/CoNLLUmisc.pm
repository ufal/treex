package Treex::Block::Write::LayerAttributes::CoNLLUmisc;
use Moose;
use Treex::Core::Common;

with 'Treex::Block::Write::LayerAttributes::AttributeModifier';

has '+return_values_names' => ( default => sub { [''] } );

sub modify_single {

    my ( $self, $node ) = @_;

        my $wild = $node->wild();
        my $ord = $node->ord;
        my $form = $node->form;
        my $lemma = $node->lemma;

        my @misc;
        @misc = split(/\|/, $wild->{misc}) if(exists($wild->{misc}) && defined($wild->{misc}));

        # In the case of fused surface token, SpaceAfter=No may be specified for the surface token but NOT for the individual syntactic words.
        if($node->no_space_after() && !$node->is_fused())
        {
            unshift(@misc, 'SpaceAfter=No');
        }
        # If transliteration of the word form to Latin (or another) alphabet is available, put it in the MISC column.
        if(defined($node->translit()))
        {
            push(@misc, 'Translit='.$node->translit());
        }
        if(defined($node->wild()->{lemma_translit}) && $node->wild()->{lemma_translit} !~ m/^_?$/)
        {
            push(@misc, 'LTranslit='.$node->wild()->{lemma_translit});
        }
        ###!!! (Czech)-specific wild attributes that have been cut off the lemma.
        ###!!! In the future we will want to make them normal attributes.
        ###!!! Note: the {lid} attribute is now also collected for other treebanks, e.g. AGDT and LDT.
        if(exists($wild->{lid}) && defined($wild->{lid}))
        {
            if(defined($lemma))
            {
                push(@misc, "LId=$lemma-$wild->{lid}");
            }
            else
            {
                log_warn("UNDEFINED LEMMA: $ord $form $wild->{lid}");
            }
        }
        if(exists($wild->{lgloss}) && defined($wild->{lgloss}) && ref($wild->{lgloss}) eq 'ARRAY' && scalar(@{$wild->{lgloss}}) > 0)
        {
            my $lgloss = join(',', @{$wild->{lgloss}});
            push(@misc, "LGloss=$lgloss");
        }
        if(exists($wild->{lderiv}) && defined($wild->{lderiv}))
        {
            push(@misc, "LDeriv=$wild->{lderiv}");
        }
        if(exists($wild->{lnumvalue}) && defined($wild->{lnumvalue}))
        {
            push(@misc, "LNumValue=$wild->{lnumvalue}");
        }

    return join('|', @misc);
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Write::LayerAttributes::CoNLLUmisc

=head1 DESCRIPTION

Finds and returns the value of the CoNLL-U C<misc> field.
Based on L<Treex::Block::Write::CoNLLU>.

CAVEATS: Probably does not work correctly on fused nodes (untested).

=head1 AUTHOR

Daniel Zeman <zeman@ufal.mff.cuni.cz>

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2017 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
