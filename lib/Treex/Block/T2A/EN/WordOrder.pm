package Treex::Block::T2A::EN::WordOrder;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {

    my ( $self, $tnode ) = @_;

    # avoid coordinations
    return if ( $tnode->is_coap_root );

    # avoid leaves
    my @children = $tnode->get_children( { ordered => 1 } );
    return if ( !@children );

    # finite clauses
    if ( $tnode->formeme =~ /v:*.fin/ ) {

        # maintain SVO order
        my @subjects = _grep_formeme( 'n:subj',     \@children );
        my @objects  = _grep_formeme( 'n:obj[12]?', \@children );
        
        # skip questions and orders, for now (TODO fix them)
        return if ($tnode->sentmod ne 'enunc');

        foreach my $subject ( reverse @subjects ) {
            $self->shift_before_node($subject, $tnode) if ( !$subject->precedes($tnode) );
        }
        foreach my $object (@objects) {
            $self->shift_after_node($object, $tnode) if ( $object->precedes($tnode) );
        }

        # at most one element preceding the subject
        my @prec = grep { $_->precedes($tnode) } @children;
        my @prec_nosubj = _grep_formeme( '(?!(n:subj)).*', \@prec );
        my $last_obj = @objects ? $objects[-1] : $tnode;

        shift @prec_nosubj;
        foreach my $nosubj (@prec_nosubj) {
            $self->shift_after_node($nosubj, $last_obj);
        }
    }
    return;
}

# grep a list of nodes for a given formeme regexp, abstract away from coordinations
sub _grep_formeme {

    my ( $formeme, $nodes_rf ) = @_;

    return grep {
        $_->formeme =~ /^$formeme$/
            or
            ( $_->is_coap_root and any { $_->formeme =~ /^$formeme$/ } $_->get_echildren( { or_topological => 1 } ) )
    } @$nodes_rf;
}


# Moving t-nodes and a-nodes in parallel
sub shift_after_node {
    my ($self, $tnode_move, $tnode_dst) = @_;
    my $anode_move = $tnode_move->get_lex_anode();
    my $anode_dst = $tnode_dst->get_lex_anode();
    
    $tnode_move->shift_after_node($tnode_dst);
    if ($anode_move and $anode_dst){
        $anode_move->shift_after_node($anode_dst);
    }
}

sub shift_before_node {
    my ($self, $tnode_move, $tnode_dst) = @_;
    my $anode_move = $tnode_move->get_lex_anode();
    my $anode_dst = $tnode_dst->get_lex_anode();
    
    $tnode_move->shift_before_node($tnode_dst);
    if ($anode_move and $anode_dst){
        $anode_move->shift_before_node($anode_dst);
    }
}

1;
__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2A::EN::WordOrder

=head1 DESCRIPTION

Impose a few basic word ordering rules of English.

1) SVO order in the sentence

2) At most one non-subject element may precede a finite verb in a clause

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
