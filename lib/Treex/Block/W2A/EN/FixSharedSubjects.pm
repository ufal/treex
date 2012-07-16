package Treex::Block::W2A::EN::FixSharedSubjects;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_anode {
    my ( $self, $anode ) = @_;

    # Find finite verbs without subject that are conjuncts
    return if !$anode->is_member;
    return if any { $_->afun eq 'Sb' } $anode->get_echildren();
    return if $anode->tag !~ /^V/;

    # Check if the first verb conjunct has a subject
    my $first_verb = $anode->get_siblings( { preceding_only => 1, first_only => 1 } );
    return if !$first_verb;
    return if $first_verb->tag !~ /^V/;
    my $subject = first { $_->afun eq 'Sb' } $first_verb->get_echildren();
    return if !$subject;

    # Make this subject shared for the whole conjunction.
    # Rehang also left siblings of subject to prevent non-projectivities (they are mostly shared as well).
    my $conjunction = $anode->get_parent();
    return if !$conjunction->is_coap_root();
    foreach my $n ( $subject, $subject->get_siblings( { preceding_only => 1 } ) ) {
        $n->set_parent($conjunction);
    }
    return;
}

1;

__END__
 
=head1 NAME

Treex::Block::W2A::EN::FixSharedSubjects - find subjects that should be shared modifiers of a coordination

=head1 DESCRIPTION

TODO

=head1 COPYRIGHT

Copyright 2012 Martin Popel
This file is distributed under the GNU General Public License v2 or later.
