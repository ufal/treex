package Treex::Block::A2A::CS::DetectClauses;

use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

has 'debug' => ( is => 'rw', isa => 'Bool', default => 0 );

binmode STDOUT, ":utf8";

sub process_bundle {
    my ( $self, $bundle ) = @_;

    my $source_zone = $bundle->get_zone( $self->language, $self->selector );
    my $source_root = $source_zone->get_atree;
    
    $source_root->{seed_type} = 'root';
    $source_root->set_clause_number(1);

    $self->plant_seeds( 2, $source_root, $source_root, not $self->debug );
    $self->add_compound_verbs( $source_root, $source_root );
    _add_coords( $source_root, $source_root );
    
    $self->complete_clauses( $source_root, $source_root );
    $self->resolve_boundaries($source_root);
    $self->normalize_clause_ords($source_root);
}

sub add_compound_verbs {
    my ( $self, $node, $root, $noset ) = @_;
    my @children = $node->get_children( { ordered => 1 } );
    foreach (@children) {
        $self->add_compound_verbs( $_, $root, $noset );
    }
    ## compound verbs
    foreach my $child ( grep { $_->clause_number } @children ) {
        next if not $node or not $node->get_parent;
        my @parent = $child->get_eparents ( { ordered=>1 } );
        #if ( $parent[0]->afun eq 'Coord' and not $child->is_member ) {
        #    push @parent, grep { $_->is_member and not $_->clause_number } $parent[0]->get_children;
        #}
        my $is_verb   = $child->tag =~ /^V[Bpf]/;
        foreach my $parent (@parent) {
            if (    $parent
                and $parent->tag
                and
                (
                    # === 1 ==== ma-li
                    ($is_verb and $parent eq $parent[0] and $parent->lemma =~ /^li$/)

                    # === 4 === auxiliary verb
                    or ($child->afun eq 'AuxV')
                )
                )
            {
                if ( not $parent->clause_number ) {
                    $parent->set_clause_number( $child->clause_number );
                    $parent->{seed_type} = $child->{seed_type};
                }
                else {
                    $child->set_clause_number( $parent->clause_number );
                    last;
                }
            }
        }
    }
}
sub _add_coords {
    my ( $node, $root ) = @_;
    my @children = $node->get_children;
    foreach my $child (@children) {
        _add_coords( $child, $root );
    }
    return if not $node->get_parent;    #root
    return if $node->clause_number;

    #propagate is_member
    if ( $node->afun !~ /Coord|Apos/ ) {
        foreach my $child (@children) {
            $node->set_clause_number( $child->clause_number )
                if $child->is_member;
        }
    }
    
    if ( $node->tag =~ /^J,/  or $node->afun =~ /AuxC/ ) {
        my @children = grep { $_->clause_number } $node->get_children( { following_only => 1 } );
        if (@children) {
            $node->set_clause_number( $children[-1]->clause_number );
            return; 
        }
    }
    
    @children = grep {
        $_->clause_number and ( $_->is_member or ( $_->afun !~ /Coord|Apos/ and grep { $_->is_member } $_->get_children ) )
    } @children;

    return if not @children;
    
    if ( $node->tag =~ /^J\^/ or $node->afun =~ /Coord/ ) {
        $node->set_clause_number( $children[0]->clause_number );
        $node->{seed_type} = $children[0]->{seed_type};
    }

    
}

sub plant_seeds { 
    my ( $self, $clause_number, $node, $root, $silent, $noset ) = @_;

    # preorder seed identification to allow filtering on parent's seed_type
    my @children = $node->get_children( { ordered => 1 } );
    
    foreach (@children) {
  
        my $new_seed   = 0;
        my $new_clause = $clause_number;
  
        ## === finite verb or imperative
        if ( $_->tag =~ /^V[Bpi]/ and $_->lemma !~ /_,t/ ) {
            $_->{seed_type} = 'Verb';
        }

        if ( $_->{seed_type} ) {
            print {*STDERR} $_->id . " seed #" . $_->{seed_type} . "\n" unless $silent;
            $clause_number++ if $new_clause == $clause_number;
            $_->set_clause_number($new_clause);
        }
      
    }
      
    foreach my $child (@children) {
        $clause_number = $self->plant_seeds( $clause_number, $child, $root, $silent, $noset );
    }
    return $clause_number;

}

sub _is_boundary {
    my $node  = shift;
    my $lemma = $node->lemma;

    return 4 if $lemma =~ m/^(?:\(|\[|\{|\)|\]|\})$/;
    return 3 if $lemma =~ m/^(?:-|–|-|—|'|\\|„|“|“|”|"||«|»|‛|‘|’|‹|›)$/;
    return 2 if $lemma =~ m/^(?:,|‚|:|;|\.|\?|!|)$/;
   
    if ( $node->tag =~ m/^J\^/ or $node->afun =~ /Coord/ ) {
        my $parent = $node->get_parent;
        return 1
            unless $parent
            and $parent->tag
            and ( $parent->tag =~ /^J,/ or $parent->afun eq 'AuxC' )
            and not $node->get_children
        ;
    }
    return 0;
}

sub complete_clauses {
    my ( $self, $node, $copy_from ) = @_;


    my @children = $node->get_children( { ordered => 1 } );

    foreach my $child (@children){
        if ( not $child->clause_number ) {
            
            if ( $node->tag and ( $node->tag =~ /^J\^/ or $node->afun =~ /Coord/ ) ) {
                
                my @right_siblings = grep {
                        $_->clause_number
                    and $_->is_member
                    and $_->ord > $child->ord
                    and
                    (
                           ( $node->ord > $child->ord && $_->ord < $node->ord )
                        or ( $node->ord < $child->ord )
                    )
                } @children;

                my @left_siblings = grep {
                        $_->clause_number
                    and $_->is_member
                    and $_->ord < $child->ord
                    and
                    (
                           ( $node->ord < $child->ord && $_->ord > $node->ord )
                        or ( $node->ord > $child->ord)
                    )
                } @children;

                $copy_from = $right_siblings[0] || $left_siblings[-1] || $node;

                my $n = $node;
                while ( $n->get_parent and ( $n->tag =~ /^J\^/ or $n->afun =~ /Coord/ ) ) {
                    $n->set_clause_number( $copy_from->clause_number );
                    $n = $n->get_parent;
                }
            }
            elsif ( $node->tag and ( $node->lemma =~ /^být/ and $node->afun =~ /Apos/ ) ) {
                my $first_child = $node->get_children( {first_only => 1} );
                $copy_from = $node unless $first_child->id eq $child->id;
            }
            else {
              $copy_from = $node; #copy from parent; 
            }
            $child->set_clause_number( $copy_from->clause_number );
        }
        elsif ( $node->tag and ( $node->tag =~ /^J\^/ or $node->afun =~ /Coord/ ) and $child->is_member ) {
            $node->set_clause_number( $child->clause_number );
        }
        $self->complete_clauses( $child, $copy_from );
    }

    #(ze kdyz #1), (#2)
    if ( $node->tag and ( $node->tag =~ /^J,/ or $node->afun eq 'AuxC' ) ) {

        #neresi vsuvku ihned za podradici spojkou
        my $old_clause_number = $node->get_parent->clause_number || '';
        my @desc              = $node->get_descendants( { following_only => 1 } );
        if (@desc) {
            my $new_clause_number = undef;
            if ( _is_boundary( $desc[0] ) > 1 ) {
                my @next_ord = grep { $_->clause_number } $node->get_children( { following_only => 1 } );
                $new_clause_number = @next_ord ? $next_ord[-1]->clause_number : undef;
            }
            else {
                my @next_ord = grep { $_->clause_number } @desc;
                $new_clause_number = @next_ord ? $next_ord[0]->clause_number : undef;
            }
            if ($new_clause_number) {
                $node->set_clause_number($new_clause_number);
                my $parent = $node->get_parent;

                #stejně jako
                if ( $parent and $parent->lemma and $node->lemma =~ /^jako/ and $parent->lemma =~ /^stejně/ ) {
                    $parent->set_clause_number($new_clause_number);
                }

                #compound subordinate expression: i <- kdyz
                foreach my $desc ( $node->get_children ){
                    if ( $desc->clause_number and $desc->clause_number eq $old_clause_number ) {
                        $desc->set_clause_number($new_clause_number);  
                    }
                }
            }
        }
    }
}

sub normalize_clause_ords {
    my ( $self, $root ) = @_;
    my $i               = 1;
    my %reord           = ();
    my @all_nodes       = grep { $_->clause_number } $root->get_descendants( { ordered => 1 } );
    map {
        if ( not exists $reord{ $_->clause_number } ) {
            $reord{ $_->clause_number } = $i;
            $i++;
        }
    } @all_nodes;
    foreach my $node (@all_nodes) {
        $node->set_clause_number( $reord{ $node->clause_number } );
    }
}

sub resolve_boundaries {
    my ( $self, $root ) = @_;
    my @ordered_nodes   = $root->get_descendants( { ordered => 1 } );
    my $last_clause     = 0;
    my @last_boundaries = ();
    foreach my $node (@ordered_nodes) {
        if ( _is_boundary($node) ) {
            $node->set_clause_number(undef);  
        }
    }
    while (@ordered_nodes) {
        my $node = shift @ordered_nodes;
        if ( $node->clause_number) {
            $last_clause = $node->clause_number;
            @last_boundaries = ();
        }
        else {
            my $next_clause = 0;
            my @prev_child  = grep { $_->clause_number } $node->get_children( { preceding_only => 1 });
            my @next_child  = grep { $_->clause_number } $node->get_children( { following_only => 1 });
            my $parent = $node->get_parent;
            if ( @prev_child and @next_child and ( $prev_child[-1]->clause_number || '' ) eq ( $next_child[0]->clause_number || '' ) ) {
                if ( @last_boundaries and $last_clause == $next_child[0]->clause_number ){
                    $_->set_clause_number($next_child[0]->clause_number) for @last_boundaries;
                }
                if ( @last_boundaries or $last_clause == $next_child[0]->clause_number ) {
                    $node->set_clause_number( $next_child[0]->clause_number );
                }
                $last_clause = $next_child[0]->clause_number;
                next;
            }
            foreach my $next_node (@ordered_nodes) {
                if ( $next_node->clause_number ){
                    $next_clause = $next_node->clause_number;
                    last;
                }
            }
            if ( $next_clause and $last_clause and $next_clause == $last_clause ){
                $node->set_clause_number($last_clause);
            }
            elsif ( ($next_clause == 0 or $last_clause == 0 ) and _is_boundary($node) < 2 ) {
                if ( @last_boundaries and $last_clause == ($next_clause || $last_clause) ){
                    $_->set_clause_number( $next_clause || $last_clause ) for @last_boundaries;
                }
                $node->set_clause_number( $next_clause || $last_clause );
                $last_clause = $next_clause || $last_clause;
            }
            else {
                $node->set_clause_number(0);
                push @last_boundaries, $node;
            }
        }
    }
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2A::CS::DetectClauses

=head1 DESCRIPTION

Baseline detection of clauses. Each segment marked as separate clause. Depth of clauses not distinguished, defaults to zero.

=head1 PARAMETERS

=over

=item C<debug>

=back

=head1 AUTHOR

Jan Popelka <popelka@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
