package Treex::Block::W2A::JA::SetAfunParticles;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_atree {
    my ( $self, $a_root ) = @_;

    # 0) Get all particle nodes with empty afun (so leave already filled values intact)
    my @all_nodes = grep { !$_->afun && $_->tag =~ /^Joshi/ } $a_root->get_descendants();
    
    # 1) Fill Coord (coordinating conjunctions).
    foreach my $node (@all_nodes) {
      $node->set_afun('Coord') if is_coord($node);
    }
    
    # 2) Now we can use effective children (without diving), since Coord is filled.
    foreach my $node ( grep { !$_->afun } @all_nodes ) {
        my $aux_afun = get_Particle_afun($node) or next;
        $node->set_afun($aux_afun);
    }

    return 1;
}

sub is_coord {
    my ($node) = @_;
    return any { $_->is_member } $node->get_children();
}

sub get_Particle_afun {
    my ($node) = @_;
    my $tag = $node->tag;
    my $lemma = $node->lemma;

    # we treat adverbial particles same way as adverbs
    return 'Adv' if $tag =~ /-FukuJoshi-/;

    return 'AuxC' if $tag =~ /SetsuzokuJoshi/;

    # According to HamleDT, the interrogative particles should be AuxO
    return 'AuxO' if ( $tag =~ /Shūjoshi/ && scalar ($node->get_children()) == 0); 

    # Coordinationg particles that are not the head of the coordination get AuxY
    return 'AuxY' if $tag =~ /Heiritsujoshi/;

    return 'AuxP' if $tag =~ /^Joshi/;

    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::W2A::JA::SetAfunParticles

=head1 DECRIPTION

Fills afun attributes for particles.
C<Coord> (coordinating conjunctions), C<AuxC> (subordinating conjunctions), C<Adv> (adverbial particles), C<AuxY> (coordinating conjunctions, which are not Coord), C<AuxO> (interrogatives), C<AuxP> (and the rest).
This block doesn't change already filled afun values.

=head1 AUTHOR

Dušan Variš <varis@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut


