package Treex::Block::Align::Annot::Summary;

use Moose;
use Moose::Util::TypeConstraints;
use Treex::Core::Common;

extends 'Treex::Block::Write::BaseTextWriter';
with 'Treex::Block::Filter::Node';

subtype 'LangsArrayRef' => as 'ArrayRef';
coerce 'LangsArrayRef'
    => from 'Str'
    => via { [split /,/] };

has 'align_langs' => ( is => 'ro', isa => 'LangsArrayRef', coerce => 1, required => 1 );
has 'gold_ali_type' => ( is => 'ro', isa => 'Str', default => 'gold' );

sub _build_node_types {
    return 'all_anaph';
}

# print only for t-nodes by default
sub _build_layers {
    return "t";
}


sub feats_for_tnode {
    my ($tnode) = @_;

    return map {"undef"} 1..7 if (!defined $tnode);

    my @feats = ();

    push @feats, $tnode->get_address;
    push @feats, join " ", @{$tnode->wild->{filter_types}};
    push @feats, $tnode->t_lemma // "undef";
    push @feats, $tnode->gram_sempos // "undef";

    my $anode = $tnode->get_lex_anode;
    if (defined $anode) {
        push @feats, $anode->lemma;
        push @feats, substr($anode->tag, 0, 2);
    }
    else {
        push @feats, ("undef", "undef");
    }

    my @g_antes = $tnode->get_coref_gram_nodes();
    my @t_antes = $tnode->get_coref_text_nodes();
    my $coref_label = @g_antes > 0 ? "g" :
                      (@t_antes > 0 ? "t" : "0");
    push @feats, $coref_label;

    return @feats;
}

sub feats_for_anode {
    my ($anode) = @_;
    
    return map {"undef"} 1..5 if (!defined $anode);
    
    my @feats = ();
    push @feats, $anode->get_address;
    #push @feats, join " ", ($anode->wild->{filter_types} ? @{$anode->wild->{filter_types}} : "undef");
    #push @feats, map {"undef"} 1..2;

    push @feats, $anode->form;
    push @feats, $anode->lemma;
    push @feats, substr($anode->tag, 0, 2);
    push @feats, $anode->tag;
    #push @feats, "undef";
    return @feats;
}

sub get_gold_aligns {
    my ($self, $node) = @_;
    my %gold_aligns = map {
        my ($ali_nodes, $ali_types) = $node->get_undirected_aligned_nodes({ 
            language => $_, 
            selector => $node->selector, 
            rel_types => [$self->gold_ali_type],
        });
        $_ => $ali_nodes;
    } @{$self->align_langs};
    $gold_aligns{$node->language} = [$node];
    return \%gold_aligns;
}

sub get_align_info {
    my ($gold_aligns) = @_;

    my @all_langs = keys %$gold_aligns;
    my $align_info;
    foreach my $lang (@all_langs) {
        my ($ali_node) = @{$gold_aligns->{$lang}};
        next if (!defined $ali_node);
        if (defined $ali_node->wild->{align_info}) {
            $align_info->{$_} = $ali_node->wild->{align_info}->{$_} foreach (keys %{$ali_node->wild->{align_info}});
        }
    }
    return $align_info;
}

#sub process_filtered_tnode {
#    my ($self, $tnode) = @_;
#
#    # TODO: refactor this
#
#    my $t_gold_aligns = $self->get_gold_aligns($tnode);
#    my $anode = $tnode->get_lex_anode;
#    my $a_gold_aligns = $self->get_gold_aligns($anode);
#    foreach my $lang ($tnode->language, @{$self->align_langs}) {
#        my ($ali_tnode) = @{$gold_aligns->{$lang}};
#        my @feats = feats_for_tnode($ali_tnode);
#    }
#
#    my @l2_feats;
#    my $l1_anode = $l1_tnode->get_lex_anode;
#    my $ali_info = undef;
#    if (!defined $l2_tnode && defined $l1_anode) {
#        my ($l2_anode) = Treex::Tool::Align::Utils::aligned_transitively([$l1_anode], [$self->gold_align_filter]);
#        @l2_feats = feats_for_anode($l2_anode);
#        $ali_info = get_ali_info($l1_anode, $l2_anode);
#    }
#    else {
#        @l2_feats = feats_for_tnode($l2_tnode);
#    }
#    if (!defined $ali_info) {
#        $ali_info = get_ali_info($l1_tnode, $l2_tnode);
#    }
#    push @l2_feats, $ali_info;
#
#    my @feats = (@l1_feats, @l2_feats);
#
#    print {$self->_file_handle} join "\t", (@l1_feats, @l2_feats);
#    print {$self->_file_handle} "\n";
#}

sub process_filtered_anode {
    my ($self, $anode) = @_;

    my $gold_aligns = $self->get_gold_aligns($anode);
    my $align_info = get_align_info($gold_aligns);

    my @all_feats = ();
    foreach my $lang ($anode->language, @{$self->align_langs}) {
        my ($ali_anode) = @{$gold_aligns->{$lang}};
        my @feats = feats_for_anode($ali_anode);
        push @feats, uc($lang) . ": " . ($align_info->{$lang} // "");
        push @all_feats, @feats;
    }
    
    @all_feats = map {$_ =~ s/\t/ /g; $_} @all_feats;
    print {$self->_file_handle} (join "\t", @all_feats);
    print {$self->_file_handle} "\n";
}

# TODO process_anode

1;
