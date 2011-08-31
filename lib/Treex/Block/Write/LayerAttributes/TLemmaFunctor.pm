package Treex::Block::Write::LayerAttributes::TLemmaFunctor;
use Moose;
use Treex::Core::Common;

with 'Treex::Block::Write::LayerAttributes::AttributeModifier';

has '+return_values_names' => ( default => sub { [ '' ] } );

# Return the t-lemma and sempos
sub modify {

    my ($self, $tlemma, $functor) = @_;

    return if ( !defined($functor) );

    return '' if ( $functor !~ m/^(ACT|PAT|ADDR|ORIG|EFF)$/ );
    return ( $tlemma );
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Write::LayerAttributes::TLemmaFunctor

=head1 SYNOPSIS

    my $modif = Treex::Block::Write::LayerAttributes::TLemmaFunctor->new();
    my $parent_tlemma = 'ministr';
    my $functor = 'RSTR';   

    print $modif->modify( $parent_tlemma, $functor ); # prints ''
    
    my $parent_tlemma = 'vládnout';
    my $functor = 'ACT';
    
    print $modif->modify( $parent_tlemma, $functor ); # prints 'vládnout'  

=head1 DESCRIPTION

A text modifier for blocks using L<Treex::Block::Write::LayerAttributes> which takes the C<t_lemma> of the node's 
(effective) parent the C<functor> of the node itself. If the functor is an actant, it returns the parent's C<t_lemma>,
if not, it returns an empty value (so that all adverbials are grouped, but actants split according to the parent 
t-lemma).

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
