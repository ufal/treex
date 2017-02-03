package Treex::Block::Write::LayerAttributes::CoNLLUfeats;
use Moose;
use Treex::Core::Common;
use Lingua::Interset qw(encode);

with 'Treex::Block::Write::LayerAttributes::AttributeModifier';

has '+return_values_names' => ( default => sub { [''] } );

sub modify_single {

    my ( $self, $node ) = @_;
        
            my $isetfs = $node->iset();
            if ($isetfs->get_nonempty_features()) {
                my $upos_features = encode('mul::uposf', $isetfs);
                my ($upos, $feat) = split(/\t/, $upos_features);
                return $feat;
            } else {
                return '';
            }
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Write::LayerAttributes::CoNLLUfeats

=head1 DESCRIPTION

Finds and returns the value of the CoNLL-U C<feats> field.
Based on L<Treex::Block::Write::CoNLLU>.

=head1 AUTHOR

Daniel Zeman <zeman@ufal.mff.cuni.cz>

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2017 by Institute of Formal and Applied Linguistics, 
Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
