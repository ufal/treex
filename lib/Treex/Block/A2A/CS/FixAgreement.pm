package Treex::Block::A2A::CS::FixAgreement;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';

has '+language'       => ( required => 1 );
has 'source_language' => ( is       => 'rw', isa => 'Str', required => 1 );
has 'source_selector' => ( is       => 'rw', isa => 'Str', default => '' );
has 'log_to_console'  => ( is       => 'rw', isa => 'Bool', default => 0 );
has 'magic'           => ( is       => 'rw', isa => 'Str', default => '' );
has 'dont_try_switch_number' => ( is => 'rw', isa => 'Bool', default => '0' );

use Carp;

use Treex::Tool::Depfix::CS::FormGenerator;
use Treex::Tool::Depfix::CS::TagHandler;

my $formGenerator;

sub process_start {
    my $self = shift;

    $formGenerator  = Treex::Tool::Depfix::CS::FormGenerator->new();

    return;
}

# this sub is to be to be redefined in child module
sub fix {
    croak 'abstract sub fix() called';

=over

=item sample of body of sub fix:

    my ( $self, $dep, $gov, $d, $g ) = @_;

    if (1) {    #if something holds

        #do something here

        $self->logfix1( $dep, "some change was made" );
        $self->regenerate_node( $gov, $g->{tag} );
        $self->logfix2($dep);
    }

=back

=cut

}

# alignment mapping
my %en_counterpart;

# named entities mapping
my %is_named_entity;

sub process_zone {
    my ( $self, $zone ) = @_;

    # get alignment mapping
    my $en_root = $zone->get_bundle->get_tree(
        $self->source_language, 'a', $self->source_selector
    );
    foreach my $en_node ( $en_root->get_descendants ) {
        my ( $nodes, $types ) = $en_node->get_aligned_nodes();
        if ( $nodes->[0] ) {
            $en_counterpart{ $nodes->[0]->id } = $en_node;
        }
    }

    # TODO hash NER results into %is_named_entity

    #do the fix for each node
    my $a_root = $zone->get_atree;
    foreach my $node ( $a_root->get_descendants() ) {
        next if $node->isa('Treex::Core::Node::Deleted');
        my ( $dep, $gov, $d, $g ) = $self->get_pair($node);
        next if !$dep;
        $self->fix( $dep, $gov, $d, $g );
    }

    return;
}

# nice name
sub get_en_counterpart {
    my ( $self, $node ) = @_;
    return $en_counterpart{ $node->id };
}

# quick-to-write name
sub en {
    my ( $self, $node ) = @_;
    if ( defined $node ) {
        return $en_counterpart{ $node->id };
    }
    else {
        return undef;
    }
}

# only a wrapper, for backward compatibility
sub get_form {
    my ( $self, $lemma, $tag ) = @_;
    return $formGenerator->get_form( $lemma, $tag );
}

# changes the tag in the node and regebnerates the form correspondingly
# only a wrapper
sub regenerate_node {
    my ( $self, $node, $new_tag, $dont_try_switch_number ) = @_;

    if (defined $new_tag) {
        $node->set_tag($new_tag);
    }

    if (!defined $dont_try_switch_number) {
        $dont_try_switch_number = $self->dont_try_switch_number;
    }

    if ($self->magic =~ /switch_num_only_if_ennode/ && !defined $self->en($node)) {
        $dont_try_switch_number = 1;
    }

    return $formGenerator->regenerate_node(
        $node, $dont_try_switch_number, $self->en($node) );
}

# prefetches useful information into hashes
sub get_pair {
    my ( $self, $node ) = @_;

    return if $node->isa('Treex::Core::Node::Deleted');

    # "old"
    my $parent = $node->get_parent;
    while (
        $node->is_member
        && !$parent->is_root()
        && $parent->afun =~ /^(Coord|Apos)$/
        )
    {
        $parent = $parent->get_parent();
    }

    #     # "new"
    #     my $parent = $node->get_eparents({
    #         first_only => 1,
    #         or_topological => 1,
    #         ignore_incorrect_tree_structure => 1
    #     });
    #     # or probably better:
    #     my ($parent) = $node->get_eparents({
    #         or_topological => 1,
    #         ignore_incorrect_tree_structure => 1
    #     });

    return if ( !defined $parent || $parent->is_root );

    my $d_tag = ($node->tag && length ($node->tag) >= 15) ?
        $node->tag : '---------------';
    my %d_categories = (
        pos    => substr( $d_tag, 0,  1 ),
        subpos => substr( $d_tag, 1,  1 ),
        gen    => substr( $d_tag, 2,  1 ),
        num    => substr( $d_tag, 3,  1 ),
        case   => substr( $d_tag, 4,  1 ),
        pgen   => substr( $d_tag, 5,  1 ),
        pnum   => substr( $d_tag, 6,  1 ),
        pers   => substr( $d_tag, 7,  1 ),
        tense  => substr( $d_tag, 8,  1 ),
        grade  => substr( $d_tag, 9,  1 ),
        neg    => substr( $d_tag, 10, 1 ),
        voice  => substr( $d_tag, 11, 1 ),
        var    => substr( $d_tag, 14, 1 ),
        tag    => $d_tag,
        afun   => ( $node->afun || '' ),
        flt    => ( $node->form || '' ) . '#' . ( $node->lemma || '' ) . '#' . ( $node->tag || '' ),
    );
    my $g_tag = ($parent->tag && length ($parent->tag) >= 15) ?
        $parent->tag : '---------------';
    my %g_categories = (
        pos    => substr( $g_tag, 0,  1 ),
        subpos => substr( $g_tag, 1,  1 ),
        gen    => substr( $g_tag, 2,  1 ),
        num    => substr( $g_tag, 3,  1 ),
        case   => substr( $g_tag, 4,  1 ),
        pgen   => substr( $g_tag, 5,  1 ),
        pnum   => substr( $g_tag, 6,  1 ),
        pers   => substr( $g_tag, 7,  1 ),
        tense  => substr( $g_tag, 8,  1 ),
        grade  => substr( $g_tag, 9,  1 ),
        neg    => substr( $g_tag, 10, 1 ),
        voice  => substr( $g_tag, 11, 1 ),
        var    => substr( $g_tag, 14, 1 ),
        tag    => $g_tag,
        afun   => ( $parent->afun || '' ),
        flt    => ( $parent->form || '' ) . '#' . ( $parent->lemma || '' ) . '#' . ( $parent->tag || '' ),
    );

    return ( $node, $parent, \%d_categories, \%g_categories );
}

sub get_tag_cat {
    my ($self, $tag, $cat) = @_;

    return Treex::Tool::Depfix::CS::TagHandler::get_tag_cat($tag, $cat);
}

sub set_tag_cat {
    my ($self, $tag, $cat, $value) = @_;

    return Treex::Tool::Depfix::CS::TagHandler::set_tag_cat($tag, $cat, $value);
}

sub get_node_tag_cat {
    my ($self, $node, $cat) = @_;

    return Treex::Tool::Depfix::CS::TagHandler::get_node_tag_cat($node, $cat);
}

sub set_node_tag_cat {
    my ($self, $node, $cat, $value) = @_;

    return Treex::Tool::Depfix::CS::TagHandler::set_node_tag_cat($node, $cat, $value);
}

# tries to guess whether the given node is a name
sub isName {
    my ( $self, $node ) = @_;

    # TODO: now very unefficient implementation,
    # should be computed and hashed at the beginning
    # and then use something like return $is_named_entity{$node->id}

    if (!$node->get_bundle->has_tree(
            $self->language, 'n', $self->selector )
    ) {
        log_warn "n tree is missing!";
        return 0;
    }

    my $n_root = $node->get_bundle->get_tree( $self->language, 'n', $self->selector );

    # all n nodes
    my @n_nodes = $n_root->get_descendants();
    foreach my $n_node (@n_nodes) {

        # all a nodes that are named entities
        my @a_nodes = $n_node->get_anodes();
        foreach my $a_node (@a_nodes) {
            if ( $node->id eq $a_node->id ) {

                # this node is a named entity
                return 1;
            }
        }
    }
    return 0;
}

my %time_expr = (
    'Monday'    => 1,
    'Tuesday'   => 1,
    'Wednesday' => 1,
    'Thursday'  => 1,
    'Friday'    => 1,
    'Saturday'  => 1,
    'Sunday'    => 1,
    'January'   => 1,
    'February'  => 1,
    'March'     => 1,
    'April'     => 1,
    'May'       => 1,
    'June'      => 1,
    'July'      => 1,
    'August'    => 1,
    'September' => 1,
    'October'   => 1,
    'November'  => 1,
    'December'  => 1,
    'second'    => 1,
    'minute'    => 1,
    'hour'      => 1,
    'morning'   => 1,
    'afternoon' => 1,
    'evening'   => 1,
    'night'     => 1,
    'day'       => 1,
    'week'      => 1,
    'fortnight' => 1,
    'month'     => 1,
    'season'    => 1,
    'year'      => 1,
    'decade'    => 1,
    'century'   => 1,
    'beginning' => 1,
    'end'       => 1,
);

sub isTimeExpr {
    my ( $self, $lemma ) = @_;

    if ( $time_expr{$lemma} ) {
        return 1;
    } else {
        return 0;
    }
}

sub isNumber {
    my ( $self, $node ) = @_;

    if ( !defined $node ) {
        return 0;
    }

    if ( $node->tag =~ /^C/ || $node->form =~ /^[0-9%]/ ) {
        return 1;
    } else {
        return 0;
    }
}

# convert the "normal" gender and number to past participle gender and number
sub gn2pp {
    my ( $self, $gn ) = @_;
    $gn =~ s/[IF]P/TP/;
    $gn =~ s/[MI]S/YS/;
    $gn =~ s/(FS|NP)/QW/;
    return $gn;
}

sub shift_subtree_after_node {
    my ($self, $subtree_root, $node) = @_;
    
    # do the shift
    $subtree_root->shift_after_node($node);
    
    # try to normalize spaces
    # TODO: I am sure I am reinventing America here -> find a block for that!
    # important nodes
    my $subtree_rightmost = $subtree_root->get_descendants(
        {add_self => 1, last_only => 1});
    my $subtree_preceding = $subtree_root->get_descendants(
        {add_self => 1, last_only => 1})->get_prev_node();
    # remember the no_space_after ("nsa") values
    my $node_nsa = $node->no_space_after;
    my $subtree_rightmost_nsa = $subtree_rightmost->no_space_after;
    my $subtree_preceding_nsa = eval '$subtree_preceding->no_space_after' // 0;
    # set the nsa values
    $node->set_no_space_after($subtree_preceding_nsa);
    $subtree_rightmost->set_no_space_after($node_nsa);
    $subtree_preceding->set_no_space_after($subtree_rightmost_nsa);
        
    return;
}

# removes a node, moving its children under its parent
sub remove_node {
    my ( $self, $node, $rehang_under_en_eparent ) = @_;

    #move children under parent
    my $parent = $node->get_parent;
    if ( $rehang_under_en_eparent && $self->en($node) ) {
        my $en_parent = $self->en($node)->get_eparents(
            { first_only => 1, or_topological => 1 }
        );
        my ($nodes) = $en_parent->get_aligned_nodes();
        if ( $nodes->[0] && !$nodes->[0]->is_descendant_of($node) ) {
            $parent = $nodes->[0];
        }
    }
    foreach my $child ( $node->get_children ) {
        $child->set_parent($parent);
    }

    #remove alignment
    if ( $self->en($node) ) {
        # $self->en($node)->set_attr( 'alignment', undef );

        # delete $self->en($node);
    }

    #remove
    $node->remove();

    return;
}

sub add_parent {
    my ( $self, $parent_info, $node ) = @_;

    if (!defined $node) {
        log_warn("Cannot add parent to undefined node!");
        return;
    }
    
    my $old_parent = $node->get_parent();
    my $new_parent = $old_parent->create_child($parent_info);
    $new_parent->set_parent($old_parent);
    $new_parent->shift_before_subtree(
        $node, { without_children => 1 }
    );

    return $new_parent;
}

# logging

my $logfixmsg          = '';
my $logfixold          = '';
my $logfixnew          = '';
my $logfixbundle       = undef;
my $logfixold_flt_gov  = undef;
my $logfixold_flt_dep  = undef;
my $logfix_aligned_gov = undef;
my $logfix_aligned_dep = undef;

sub logfix1 {
    my ( $self, $node, $mess ) = @_;
    my ( $dep, $gov, $d, $g ) = $self->get_pair($node);

    $logfixmsg    = $mess;
    $logfixbundle = $node->get_bundle;

    if ( $gov && $dep ) {

        $logfixold_flt_gov = $g->{flt};
        $logfixold_flt_dep = $d->{flt};

        # mark with alignment arrow

        my $cs_root = $node->get_bundle->get_tree(
            $self->language, 'a'
        );
        my @cs_nodes = $cs_root->get_descendants(
            {
                add_self => 1,
                ordered  => 1
            }
        );

        my $cs_gov = $cs_nodes[ $gov->ord ];
        if ( defined $cs_gov && $cs_gov->lemma eq $gov->lemma ) {
            $logfix_aligned_gov = $cs_gov;
        } else {
            $logfix_aligned_gov = undef;
        }

        my $cs_dep = $cs_nodes[ $dep->ord ];
        if ( defined $cs_dep && $cs_dep->lemma eq $dep->lemma ) {
            $logfix_aligned_dep = $cs_dep;
        } else {
            $logfix_aligned_dep = undef;
        }

        # mark in fixlog

        # my $distance = abs($gov->ord - $dep->ord);
        # warn "FIXDISTANCE: $distance\n";

        #original words pair
        if ( $gov->ord < $dep->ord ) {
            $logfixold = $gov->form;
            $logfixold .= "[";
            $logfixold .= $gov->tag;
            $logfixold .= "] ";
            $logfixold .= $dep->form;
            $logfixold .= "[";
            $logfixold .= $dep->tag;
            $logfixold .= "]";
        }
        else {
            $logfixold = $dep->form;
            $logfixold .= "[";
            $logfixold .= $dep->tag;
            $logfixold .= "] ";
            $logfixold .= $gov->form;
            $logfixold .= "[";
            $logfixold .= $gov->tag;
            $logfixold .= "]";
        }
    }
    else {
        $logfixold         = '(undefined node)';
        $logfixold_flt_gov = undef;
        $logfixold_flt_dep = undef;
    }

    return;
}

sub logfix2 {
    my ( $self, $node ) = @_;

    my $dep = undef;
    my $gov = undef;
    my $d   = undef;
    my $g   = undef;

    if ($node) {
        ( $dep, $gov, $d, $g ) = $self->get_pair($node);
        return if !$dep;

        #new words pair
        if ( $gov->ord < $dep->ord ) {
            $logfixnew = $gov->form;
            $logfixnew .= "[";
            $logfixnew .= $gov->tag;
            $logfixnew .= "] ";
            $logfixnew .= $dep->form;
            $logfixnew .= "[";
            $logfixnew .= $dep->tag;
            $logfixnew .= "] ";
        }
        else {
            $logfixnew = $dep->form;
            $logfixnew .= "[";
            $logfixnew .= $dep->tag;
            $logfixnew .= "] ";
            $logfixnew .= $gov->form;
            $logfixnew .= "[";
            $logfixnew .= $gov->tag;
            $logfixnew .= "] ";
        }
    }
    else {
        $logfixnew = '(removal)';
    }

    #output
    if ( $logfixold ne $logfixnew ) {

        # alignment link
        if (
            defined $gov && defined $logfix_aligned_gov
            && defined $logfixold_flt_gov && $logfixold_flt_gov ne $g->{flt}
            )
        {
            $logfix_aligned_gov->add_aligned_node( $gov, "depfix_$logfixmsg" );
        }
        if (
            defined $dep && defined $logfix_aligned_dep
            && defined $logfixold_flt_dep && $logfixold_flt_dep ne $d->{flt}
            )
        {
            $logfix_aligned_dep->add_aligned_node( $dep, "depfix_$logfixmsg" );
        }

        # FIXLOG
        if ( $logfixbundle->get_zone( 'cs', 'FIXLOG' ) ) {
            my $sentence = $logfixbundle->get_or_create_zone( 'cs', 'FIXLOG' )
                ->sentence . "{$logfixmsg: $logfixold -> $logfixnew} ";
            $logfixbundle->get_zone( 'cs', 'FIXLOG' )->set_sentence($sentence);
        }
        else {
            my $sentence = "{$logfixmsg: $logfixold -> $logfixnew} ";
            $logfixbundle->create_zone( 'cs', 'FIXLOG' )
                ->set_sentence($sentence);
        }
    }

    if ( $self->log_to_console ) {
        log_info("Fixing $logfixmsg: $logfixold -> $logfixnew");
    }

    return;
}

1;

=head1 NAME 

Treex::Block::A2A::CS::FixAgreement

=head1 DESCRIPTION

Base class for grammatical errors fixing (common ancestor of all
C<A2A::CS::Fix*> modules).

A loop goes through all nodes in the analytical tree, gets their effective
parent and their morphological categories and passes this data to the C<fix()>
sub. In this module, the C<fix()> has an empty implementation - it is to be
redefined in children modules.

The C<fix()> sub can make use of subs defined in this module.

If you find an error, you probably want to call the C<regenerate_node()> sub.
The tag is changed, then the word form is regenerated.

To log changes that were made into the tree that was changed (into the
sentence in a zone cs_FIXLOG),
call C<logfix1()> before calling C<regenerate_node()>
and C<logfix2()> after calling C<regenerate_node()>.

=head1 AUTHOR

David Marecek <marecek@ufal.mff.cuni.cz>

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2012 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
