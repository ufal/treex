package Treex::Block::W2A::EN::MarkCheckCommas;
use Moose;
use Treex::Core::Common;
#use Data::Printer;

use List::MoreUtils qw/any/;

extends 'Treex::Core::Block';

sub _process_atree {
    my ($self, $atree) = @_;

    my @old_coord_heads = get_coord_heads($atree);

    foreach my $old_coord_head (@old_coord_heads) {
        my $head_par = $old_coord_head->get_parent;

        my @phrase_nodes = $old_coord_head->get_descendants({add_self => 1, ordered => 1});
        $_->set_parent($head_par) foreach (@phrase_nodes);
        
        my @commas = ();
        my @members = ();
        my $curr_member_head;
        foreach my $node (@phrase_nodes) {
            if ($node->lemma eq ",") {
                push @commas, $node;
                $curr_member_head = undef;
                next;
            }
            if (!defined $curr_member_head) {
                $curr_member_head = $node;
                push @members, $curr_member_head;
                next;
            }
            $node->set_parent($curr_member_head);
            $curr_member_head = $node;
        }
        push @members, $curr_member_head if (defined $curr_member_head);

        my $new_coord_root = shift @commas;
        $new_coord_root->set_afun('Coord');
        my $member = shift @members;
        $member->set_parent($new_coord_root);
        $member->set_is_member(1);
        while (@members && @commas) {
            $member = shift @members;
            $member->set_parent($new_coord_root);
            $member->set_is_member(1);
            my $comma = shift @commas;
            $comma->set_parent($new_coord_root);
        }
        while (@members) {
            $member = shift @members;
            $member->set_parent($new_coord_root);
            $member->set_is_member(1);
        }
        while (@commas) {
            my $comma = shift @commas;
            $comma->set_parent($new_coord_root);
        }

        $new_coord_root->set_parent($head_par);
    }

}

sub process_atree {
    my ($self, $atree) = @_;

    my @old_coord_heads = get_coord_heads($atree);
    foreach my $head (@old_coord_heads) {
        my @phrase_nodes = $head->get_descendants({add_self => 1, ordered => 1});
        for (my $i = 0; $i < @phrase_nodes; $i++) {
            my $curr_node = $phrase_nodes[$i];
            my $next_node = $phrase_nodes[$i+1];
            if (defined $next_node && $next_node->lemma eq ",") {
                $curr_node->wild->{check_comma_after} = 1;
            }
        }
    }
}

sub get_coord_heads {
    my ($atree) = @_;
    
    my @all_commas = grep {$_->lemma eq ","} $atree->get_descendants;
    my %commas_parents = map {my $par = $_->parent; $par->id => $par} @all_commas;

    my @keys = keys %commas_parents;

    my %head_phrases = ();
    while (my $par_id = shift @keys) {
        my $par = delete $commas_parents{$par_id};
        my @descs = $par->get_descendants({add_self => 1});
        next if any {$_->tag =~ /^V/ || $_->afun eq 'Coord'} @descs;
        foreach my $desc (@descs) {
            if (defined $commas_parents{$desc->id}) {
                delete $commas_parents{$desc->id};
            }
            if (defined $head_phrases{$desc->id}) {
                delete $head_phrases{$desc->id};
            }
        }
        $head_phrases{$par->id} = $par;
        @keys = keys %commas_parents;
    }
    return values %head_phrases;
}

1;
