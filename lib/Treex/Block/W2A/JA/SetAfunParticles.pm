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

    # we treat adverbial particles same way as adverbs
    return 'Adv' if $node->tag =~ /-FukuJoshi-/;

    return 'AuxC' if $node->tag =~ /SetsuzokuJoshi/;

    # we need to set different Afun for "て" particle (for now we treat it like aux verb)
    #return 'AuxV' if ( $node->form eq "て" && $node->tag =~ /Setsuzoku/ ) ;

    return 'AuxP' if $node->tag =~ /^Joshi/ ;

    return;
}

1;

__END__

=head1 NAME

Treex::Block::W2A::JA::SetAfunParticles

=head1 DECRIPTION

Fills afun attributes for particles.
C<Coord> (coordinating conjunctions), C<AuxC> (subordinating conjunctions), C<Adv> (Adverbial particles) C<AuxP> (and the rest).
This block doesn't change already filled afun values 

=head1 AUTHORS

Dusan Varis


