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

    my %seeds;
    _plant_seeds( \%seeds, 1, $source_root, $source_root, not $self->debug );

    my %clause_head;
    my $clause_number = 0;
    foreach my $seed ( sort { $a->ord <=> $b->ord } values %seeds ) {

        #        $verb_node->set_clause_number($clause_number);
        $clause_head{ $seed->clause_number } = $seed;
        $clause_number = $seed->clause_number
            if $seed->clause_number > $clause_number;

        #           $clause_number++;
    }

    ## compound verbs
    foreach my $node ( values %clause_head ) {
        my @parent = ( $node->get_parent );
        next if not @parent or not $parent[0]->get_parent;
        if ( $parent[0]->afun eq 'Coord' and not $node->is_member ) {
            push @parent, grep { $_->is_member and not $_->clause_number } $parent[0]->get_children;
        }
        my $is_finite = $node->tag =~ /^V[Bp]/;
        my $has_child = $node->get_children;
        my $cnt       = 0;
        foreach my $parent (@parent) {
            if (    $parent
                and $parent->tag
                and
                (

                    # === 1 ==== ma-li
                    ( $is_finite and $parent eq $parent[0] and $parent->lemma =~ /^li$/ )

                    # === 2 === byl napsan [Vs] bude mit [Vf]
                    or ( $is_finite and $parent->tag =~ /^V[sf]/ )

                    # === 3 === napsali [Vp] jsme [VB]
                    or ( $parent->tag =~ /^Vp/ and not $has_child )
                )
                )
            {
                $cnt += $parent eq $parent[0] ? 1 : 2;
                if ( not $parent->clause_number ) {
                    $parent->set_clause_number( $node->clause_number );
                    $parent->{seed_type} = $node->{seed_type};
                }
                else {
                    $node->set_clause_number( $parent->clause_number );
                }
                $clause_head{ $node->clause_number } = $parent;
            }
        }

        # if($cnt > 1) {
        #     print "DEBUG coordinated ", $bundle->get_document->full_filename, "\t", $node->attr( 'alignment/counterpart.rf'), "\n";
        # }
    }
    ## join multiple seed forming a flat apos/embed entity
    my %same_parent;
    map { push @{ $same_parent{ $_->get_parent } }, $_; }
        grep { $_->{seed_type} =~ /_member/ } values %clause_head;
    foreach my $common_parent ( keys %same_parent ) {
        my @join_childs = @{ $same_parent{$common_parent} };
        my $first_child = shift @join_childs;
        push @join_childs, $first_child->get_parent
            if ( $first_child->get_parent->{seed_type} || '' ) =~ /_root/;
        if (@join_childs) {
            foreach my $child (@join_childs) {
                $child->set_clause_number( $first_child->clause_number );
            }
        }
    }
    _add_coords( $source_root, $source_root );

    #return;
    _complete_clauses($source_root);

    #in case the top level clause is a fragment without seed
    if ( not $source_root->clause_number ) {
        $source_root->set_clause_number( $clause_number + 1 );
        _complete_clauses($source_root);
    }
    _normalize_clause_ords($source_root);

}

sub _plant_seeds {
    my ( $seeds_rf, $clause_number, $node, $root, $silent ) = @_;

    # preorder seed identification to allow filtering on parent's seed_type
    my @children = $node->get_children( { ordered => 1 } );

    foreach (@children) {

        my $new_seed   = 0;
        my $new_clause = $clause_number;

        my $parent            = $_->get_parent;
        my $first_child       = $_->get_children( { first_only => 1 } );
        my $last_child        = $_->get_children( { last_only => 1 } );
        my @following_child   = $_->get_children( { following_only => 1 } );
        my @preceding_child   = $_->get_children( { preceding_only => 1 } );
        my @following_sibling = $_->get_siblings( { following_only => 1, add_self => 1 } );
        my @preceding_sibling = $_->get_siblings( { preceding_only => 1, add_self => 1 } );
        my @apos_end          = grep { _is_boundary($_) > 2 } $_->get_siblings( { following_only => 1 } );
        my @apos_start        = grep { _is_boundary($_) > 2 } $_->get_siblings( { preceding_only => 1 } );
        my @embed_end         = grep { _is_boundary($_) > 3 } $_->get_siblings( { following_only => 1 } );
        my @embed_start       = grep { _is_boundary($_) > 3 } $_->get_siblings( { preceding_only => 1 } );
        my $first_sibling     = $_->get_siblings( { first_only => 1 } );
        my $last_sibling      = $_->get_siblings( { last_only => 1 } );

        # === Apos first type (boundaries as children) root => new seed
        if (    #$_->afun =~ /Apos|Coord/
            grep     { _is_boundary($_) > 2 } @preceding_child
            and grep { _is_boundary($_) > 2 } @following_child
            )
        {
            $_->{seed_type} = 'Apos_root1';
        }

        # === Apos first type (boundaries as children) childern => same as root
        elsif (    # ($parent->afun||'') =~ /Apos|Coord/
            ( grep { _is_boundary($_) > 2 } @preceding_sibling )
            and ( grep { _is_boundary($_) > 2 } @following_sibling or $following_sibling[-1] eq $_ )
            and ( $parent->{seed_type} || '' ) =~ /_root/
            and ( $preceding_sibling[0] ne $following_sibling[-1] )
            )
        {
            $_->{seed_type} = 'Apos_member1';
            $new_clause = $parent->clause_number;
        }

        # === embedded ( children ) as seeds (lze spolecne rozviti)
        elsif (
            (   @apos_start
                and _is_boundary( $apos_start[0] )
                > 3
                and @apos_end and _is_boundary( $apos_end[-1] ) > 3
                and $_->ord > $apos_start[0]->ord
                and not $parent->{seed_type}
            )
            )
        {
            $_->{seed_type} = 'Embed_member2';
        }

        # === Apos second type (first boundary as root, second as last child
        elsif (
                $parent->get_parent
            and $parent->afun =~ /Apos/
            and _is_boundary($parent)
            > 2
            and $_->is_member and $_->ord > $parent->ord
            and ( not @following_child or @apos_end )
            )
        {
            $_->{seed_type} = 'Apos_root2';
        }

        # === embedded --subtree-- as
        elsif (
                @embed_start
            and @embed_end
            and ( $embed_start[0] ne $first_sibling or $embed_end[-1] ne $last_sibling or $parent->ord < $_->ord )
            and (
                    $parent
                and $parent->tag !~ /^(?:V[Bp]|J,)/
                and not $parent->{seed_type}
            )
            )
        {
            $_->{seed_type} = 'Embed_member1';
        }

        # === parenthesis root
        elsif (
            $_->is_parenthesis_root
            and ( ( $first_child and _is_boundary($first_child) > 2 ) or (@apos_end) )
            )
        {
            $_->{seed_type} = 'Parenth_root_member';
        }

        # === finite verb or imperative
        elsif (
                $_->tag =~ /^V[Bpi]/
            and $_->form ne 'viz'
            )
        {
            $_->{seed_type} = 'Verb';
        }

        if ( $_->{seed_type} ) {
            print {*STDERR} $_->id . " seed #" . $_->{seed_type} . "\n" unless $silent;
            $clause_number++ if $new_clause == $clause_number;
            $_->set_clause_number($new_clause);
            $seeds_rf->{$_} = $_
        }

    }

    foreach my $child (@children) {
        $clause_number = _plant_seeds( $seeds_rf, $clause_number, $child, $root, $silent );
    }
    return $clause_number;

}

sub _add_coords {
    my ( $node, $root ) = @_;
    my $yep = $node->id eq 'a_tree-cs_test-s6-n2479';
    my @children = $node->get_children;
    foreach my $child (@children) {
        _add_coords( $child, $root );
    }
    return if $node->clause_number;
    @children = grep { $_->clause_number and ( $_->{seed_type} || '' ) !~ /_member/ } @children;
    @children = grep { $_->clause_number == $children[0]->clause_number } @children;
    return if not @children;
    my $has_member = grep { $_->is_member } @children;
    my $has_member2 = grep { $_->is_member } map { $_->get_children } grep { $_->tag !~ /Coord|Apos/ } @children;
    if ($yep) {
        print {*STDERR} "Has MEMBER = ", ( $has_member ? 1 : 0 ), "\t", ( $has_member2 ? 1 : 0 ), "\t",
            ( $children[0]->is_member ? 1 : 0 ), "\n";
    }
    if (
        @children and (
            ( not $node->get_parent )    #root
            or ( $node->tag =~ /^J,/ and $children[0]->ord > $node->ord )      #subordinating conjunction should precede node
            or ( $node->tag =~ /^J\^/ and ( $has_member or $has_member2 ) )    #coordinating conjunction does not have to
            or ( $node->afun eq 'Coord' and $node->lemma !~ /^resp/ and $has_member )    #coordination by Z:
        )
        )
    {
        $node->set_clause_number( $children[0]->clause_number );
        $node->{seed_type} = $children[0]->{seed_type};
    }
    elsif (
        @children and (
            ( $node->afun eq 'Coord' and $node->lemma =~ /^resp/ )
        )
        )
    {
        $node->set_clause_number( $children[-1]->clause_number );
        $node->{seed_type} = $children[-1]->{seed_type};
    }
}

sub _is_boundary {
    my $node = shift;
    return 4 if $node->lemma =~ m/^(?:\(|\[|\{|\)|\]|\})$/;
    return 3 if $node->lemma =~ m/^(?:-|–|-|—)$/;          #/(?:'|\\|„|“|“|”|"||«|»|‛|‘|’|‹|›)$/
    return 2 if $node->lemma =~ m/^(?:,|‚|:|;|\.|\?|!|)$/;

    #   return 1 if $node->tag =~ m/^J\^/;
    return 0;
}

sub _complete_clauses {
    my ( $node, $clause_number ) = @_;

    $clause_number = ( $node->{seed_type} || '' ) =~ /_root/
        ? $clause_number : $node->clause_number;

    my @children = $node->get_children;

    foreach my $child (@children) {
        if ( $clause_number and not $child->clause_number ) {
            $child->set_clause_number($clause_number)
        }
        _complete_clauses( $child, $clause_number );
    }
}

sub _normalize_clause_ords {
    my $root      = shift;
    my $i         = 1;
    my %reord     = ();
    my @all_nodes = grep { $_->clause_number } $root->get_descendants( { ordered => 1 } );
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
