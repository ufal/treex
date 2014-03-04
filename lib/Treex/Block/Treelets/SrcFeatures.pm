package Treex::Block::Treelets::SrcFeatures;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use TranslationModel::Static::Model;

# TODO
# has substitute_pnom => (
#     is            => 'ro',
#     isa           => 'Bool',
#     default       => 1,
#     documentation => 'use the subject instead of the verb "to be" as eparent in case of copula constructions'
# );

has model_dir => (
    is            => 'ro',
    isa           => 'Str',
    default       => 'data/models/translation/en2cs',
    documentation => 'Base directory for all models'
);

has static_model => (
    is      => 'ro',
    isa     => 'Str',
    default => 'tlemma_czeng09.static.pls.slurp.gz',
);

has wild_attr => (
    is      => 'ro',
    isa     => 'Str',
    default => 'features',
    documentation => 'name of the wild attribute where to save the extracted features',
);

my $static;

sub load_model {
    my ( $self, $model, $filename ) = @_;
    my $path = $self->model_dir . '/' . $filename;
    $model->load( Treex::Core::Resource::require_file_from_share($path) );
    return $model;
}

sub process_start {
    my ($self) = @_;
    $self->SUPER::process_start();
    $static = $self->load_model( TranslationModel::Static::Model->new(), $self->static_model );
    return;
}

sub _set_static {
    my ($self, $new_static) = @_;
    $static = $new_static;
    return;
}

sub process_tnode {
    my ( $self, $tnode ) = @_;
    my $feats = $self->features_of_tnode($tnode);
    $tnode->wild->{$self->wild_attr} = $feats;
    return;
}

sub features_of_tnode {
    my ( $self, $tnode ) = @_;
    my $tlemma = lemma($tnode);    
       
    # Features from this node
    my $feats = join '',
        add($tnode, 'f', 'formeme'),
        add($tnode, 'l', 't_lemma'),
        add($tnode, 'num', 'gram/number'),
        add($tnode, 'voi', 'gram/voice'),
        add($tnode, 'neg', 'gram/negation'),
        add($tnode, 'ten', 'gram/tense'),
        add($tnode, 'per', 'gram/person'),
        add($tnode, 'deg', 'gram/degcmp'),
        add($tnode, 'pos', 'gram/sempos'),
        add($tnode, 'mem', 'is_member'),
        add($tnode, 'art', '_article'),
        add($tnode, 'ent', '_ne_type'),
        add($tnode, 'ppa', '_precedes_parent'),
        add($tnode, 'tag', '_pos_tag'),
        add($tnode, 'cap', '_capitalized'),
        add($tnode, 'hlc', '_has_left_child'),
        add($tnode, 'hrc', '_has_right_child'),
    ;
    
    # Features from previous (left) and following (Right) node
    my $prev_tnode = $tnode->get_prev_node();
    my $next_tnode = $tnode->get_next_node();
    $feats .= join '',
        add($prev_tnode, 'Ll', 't_lemma'),
        add($next_tnode, 'Rl', 't_lemma'),
        add($prev_tnode, 'Lent', '_ne_type'),
        add($next_tnode, 'Rent', '_ne_type'),
    ;

    # Features from its parent
    my ($tparent) = $tnode->get_eparents( { or_topological => 1 } );
    if (!$tparent->is_root){
        $feats .= join '',
        ' f&Pl=' . $tnode->formeme . '&' . lemma_or_tag($tparent),
        add($tparent, 'Pnum', 'gram/number'),
        add($tparent, 'Pvoi', 'gram/voice'),
        add($tparent, 'Pneg', 'gram/negation'),
        add($tparent, 'Pten', 'gram/tense'),
        add($tparent, 'Pper', 'gram/person'),
        add($tparent, 'Pdeg', 'gram/degcmp'),
        add($tparent, 'Ppos', 'gram/sempos'),
        add($tparent, 'Pmem', 'is_member'),
        add($tparent, 'Part', '_article'),
        add($tparent, 'Pent', '_ne_type'),
        add($tparent, 'Ptag', '_pos_tag'),
        add($tparent, 'Pcap', '_capitalized'),
        ;
    }

    # Features from its children
    foreach my $child ($tnode->get_echildren( { or_topological => 1 } )){
        if (my $achild = $child->get_lex_anode) {
            $feats .= ' Ct=' . $achild->tag;
            $feats .= ' Cc=' . $achild->form =~ /^\p{IsUpper}/;
        }
        $feats .= ' Cf=' . $child->formeme;
        $feats .= ' Cf&Cl=' . $child->formeme .'&'. lemma_or_tag($child);
    }

    # VW format does not allow ":"
    $feats =~ s/:/;/g;

    return $feats;
}

sub add {
    my ($tnode, $name, $attr) = @_;
    return " $name=_SENT_" if !$tnode && $attr eq 't_lemma';
    return '' if !$tnode;
    my $value;
    my $anode = $tnode->get_lex_anode;
    if ($attr eq '_article'){
        $value = first {/^(an?|the)$/} map {lc $_->form} $tnode->get_aux_anodes;
    } elsif ($attr eq '_ne_type'){
        if ( my $n_node = $tnode->get_n_node() ) {
            $value = $n_node->ne_type;
        }
    } elsif ($attr eq '_precedes_parent'){
        my ($tparent) = $tnode->get_eparents( { or_topological => 1 } );
        if ( !$tparent->is_root ) {
            $value = $tnode->precedes($tparent) ? 'yes' : 'no';
        }
    } elsif ($attr eq '_has_left_child'){
        $value = $tnode->get_children({preceding_only => 1}) ? 'yes' : 'no';
    } elsif ($attr eq '_has_right_child'){
        $value = $tnode->get_children({following_only => 1}) ? 'yes' : 'no';
    } elsif ($attr eq '_pos_tag' && $anode) {
        $value = $anode->tag;
    } elsif ($attr eq '_capitalized' && $anode) {
        $value = 1 if $anode->form =~ /^\p{IsUpper}/;
    } 
    else {
        $value = $tnode->get_attr($attr);
    }

    return '' if !defined $value;
    $value =~ s/ /&#32;/g;

    # Return the lemma if it is frequent enough. Otherwise return PennTB PoS tag.
    # TODO: use something better than the static dictionary.
    if ($attr eq 't_lemma' && !$static->_submodels->{lc $value}){
        return '' if !$anode;
        $value = $anode->tag;
    }

    # Shorten sempos
    $value =~ s/\..+// if $attr eq 'gram/sempos';

    return " $name=$value";
}

# For English
sub lemma {
    my ($tnode) = @_;
    my $lemma = $tnode->t_lemma // ''; #/
    $lemma =~ s/ /&#32;/g;
    return $lemma;
}

sub lemma_or_tag {
    my ($tnode) = @_;
    my $lemma = $tnode->t_lemma // ''; #/
    $lemma =~ s/ /&#32;/g;

    # Return the lemma if it is frequent enough.
    # TODO: use something better than the static dictionary.
    return $lemma if $static->_submodels->{lc $lemma};

    # Otherwise, return the PennTB PoS tag
    my $anode = $tnode->get_lex_anode();
    return $anode->tag if $anode;
    return '';
}


1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Treelets::SrcFeatures - extract context features for VW

=head1 DESCRIPTION

Can be used as a block (which fills a wild attribute) or as a library with function C<features_of_tnode>.
The usage aa a block is useful for debugging purposes, the library is for real-world usage.

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
