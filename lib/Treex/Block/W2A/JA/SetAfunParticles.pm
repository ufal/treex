package Treex::Block::W2A::JA::SetAfunParticles;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_atree {
    my ( $self, $a_root ) = @_;

    # TODO : Distinguish particle classes? (now we treat almost all of them like prepositions)

    # 0) Get all particle nodes with empty afun (so leave already filled values intact)
    my @all_nodes = grep { !$_->afun && $_->tag =~ /^Joshi/ } $a_root->get_descendants();
    
    # 1) Fill Coord (coordinating conjunctions).
    foreach my $node (@all_nodes) {
       # TODO: fix this
       # if ( is_coord($node) ) { $node->set_afun('Coord'); }
    }
    
    # Now we can use effective children (without diving), since Coord is filled.
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

    # we treat adverbial particles same way as adverbs
    return 'Adv' if $node->tag =~ /_FukuJoshi_/;

    # we need to set different Afun for "て" particle (for now we treat it like aux verb)
    return 'AuxV' if ( $node->form eq "て" && $node->tag =~ /Setsuzoku/ ) ;

    return 'AuxP' if $node->tag =~ /^Joshi/ ;

    return;
}

1;

__END__

=head1 NAME

Treex::Block::W2A::JA::SetAfunParticles

=head1 DECRIPTION

Fills afun attributes for particles.
C<Coord> (coordinating conjunction), C<AuxP> (we treat almost every particle as preposition). C<AuxV> is used for particle "て".
We also set C<Adv> for adverbial particles.
This block doesn't change already filled afun values 

=head1 AUTHORS

Dusan Varis


