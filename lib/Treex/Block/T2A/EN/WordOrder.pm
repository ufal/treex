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

        # skip imperatives, for now (TODO fix them)
        return if ( ( $tnode->sentmod // '' ) !~ /enunc|inter/ );

        # Maintain SVO order: move subjects and objects 
        my @subjects = _grep_formeme( 'n:subj',     \@children );
        my @objects  = _grep_formeme( 'n:obj[12]?', \@children );

        if ($tnode->sentmod eq 'enunc') {
            # Bla bla bla, said Mr. Brown is not SVO, but keep it
            if ( ( $tnode->t_lemma // '' ) ne 'say' ){
                foreach my $subject ( reverse @subjects ) {
                    $self->shift_before_node( $subject, $tnode ) if ( !$subject->precedes($tnode) );
                }
            }
            my $last_before_obj = ( !@subjects or $subjects[-1]->precedes($tnode) ) ? $tnode : $subjects[-1];
            foreach my $object ( reverse @objects ) {
                $self->shift_after_node( $object, $last_before_obj ) if ( $object->precedes($last_before_obj) );
            }

            # Let at most one element precede the subject
            my @prec = grep { $_->precedes($tnode) } @children;
            my @prec_nosubj = _grep_formeme( '(?!(n:subj)).*', \@prec );
            my $last_obj = @objects ? $objects[-1] : $tnode;

            my $first_nosubj = shift @prec_nosubj;
            # Allow two introductory elements in exceptional cases
            if ( $first_nosubj and $first_nosubj->is_leaf and ( ($first_nosubj->t_lemma // '') =~ /^(then|further|and)$/ ) ){
                shift @prec_nosubj;
            }
            foreach my $nosubj (@prec_nosubj) {
                $self->shift_after_node( $nosubj, $last_obj );
            }
        } elsif ($tnode->sentmod eq 'inter') {
            # objects
            foreach my $object ( reverse @objects ) {
                $self->shift_after_node( $object, $tnode ) if ( $object->precedes($tnode) );
            }
            # subjects
            # (later moved again in SbAuxvReorder)
            foreach my $subject ( reverse @subjects ) {
                $self->shift_after_node( $subject, $tnode );
            }
            # Let at most one element precede the verb
            my @prec = grep { $_->precedes($tnode) } @children;
            shift @prec;
            my $last_obj = @objects ? $objects[-1] : $tnode;
            foreach my $wrongprec (reverse @prec) {
                $self->shift_after_node( $wrongprec, $last_obj );
            }
            # wh*
            my @whs = grep { $_->t_lemma =~ /^wh(at|ich|om?|ere|en|y)|how$/ } @children;
            foreach my $wh (@whs) {
                $self->shift_before_node( $wh, $tnode );
            }
        }
    }
    # infinitives
    elsif ( $tnode->formeme eq 'v:to+inf' ){
        
        # move objects after infinitives
        my @objects  = _grep_formeme( 'n:obj[12]?', \@children );
        foreach my $object ( reverse @objects ) {
            $self->shift_after_node( $object, $tnode ) if ( $object->precedes($tnode) );
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
    my ( $self, $tnode_move, $tnode_dst ) = @_;
    my $anode_move = $tnode_move->get_lex_anode();
    my $anode_dst  = $tnode_dst->get_lex_anode();

    $tnode_move->shift_after_node($tnode_dst);
    if ( $anode_move and $anode_dst ) {
        $anode_move->shift_after_node($anode_dst);
    }
}

sub shift_before_node {
    my ( $self, $tnode_move, $tnode_dst ) = @_;
    my $anode_move = $tnode_move->get_lex_anode();
    my $anode_dst  = $tnode_dst->get_lex_anode();

    $tnode_move->shift_before_node($tnode_dst);
    if ( $anode_move and $anode_dst ) {
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

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014-2015 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
